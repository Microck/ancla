# Ancla Release Checklist

## Design and Brand

1. Confirm slate palette and anchor icon are used across web and iOS.
2. Confirm Google Sans Flex is loaded on web.
3. Confirm no placeholder copy remains.

## Web

1. `pnpm lint` passes in `site`.
2. `pnpm build` passes in `site`.
3. Verify desktop and mobile layout in browser.
4. Verify links:
   - waitlist CTA
   - sticker guide links
   - Apple TestFlight docs link

## Linux Core

1. `docker run --rm -v "$PWD/ios:/workspace" -w /workspace swift:5.10-jammy swift test` passes from repo root.
2. Confirm the SwiftPM lane still covers default repair, preferred mode, release gating, and arm gating.

## iOS

1. Build app and shield extension on Mac.
2. Confirm entitlements and capabilities are valid.
3. Confirm `com.apple.developer.nfc.readersession.formats` includes `TAG`.
4. Confirm bundled Google Sans Flex fonts load in the app.
5. Test on physical device with real NFC sticker.
6. Verify deny path for non-paired sticker.
7. Verify a wrong sticker keeps the session blocked and allows an immediate retry with the correct sticker.
8. Verify shield extension text and branding.
9. Verify shield subtitle includes active mode + sticker name.
10. Verify edit-mode flow updates active armed mode immediately.
11. Verify the single-screen flow renders correctly and all actions are reachable without extra navigation.
12. Verify sticker-buy guidance links open correctly inside the app.
13. Verify the mode editor cannot save a mode with no selected targets.

## Product Behavior

1. Arm mode actually shields selected apps and domains.
2. Release only succeeds with paired sticker.
3. Re-arming works after a release.
4. Persisted snapshot survives app restart.
5. Default-mode changes persist and affect arm behavior.
6. Deleting a mode clears active session if that mode was armed.
7. Sticker rename and unpair flows persist correctly.
8. Mode selection highlights and per-mode arm action stay in sync.
9. Sticker buy guidance matches `README.md`.
10. TestFlight copy matches the current Apple tester/public-link policy.

## QA Artifacts

1. Capture web screenshots (desktop + mobile).
2. Capture iPhone flow screenshots (idle, armed, release, mismatch).
3. Capture one short demo video of pairing and release.
