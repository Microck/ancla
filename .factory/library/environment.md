# Environment

Environment variables, external dependencies, and setup notes.

**What belongs here:** required env vars, external services, SDK/tooling locations, setup notes, platform-specific quirks.  
**What does NOT belong here:** service ports/commands - use `.factory/services.yaml`.

---

- Android SDK is installed locally under `/home/ubuntu/workspace/ancla/tmp/android-sdk`.
- `ANDROID_SDK_ROOT` and `ANDROID_HOME` should point to that path during Android build/test commands.
- Initial SDK packages planned for the mission:
  - `platform-tools`
  - `platforms;android-36`
  - `build-tools;36.0.0`
- Android command-line tools should live at `<sdk>/cmdline-tools/latest`, matching official `sdkmanager` layout guidance from Android Developers.
- Host-specific note from the first bootstrap attempt: do not force Gradle's internal `InetAddressFactory` to `localhost` inside `android/gradlew`. On this Oracle Linux host it caused the daemon/client handshake to fail before project evaluation.
- Mission commands already use `--no-daemon`; launcher/bootstrap fixes should preserve that and avoid custom socket-binding hacks unless they are proven on this host.
- Host-specific note from the second bootstrap attempt: `android/gradle.properties` should not force networking-sensitive JVM flags such as `-Djava.net.preferIPv4Stack=true` unless they are proven to work on this host. Current evidence suggests that flag contributes to the loopback-only single-use daemon behavior.
- Next workaround to try before escalation: export `OPENSHIFT_IP=127.0.0.1` from `android/gradlew` so Gradle's `InetAddressFactory` treats the client and daemon as the same local interface. If that still fails, the blocker is likely external to repo-local bootstrap knobs.
- User-approved fallback after the OPENSHIFT_IP attempt: use a Dockerized Android Gradle lane instead of host-local Gradle execution on this machine.
- BrowserStack credentials must come from environment/session state only:
  - `BROWSERSTACK_USERNAME`
  - `BROWSERSTACK_ACCESS_KEY`
- Never commit BrowserStack credentials, release keystores, Play credentials, or signed release artifacts containing secrets.
- Play submission is out of scope unless new credentials and workflows are explicitly added later.
