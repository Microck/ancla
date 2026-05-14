# Architecture

Architectural decisions, parity notes, and implementation boundaries for this mission.

**What belongs here:** Android architecture choices, behavior-preservation notes, platform replacements for iOS-only APIs, and state-model expectations.

---

- Android app lives in `/home/ubuntu/workspace/ancla/android`.
- The Android port is **native Kotlin + Jetpack Compose**.
- The iOS app is the behavioral source-of-truth, but Android should use Android-native mechanics rather than transliterating iOS-only APIs.
- Domain/network blocking is intentionally out of scope on Android.
- Browsers are treated as explicit app targets selected by the user.
- Planned worker split:
  - `android-core-worker` for project foundation, setup/readiness, mode management, schedules, unlocks, failsafes, and history
  - `android-platform-worker` for NFC integration, session binding, accessibility-driven blocking, and lock-surface behavior
  - `android-release-worker` for release packaging and BrowserStack smoke validation
- Approved infrastructure fallback: a Dockerized Android Gradle lane may replace host-local Gradle execution if the Oracle Linux host continues to reject local Gradle daemon/client handshakes.
- Preserve the narrow product philosophy:
  - one physical release path anchored to a paired NFC object
  - explicit blocking modes chosen by the user
  - lock surface while blocked
  - timed unlock presets and fallback release flows
- Avoid compatibility shims for hypothetical legacy Android states. There is no existing Android app to preserve.
