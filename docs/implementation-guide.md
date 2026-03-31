# Ancla Implementation Guide

This is the operator guide for shipping the current `ancla` workspace.

## 1) Product behavior

Ancla uses Apple Screen Time APIs and one paired NFC sticker.

1. User grants Screen Time access (`FamilyControls`).
2. User chooses apps and domains to block (`FamilyActivitySelection`).
3. User scans and pairs one NFC sticker (`CoreNFC`).
4. User arms a block mode (`ManagedSettingsStore` shields selected targets).
5. To release, user must scan the paired sticker.
6. If scanned UID fingerprint matches, shields clear. If not, unlock is denied.

Current app frontend supports:

- a single-screen native control flow,
- mode creation with target selection summary,
- mode editing for name, selected targets, and default assignment,
- default mode assignment,
- mode-specific arm action,
- mode deletion with active-session cleanup,
- sticker pair, rename, replace, and unpair flows.
- shield extension subtitle that reflects active mode and paired sticker names.

## 2) What NFC scanning does

When scanning:

1. iPhone reads NFC tag identifier bytes from the sticker.
2. App hashes those bytes with SHA-256.
3. App compares the hash with the stored paired hash.
4. Match = release is allowed.
5. Mismatch = release denied.

No cloud lookup is required in this v1 path.

## 3) How this differs from basic NFC automations

Simple NFC shortcut flows:

- usually trigger an action from any scanned compatible tag,
- are easy to bypass from the same phone surface,
- do not enforce Screen Time shields directly.

Ancla flow:

- ties release to one specific paired tag fingerprint,
- keeps blocking under `ManagedSettings` policy control,
- makes the unlock physically inconvenient by design.

## 4) Repo map

- `site` - Next.js marketing frontend
- `ios` - SwiftUI app, CoreNFC, Screen Time integration, shield extension
- `brand` - brand tokens and anchor direction

## 5) Web app runbook

```bash
cd /home/ubuntu/workspace/ancla/site
pnpm install
pnpm dev
```

Checks:

```bash
pnpm lint
pnpm build
```

## 6) Linux-native verification

What can be verified from this workspace right now:

```bash
cd /home/ubuntu/workspace/ancla
docker run --rm \
  -v "$PWD/ios:/workspace" \
  -w /workspace \
  swift:5.10-jammy \
  swift test
```

This validates the framework-free core in:

- `ios/ancla-shared/ancla-models.swift`
- `ios/ancla-shared/ancla-core.swift`
- `ios/ancla-shared/ancla-dependencies.swift`

## 7) iOS runbook (Mac required)

Prereqs:

- Xcode (latest stable)
- Apple Developer account with required capabilities
- iPhone test device (CoreNFC does not work in Simulator)

Steps:

1. Open `/home/ubuntu/workspace/ancla/ios`.
2. Generate Xcode project from `project.yml` (if using XcodeGen).
3. Configure signing for app + shield extension.
4. Enable capabilities:
   - Family Controls / Managed Settings
   - App Groups (`group.dev.micr.ancla`)
   - Near Field Communication Tag Reading
   - NFC entitlement format `TAG`
5. Build and run on physical iPhone.
6. Verify the full loop:
   - authorize,
   - select blocked apps/sites,
   - pair sticker,
   - arm mode,
   - release with correct sticker,
   - fail release with wrong sticker.

## 8) NFC sticker procurement

Recommended for v1:

- NTAG213 adhesive stickers
- Prefer 25 mm minimum, or 38 mm when a seller offers it
- Use standard adhesive stickers unless the sticker will be mounted on metal
- Keep one sticker dedicated as the paired anchor
- See `docs/sticker-buying-guide.md` for concrete Amazon and AliExpress targets

## 9) Current constraints

- Linux workspace cannot compile or run iOS targets.
- Linux workspace can validate the framework-free core with Docker Swift tests.
- Native Apple-framework behavior still requires Mac verification before release.

## 10) Recommended macOS verification commands

```bash
cd /home/ubuntu/workspace/ancla/ios
xcodegen generate
xcodebuild -project Ancla.xcodeproj -scheme Ancla -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -project Ancla.xcodeproj -scheme AnclaTests -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## 11) Web app vs native scope

- The core Ancla behavior must stay native iOS.
- A web app on iPhone cannot call `FamilyControls` / `ManagedSettings` to block installed apps.
- Safari web apps also do not provide the native NFC tag-reading path required for this product loop.
- Web remains useful for marketing, waitlist, and account surfaces, but not for the enforcement loop.

## 12) TestFlight distribution

- Other users can use Ancla through TestFlight as external testers.
- Apple allows up to 10,000 external testers per app.
- External testing can use email invites or a public link.
- The first external build sent to an external group requires TestFlight review before open public-link distribution.
