<div align="center">
  <img src="https://raw.githubusercontent.com/Microck/ancla/main/brand/logo/ancla-app-icon.png" width="140" alt="ancla logo" />

  <h1>ancla</h1>

  <p><strong>iphone app blocking with a paired nfc anchor</strong></p>

  <p>
    <img src="https://img.shields.io/badge/platform-ios%2017%2B-0f172a.svg?style=flat-square" alt="ios" />
    <img src="https://img.shields.io/badge/ui-swiftui-0f172a.svg?style=flat-square" alt="swiftui" />
    <img src="https://img.shields.io/badge/site-next.js%2016-0f172a.svg?style=flat-square" alt="next.js" />
    <img src="https://img.shields.io/badge/storage-on--device-0f172a.svg?style=flat-square" alt="on-device" />
  </p>
</div>

ancla is an iphone-first blocker that uses apple screen time controls plus one paired nfc sticker to make distracting apps physically annoying to reopen. instead of putting the override on the same glass surface as the temptation, it moves the release path into the room around you.

---

## why

most blockers fail because the escape hatch is still one tap away. ancla changes the shape of the loop:

- pick the apps and sites you want blocked
- pair one physical sticker
- arm a mode
- walk to the sticker if you really want the apps back

it is meant to create friction, not clever automation theater.

---

## how it works

```text
user picks apps + domains
        │
        ▼
familycontrols selection is saved as a block mode
        │
        ▼
managedsettings shields the selected targets
        │
        ▼
user scans one nfc sticker with corenfc
        │
        ▼
ancla hashes the sticker identifier and stores that local fingerprint
        │
        ▼
release is allowed only when a future scan matches the paired fingerprint
```

wrong stickers do not release the session. the block stays armed until the paired sticker is scanned.

---

## features

1. single-screen native flow for authorize, pair, create mode, arm, and release
2. multiple block modes with default-mode support
3. paired sticker rename, replace, and unpair flows
4. wrong-sticker handling that keeps the session blocked and allows immediate retry
5. shield extension subtitle that reflects the active mode and sticker name
6. no backend in the current path — pairing and comparison stay on-device
7. sideload-safe build variant for testing nfc flow without apple-managed distribution

---

## quickstart

### web (marketing site)

```bash
cd site
pnpm install
pnpm dev
```

### linux: core logic tests

validates the framework-free shared logic without `FamilyControls`, `ManagedSettings`, or `CoreNFC`:

```bash
docker run --rm \
  -v "$PWD/ios:/workspace" \
  -w /workspace \
  swift:5.10-jammy \
  swift test
```

### mac: full build

requires xcode and [xcodegen](https://github.com/yonaskolb/XcodeGen):

```bash
cd ios
xcodegen generate
xcodebuild -project Ancla.xcodeproj -scheme Ancla \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### ios test flight (windows-friendly)

build from github actions without a local mac. see [`docs/testflight-github-actions.md`](docs/testflight-github-actions.md) for the full setup.

### sideload ipa

two github actions workflows produce unsigned `.ipa` artifacts:

- `ios-sideload-ipa` — sideload-safe build with real `CoreNFC`, no shield extension
- `ios-sideload-lite-ipa` — older `AnclaLite` fallback target

for the sideload notes, see [`docs/sideloading.md`](docs/sideloading.md).

---

## sticker

if you want the default answer, buy **`NTAG213`** stickers, standard adhesive, `38 mm` if the listing offers it.

for full buying guidance and marketplace picks, see [`docs/sticker-buying-guide.md`](docs/sticker-buying-guide.md).

only buy on-metal tags if the sticker will live on metal.

---

## repo layout

```text
ancla/
├── ios/      native iphone app, shield extension, shared core, tests
├── site/     next.js marketing site
├── brand/    logo, palette, naming, shared visual direction
└── docs/     guides and reference documentation
```

---

## documentation

| Document | Description |
| --- | --- |
| [`docs/implementation-guide.md`](docs/implementation-guide.md) | product behavior, nfc flow, architecture |
| [`docs/local-testing.md`](docs/local-testing.md) | what can be tested on linux vs mac vs iphone |
| [`docs/sideloading.md`](docs/sideloading.md) | unsigned ipa workflows and post-download steps |
| [`docs/testflight-github-actions.md`](docs/testflight-github-actions.md) | windows-first testflight release path |
| [`docs/sticker-buying-guide.md`](docs/sticker-buying-guide.md) | nfc sticker specs and marketplace links |
| [`docs/release-checklist.md`](docs/release-checklist.md) | pre-release verification checklist |
| [`ios/README.md`](ios/README.md) | ios-specific build, test, and sideload details |

---

## current constraint

this repo can be developed and partially verified from linux, but the real product loop is still native-ios-only:

- build/signing needs xcode on macos
- the sideload workflow can produce an unsigned `.ipa`, but users still need a sideload tool or signing service to install it
- family controls entitlement behavior needs apple tooling
- corenfc needs a real iphone
- managedsettings shielding needs a real iphone

that is not a documentation gap. it is the product boundary.

---

## license

no license file exists in this repository. all rights are reserved by default.
