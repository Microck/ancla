#!/usr/bin/env bash
set -euo pipefail

ANDROID_ROOT="/home/ubuntu/workspace/ancla/android"
REPO_ROOT="/home/ubuntu/workspace/ancla"
SDK_ROOT="$REPO_ROOT/tmp/android-sdk"
GRADLE_USER_HOME_DIR="$REPO_ROOT/tmp/docker-gradle-user-home"
ANDROID_USER_HOME_DIR="$REPO_ROOT/tmp/docker-android-home"
AAPT2_OVERRIDE_BIN="$REPO_ROOT/tmp/android-sdk-tools-static-aarch64/build-tools/aapt2"
AAPT2_OVERRIDE_NOTE="Using the checked-in ARM64 static AAPT2 override because the stock containerized binary is not reliable on this host architecture."
KNOWN_WARNING_NOTE="AGP may still emit a non-blocking metrics/analytics warning in the containerized lane even when analytics.settings is pre-seeded; treat it as informational unless the build exits non-zero."
KOTLIN_DAEMON_NOTE="Kotlin daemon startup handshakes can flap in this container lane on ARM64; force in-process Kotlin compilation so lint and unit-test validators do not fail on transient daemon-connect loss."
IMAGE_REPOSITORY="ancla-android-gradle"
IMAGE_TAG="jdk17"
IMAGE_NAME="${IMAGE_REPOSITORY}:${IMAGE_TAG}"
DOCKERFILE_PATH="$ANDROID_ROOT/scripts/docker-gradle.Dockerfile"
CONTAINER_WORKDIR="/workspace/android"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

print_help() {
  cat <<EOF
Usage: android/scripts/docker-gradle.sh [gradle args...]

Runs Android Gradle commands inside a repeatable Docker lane to avoid the
host-local Oracle Linux Gradle networking failure.

Accepted containerized build notes:
- $AAPT2_OVERRIDE_NOTE
- $KNOWN_WARNING_NOTE
- $KOTLIN_DAEMON_NOTE

Examples:
  android/scripts/docker-gradle.sh tasks
  android/scripts/docker-gradle.sh :app:testDebugUnitTest
  android/scripts/docker-gradle.sh :app:assembleDebug
  android/scripts/docker-gradle.sh :app:assembleRelease :app:bundleRelease
EOF
}

ensure_requirements() {
  command -v docker >/dev/null 2>&1 || {
    echo "docker is required but was not found on PATH" >&2
    exit 1
  }

  if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "Dockerfile missing at $DOCKERFILE_PATH" >&2
    exit 1
  fi

  mkdir -p "$SDK_ROOT" "$GRADLE_USER_HOME_DIR" "$ANDROID_USER_HOME_DIR"
}

seed_android_home() {
  mkdir -p "$ANDROID_USER_HOME_DIR"
  if [ ! -f "$ANDROID_USER_HOME_DIR/analytics.settings" ]; then
    printf "{}\n" >"$ANDROID_USER_HOME_DIR/analytics.settings"
  fi
}

ensure_aapt2_override() {
  if [ ! -x "$AAPT2_OVERRIDE_BIN" ]; then
    echo "Expected ARM64 AAPT2 override at $AAPT2_OVERRIDE_BIN" >&2
    exit 1
  fi
}

build_image() {
  local image_id
  local aapt2_fingerprint
  aapt2_fingerprint="$(sha256sum "$AAPT2_OVERRIDE_BIN" | cut -d' ' -f1)"
  image_id="$(docker image inspect "$IMAGE_NAME" --format '{{ index .Config.Labels \"dev.micr.ancla.aapt2-sha\" }}' 2>/dev/null || true)"
  if [ -n "$image_id" ] && [ "$image_id" = "$aapt2_fingerprint" ]; then
    return
  fi

  if [ ! -f "$REPO_ROOT/tmp/commandlinetools-linux-14742923_latest.zip" ]; then
    bash "$REPO_ROOT/.factory/init.sh"
  fi

  docker build \
    --build-arg HOST_SDK_ROOT="$SDK_ROOT" \
    --label "dev.micr.ancla.aapt2-sha=$aapt2_fingerprint" \
    --tag "$IMAGE_NAME" \
    --file "$DOCKERFILE_PATH" \
    "$REPO_ROOT"
}

run_gradle() {
  local container_local_properties
  local host_android_home_init
  local container_aapt2_override
  local gradle_opts
  local analytics_disabled
  container_local_properties="$(mktemp)"
  host_android_home_init="$(mktemp)"
  container_aapt2_override="/tmp/android-aapt2/aapt2"
  cat >"$container_local_properties" <<'EOF'
sdk.dir=/opt/android-sdk
EOF

  cat >"$host_android_home_init" <<'EOF'
#!/usr/bin/env sh
mkdir -p /home/gradle/.android
if [ -w /home/gradle/.android ] && [ ! -f /home/gradle/.android/analytics.settings ]; then
  printf "{}\n" > /home/gradle/.android/analytics.settings
fi
exec "$@"
EOF
  chmod +x "$host_android_home_init"

  ensure_aapt2_override

  analytics_disabled="false"
  if [ "${ANCLA_DISABLE_GRADLE_METRICS:-1}" = "1" ]; then
    analytics_disabled="true"
  fi

  # The Android Gradle plugin creates AndroidLocationsBuildService during configuration.
  # Keep HOME and ANDROID_USER_HOME writable inside the container so metrics opt-out remains non-blocking
  # instead of turning Android directory creation into a hard failure before project evaluation.
  gradle_opts="-Dandroid.aapt2FromMavenOverride=$container_aapt2_override -Dorg.gradle.project.android.aapt2FromMavenOverride=$container_aapt2_override"
  gradle_opts="$gradle_opts -Dkotlin.compiler.execution.strategy=in-process"

  docker run --rm \
    --user "${HOST_UID}:${HOST_GID}" \
    --volume "$REPO_ROOT:/workspace" \
    --volume "$SDK_ROOT:/opt/android-sdk" \
    --volume "$GRADLE_USER_HOME_DIR:/home/gradle/.gradle" \
    --volume "$ANDROID_USER_HOME_DIR:/home/gradle/.android" \
    --volume "$container_local_properties:/workspace/android/local.properties:ro" \
    --volume "$host_android_home_init:/tmp/ancla-android-home-init:ro" \
    --workdir "$CONTAINER_WORKDIR" \
    --env ANDROID_HOME="/opt/android-sdk" \
    --env ANDROID_SDK_ROOT="/opt/android-sdk" \
    --env ANDROID_USER_HOME="/home/gradle/.android" \
    --env HOME="/home/gradle" \
    --env LINT_PRINT_STACKTRACE="true" \
    --env GRADLE_OPTS="$gradle_opts" \
    --env ANCLA_BROWSERSTACK_SEEDED_STATE \
    --env ANCLA_BROWSERSTACK_SCHEDULE_SEEDED_STATE \
    --env ANCLA_RELEASE_COMMIT \
    --env ANCLA_RELEASE_RUN \
    --env ANCLA_RELEASE_BUILT_AT \
    --env ANCLA_DISABLE_GRADLE_METRICS \
    --entrypoint /tmp/ancla-android-home-init \
    "$IMAGE_NAME" \
    ./gradlew --no-daemon -Dandroid.aapt2FromMavenOverride="$container_aapt2_override" -Dorg.gradle.project.android.aapt2FromMavenOverride="$container_aapt2_override" -Dkotlin.compiler.execution.strategy=in-process -Dcom.android.tools.analyticsOptOut=$analytics_disabled "$@"

  local exit_code=$?
  rm -f "$container_local_properties"
  rm -f "$host_android_home_init"
  return "$exit_code"
}

main() {
  if [ "${1:-}" = "help" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    print_help
    exit 0
  fi

  if [ "$#" -eq 0 ]; then
    print_help
    exit 1
  fi

  ensure_requirements
  seed_android_home
  ensure_aapt2_override
  build_image
  run_gradle "$@"
}

main "$@"
