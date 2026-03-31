# Ancla iOS

This directory contains the native iPhone app scaffold for Ancla.

## Notes

- The current environment does not have `swift`, `xcodebuild`, or `xcodegen`.
- The project is defined with `project.yml` so it can be generated on a macOS machine with XcodeGen.
- The app is structured around one canonical path:
  - request Screen Time authorization
  - create one or more block modes
  - set/override default mode
  - pair one NFC sticker
  - arm selected mode
  - require the paired sticker to release the lock
- Additional implemented UI flows:
  - single-screen minimal control flow
  - mode edit (name, targets, default toggle)
  - mode delete with armed-session cleanup
  - sticker rename and unpair
  - mode selection summary surfaces

## Tests

- `ancla-tests/app-view-model-tests.swift` contains in-memory fake-backed tests for mode, sticker, and session logic.
- `ancla-core-tests/ancla-core-tests.swift` is a pure SwiftPM test lane for the framework-free core logic.
- Xcode tests still require macOS, but the core package can be executed on Linux with Docker.

## Linux Verification

```bash
cd /home/ubuntu/workspace/ancla
docker run --rm \
  -v "$PWD/ios:/workspace" \
  -w /workspace \
  swift:5.10-jammy \
  swift test
```

This validates the shared core logic without `FamilyControls`, `ManagedSettings`, or `CoreNFC`.

## macOS Build/Test Commands

```bash
cd /home/ubuntu/workspace/ancla/ios
xcodegen generate
xcodebuild -project Ancla.xcodeproj -scheme Ancla -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -project Ancla.xcodeproj -scheme AnclaTests -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Expected result:

- app + extension build succeeds
- `AnclaTests` passes
