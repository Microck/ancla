# Sideloading

This repo now has two sideload-first workflows that produce unsigned `.ipa` artifacts.

Workflows:

- `.github/workflows/ios-sideload-ipa.yml`
- `.github/workflows/ios-sideload-lite-ipa.yml`

## Which one to use

Use `ios-sideload-ipa` for the real experiment. That is the full app bundle with:

- the shield extension
- `FamilyControls`
- `ManagedSettings`
- App Group-backed shared state
- real `CoreNFC` scanning

Use `ios-sideload-lite-ipa` only if the full build refuses to install or open after signing and you need the reduced fallback for NFC-only testing.

## What the full workflow does

1. runs on a GitHub-hosted macOS runner
2. installs `xcodegen`
3. generates the Xcode project from `ios/project.yml`
4. builds an unsigned `.xcarchive` with code signing disabled
5. packages `Payload/Ancla.app` into an unsigned `.ipa`
6. writes a build report that confirms the main app bundle, embedded shield extension, and checked-in entitlement sources
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
3. sign the `.ipa` in Feather with the certificate and provisioning material you bought
4. install it on your iPhone
5. open the app and check the diagnostics screen before trusting any blocker behavior

What you want to see in the app:

- `Build` = `Full blocker experiment`
- `NFC` = `Ready`
- `Storage` = `App Group live`
- `Screen Time` = `Approved`

What bad looks like:

- `Storage` = `App Group missing`
  - the signer/profile is not honoring the App Group entitlement, so shared blocker state is broken
- `Screen Time` = `Denied` or `Not granted`
  - the signer/profile is not actually giving you usable Family Controls authorization
- `NFC` = `Unavailable`
  - this phone cannot run the sticker flow

## What this does not guarantee

The lite build is not the full blocker product loop.

It keeps real sticker pairing and release scans, plus local mode and session state. It does not perform real app blocking.

The full build still depends on Apple entitlement and signing rules for:

- `FamilyControls`
- `ManagedSettings`
- the shield extension
- App Group-backed shared storage

## Why the `.xcarchive` artifact is also uploaded

The archive is useful if the `.ipa` needs to be repackaged differently later or if you want to inspect the built app bundle and embedded extension layout.

The build report is the fast sanity check. It tells you whether the GitHub runner actually produced the full app layout for the experiment before you even open Feather.
