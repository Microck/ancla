# Non-sideloaded Ancla Requirements

## Goal

Ship the regular `Ancla` target as the canonical build so the app can use the real Screen Time / shielding path instead of the sideload fallback path.

## Current reality

- The full `Ancla` target already exists and compiles.
- The full target already embeds `AnclaShieldExtension`.
- The main blocker is Apple signing and entitlement alignment, not missing blocker UI.
- `AnclaSideload` remains a ritual / gating layer, not a real system-wide blocker.

## Apple-side requirements

The non-sideloaded build needs a signing setup that matches the full target exactly.

- App bundle id: `dev.micr.ancla`
- Shield extension bundle id: `dev.micr.ancla.shield`
- Shared app group on both targets: `group.dev.micr.ancla`
- `com.apple.developer.family-controls` on both app and shield extension
- NFC tag-reading capability on the app target
- Provisioning profiles that match the app id, extension id, app group, and entitlement set
- A certificate that signs those matching profiles

## Runtime requirements

These must be true on-device before the regular build can actually block apps.

- The app and extension can both read the shared App Group container
- Screen Time authorization is granted
- The shield extension is embedded and loadable
- The selected mode has real managed settings data
- The app no longer shows `Storage unavailable` on launch

## Code paths that matter

The regular build should stay on the full blocker path.

- Use the `Ancla` scheme, not `AnclaSideload`
- Keep `AnclaShieldExtension` embedded in the app target
- Use `AppGroupStore` for persistence, not the local sideload snapshot store
- Use the real shielding service path, not the no-op lite shielding path
- Treat the Shortcut automation as supplemental friction for Apple apps, not the primary blocker

## What does not need major product rework

Most of the full-product surface is already present.

- The full target already compiles
- The shield extension is already packaged in the full archive
- The app already has a strict-mode UI, lock UI, failsafes, presets, and NFC pairing flow
- The conditional Shortcut redirect pattern can be kept for built-in Apple apps even after full blocking works

## What would change if non-sideloaded Ancla became the only supported product

If the project stops supporting the sideload fallback as a product path, then the cleanup should be deliberate rather than mixed into unrelated work.

- Remove or isolate `SIDELOAD_LITE` branches that exist only for sideload behavior
- Remove the no-op lite shielding implementation once the canonical build is the full blocker
- Remove sideload-specific tutorial copy that frames Shortcut automations as the main safety rail
- Keep one canonical persistence and blocking path instead of carrying both long-term

## Verification checklist for the regular build

1. Launch the app and confirm there is no App Group storage error.
2. Grant Screen Time authorization.
3. Save a mode and pair an anchor.
4. Start a block.
5. Open an app included in the block and confirm iOS actually shields it.
6. Release using the paired anchor and confirm the shield is removed.
7. Verify the Shortcut automation only redirects during an active block.

## Fresh IPA blocker from this workspace

Right now, building a truly fresh IPA from the current local changes is still blocked by tooling, not by intent.

- This Linux workspace cannot run Xcode directly.
- GitHub Actions can build an IPA, but only from committed and pushed source.
- The current Shortcut tutorial and App Intent changes are still uncommitted in the local working tree.
