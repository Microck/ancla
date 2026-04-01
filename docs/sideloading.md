# Sideloading

This repo now has two sideload-first workflows that produce unsigned `.ipa` artifacts.

Workflows:

- `.github/workflows/ios-sideload-ipa.yml`
- `.github/workflows/ios-sideload-lite-ipa.yml`

## Which one to use

Use `ios-sideload-lite-ipa` first if the goal is to get a Feather-signed build that installs and opens reliably.

Use `ios-sideload-ipa` only if you want the full app bundle for inspection or for testing with proper Apple-managed entitlements and provisioning.

## What the full workflow does

1. runs on a GitHub-hosted macOS runner
2. installs `xcodegen`
3. generates the Xcode project from `ios/project.yml`
4. builds an unsigned `.xcarchive` with code signing disabled
5. packages `Payload/Ancla.app` into an unsigned `.ipa`
6. uploads both the `.ipa` and the `.xcarchive` as artifacts

## What the sideload-lite workflow changes

The lite workflow builds the `AnclaLite` target instead of the full `Ancla` target.

That target intentionally removes the shield extension and does not request the restricted entitlements that make generic sideload signing fragile:

- `FamilyControls`
- `ManagedSettingsUI` shield extension behavior
- App Group-backed release path
- NFC release path

The goal is simple: produce the cleanest possible Feather-friendly shell build.

## Why unsigned

This avoids the full App Store Connect / TestFlight / Apple signing setup just to get a testable bundle artifact.

That keeps the first build path simple, but it also means the workflow does not solve installation by itself.

## What you do after download

After the action finishes:

1. download the `ancla-lite-unsigned-ipa-*` artifact from GitHub Actions if you want the installable sideload build
2. use your preferred sideload tool or signing service to re-sign and install it on your iPhone
3. if your signer tries to rewrite the bundle identifier, prefer keeping the default identifier when possible

## What this does not guarantee

The lite build is not the real blocker product loop.

It is a sideload-safe shell for launch, visual verification, and purchase-link testing. It does not perform real app blocking or sticker release.

The full build still depends on Apple entitlement and signing rules for:

- `FamilyControls`
- `ManagedSettings`
- the shield extension
- App Group-backed shared storage
- Core NFC release flow

## Why the `.xcarchive` artifact is also uploaded

The archive is useful if the `.ipa` needs to be repackaged differently later or if you want to inspect the built app bundle and embedded extension layout.
