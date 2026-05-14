#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/ubuntu/workspace/ancla"
ANDROID_ROOT="$REPO_ROOT/android"
SDK_ROOT="$REPO_ROOT/tmp/android-sdk"
CMDLINE_TOOLS_ROOT="$SDK_ROOT/cmdline-tools"
CMDLINE_TOOLS_LATEST="$CMDLINE_TOOLS_ROOT/latest"
CMDLINE_TOOLS_ZIP="$REPO_ROOT/tmp/commandlinetools-linux-14742923_latest.zip"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip"

mkdir -p "$REPO_ROOT/tmp" "$SDK_ROOT" "$CMDLINE_TOOLS_ROOT"

export ANDROID_SDK_ROOT="$SDK_ROOT"
export ANDROID_HOME="$SDK_ROOT"
export PATH="$CMDLINE_TOOLS_LATEST/bin:$SDK_ROOT/platform-tools:$PATH"

for required_tool in curl python3; do
  if ! command -v "$required_tool" >/dev/null 2>&1; then
    echo "Missing required host tool: $required_tool" >&2
    exit 1
  fi
done

if [ ! -x "$CMDLINE_TOOLS_LATEST/bin/sdkmanager" ]; then
  mkdir -p "$CMDLINE_TOOLS_LATEST"
  if [ ! -f "$CMDLINE_TOOLS_ZIP" ]; then
    curl -L "$CMDLINE_TOOLS_URL" -o "$CMDLINE_TOOLS_ZIP"
  fi

  tmp_extract_dir="$(mktemp -d)"
  python3 - "$CMDLINE_TOOLS_ZIP" "$tmp_extract_dir" <<'PY'
import sys
import zipfile

zip_path = sys.argv[1]
out_dir = sys.argv[2]

with zipfile.ZipFile(zip_path) as zf:
    zf.extractall(out_dir)
PY
  rm -rf "$CMDLINE_TOOLS_LATEST"
  mkdir -p "$CMDLINE_TOOLS_LATEST"
  cp -R "$tmp_extract_dir/cmdline-tools/." "$CMDLINE_TOOLS_LATEST/"
  rm -rf "$tmp_extract_dir"
fi

if [ -x "$CMDLINE_TOOLS_LATEST/bin/sdkmanager" ]; then
  yes | "$CMDLINE_TOOLS_LATEST/bin/sdkmanager" --sdk_root="$SDK_ROOT" --licenses >/dev/null || true
  "$CMDLINE_TOOLS_LATEST/bin/sdkmanager" --sdk_root="$SDK_ROOT" \
    "platform-tools" \
    "platforms;android-36" \
    "build-tools;36.0.0" >/dev/null
fi

if [ -d "$ANDROID_ROOT" ]; then
  cat > "$ANDROID_ROOT/local.properties" <<EOF
sdk.dir=$SDK_ROOT
EOF
fi
