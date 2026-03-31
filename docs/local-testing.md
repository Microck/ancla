# Local Testing

This repo now has one real Linux-side verification lane and one Apple-only lane.

## What you can test on Linux

- The marketing site:

```bash
cd /home/ubuntu/workspace/ancla/site
pnpm lint
pnpm build
```

- The framework-free app logic in `ios/ancla-shared`:

```bash
cd /home/ubuntu/workspace/ancla
docker run --rm \
  -v "$PWD/ios:/workspace" \
  -w /workspace \
  swift:5.10-jammy \
  swift test
```

That SwiftPM target only includes:

- `ios/ancla-shared/ancla-models.swift`
- `ios/ancla-shared/ancla-core.swift`
- `ios/ancla-shared/ancla-dependencies.swift`

It covers:

- mode ordering
- default-mode repair
- preferred-mode selection
- release eligibility
- arm eligibility

## What still requires a Mac

- generating the Xcode project from `ios/project.yml`
- building the app and shield extension
- running the existing iOS XCTest target
- code signing and TestFlight submission

## What still requires a real iPhone

- NFC sticker scanning through `CoreNFC`
- Screen Time authorization through `FamilyControls.AuthorizationCenter`
- actual app/site shielding through `ManagedSettings`
- verifying that the paired sticker is the only release path

## Why the split exists

Apple's own documentation is explicit about the constraints:

- `CoreNFC` requires a device that supports NFC.
- `CardSession` is not supported in Simulator because it requires NFC hardware.
- `Family Controls` requires the entitlement/capability flow before distribution.
- `AuthorizationCenter` requires the Family Controls capability before requesting authorization.

Useful starting points:

- https://developer.apple.com/documentation/corenfc
- https://developer.apple.com/documentation/corenfc/cardsession/
- https://developer.apple.com/documentation/familycontrols
- https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement
- https://developer.apple.com/documentation/familycontrols/authorizationcenter
- https://developer.apple.com/documentation/managedsettings

## Recommended device pass

On a Mac with Xcode and a physical iPhone:

1. Generate the project with `xcodegen generate`.
2. Build `Ancla` and `AnclaShieldExtension`.
3. Run `AnclaTests`.
4. Install on a real iPhone.
5. Request Screen Time authorization.
6. Pair one NTAG213 sticker.
7. Arm a mode and confirm apps are shielded.
8. Scan a wrong sticker and confirm the session remains armed.
9. Scan the paired sticker and confirm the session releases.
