# Sideloading

This repo now has two sideload-first workflows that produce unsigned `.ipa` artifacts.

Workflows:

- `.github/workflows/ios-sideload-ipa.yml`
- `.github/workflows/ios-sideload-lite-ipa.yml`

## Which one to use

Use `ios-sideload-ipa` for the installable sideload build. It now builds a sideload-safe target with:

- the real app UI
- real `CoreNFC` scanning
- local mode/session state
- no embedded shield extension
- no privileged Screen Time blocker entitlement requirement

Use `ios-sideload-lite-ipa` only if you specifically want the older `Ancla Lite` target as a secondary fallback.

## What the full workflow does

1. runs on a GitHub-hosted macOS runner
2. installs `xcodegen`
3. generates the Xcode project from `ios/project.yml`
4. builds an unsigned `.xcarchive` with code signing disabled
5. packages `Payload/Ancla.app` into an unsigned `.ipa`
6. writes a build report that confirms the sideload-safe target and checked-in entitlement source
7. uploads the `.ipa`, `.xcarchive`, and build report as artifacts

## What the sideload-lite workflow changes

The lite workflow builds the `AnclaLite` target instead of the full `Ancla` target.

That target intentionally removes the shield extension and the restricted entitlements that make generic sideload signing fragile:

- `FamilyControls`
- `ManagedSettingsUI` shield extension behavior
- App Group-backed release path

It keeps `CoreNFC` tag-reading enabled so pairing and release can still use a real sticker.

The goal is simple: produce the cleanest possible Feather-friendly build that still tests the actual NFC ritual.

## Why unsigned

This avoids the full App Store Connect / TestFlight / Apple signing setup just to get a testable bundle artifact.

That keeps the first build path simple, but it also means the workflow does not solve installation by itself.

## What you do after download

After the action finishes:

1. download `ancla-unsigned-ipa-*`
2. download `ancla-build-report-*`
3. inspect the build report before trusting the artifact
4. sign and install the `.ipa` with your own sideloading path if you want it on-device
5. open the app and check the diagnostics screen before trusting any blocker behavior

The release path in this repo stops at the unsigned artifact. Do not expect a maintainer-signed IPA.

What you want to see in the app:

- `Build` = `Sideload-safe build`
- `NFC` = `Ready`
- `Storage` = `Local store`
- `Screen Time` = `Not required`

What bad looks like:

- generic app icon after install
- app exits immediately on launch
- `NFC` = `Unavailable`
  - this phone cannot run the sticker flow

## What this does not guarantee

The lite build is not the full blocker product loop.

It keeps real sticker pairing and release scans, plus local mode and session state. It does not perform real app blocking.

The true blocker build still depends on Apple entitlement and signing rules for:

- `FamilyControls`
- `ManagedSettings`
- the shield extension
- App Group-backed shared storage

## Why the `.xcarchive` artifact is also uploaded

The archive is useful if the `.ipa` needs to be repackaged differently later or if you want to inspect the built app bundle and embedded extension layout.

The build report is the fast sanity check. It tells you whether the GitHub runner actually produced the sideload-safe app layout before you even open Feather.
