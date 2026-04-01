# Sideloading

This repo now has a sideload-first workflow that produces an unsigned `.ipa` artifact.

Workflow:

- `.github/workflows/ios-sideload-ipa.yml`

## What it does

1. runs on a GitHub-hosted macOS runner
2. installs `xcodegen`
3. generates the Xcode project from `ios/project.yml`
4. builds an unsigned `.xcarchive` with code signing disabled
5. packages `Payload/Ancla.app` into an unsigned `.ipa`
6. uploads both the `.ipa` and the `.xcarchive` as artifacts

## Why unsigned

This avoids the full App Store Connect / TestFlight / Apple signing setup just to get a testable bundle artifact.

That keeps the first build path simple, but it also means the workflow does not solve installation by itself.

## What you do after download

After the action finishes:

1. download the `ancla-unsigned-ipa-*` artifact from GitHub Actions
2. use your preferred sideload tool or signing service to re-sign and install it on your iPhone

## What this does not guarantee

This is just the packaging lane.

It does not guarantee that all of Ancla's Apple-managed behavior will work after sideloading, especially:

- `FamilyControls`
- `ManagedSettings`
- the shield extension
- App Group-backed shared storage

Those behaviors depend on Apple entitlement and signing rules that this workflow intentionally skips.

## Why the `.xcarchive` artifact is also uploaded

The archive is useful if the `.ipa` needs to be repackaged differently later or if you want to inspect the built app bundle and embedded extension layout.
