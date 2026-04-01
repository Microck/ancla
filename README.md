<div align="center">
  <img src="https://raw.githubusercontent.com/Microck/ancla/main/brand/logo/ancla-app-icon.png" width="140" alt="ancla logo" />

  <h1>ancla</h1>

  <p><strong>iphone app blocking with a paired nfc anchor</strong></p>

  <p>
    <img src="https://img.shields.io/badge/platform-ios%2017%2B-0f172a.svg?style=flat-square" alt="ios" />
    <img src="https://img.shields.io/badge/ui-swiftui-0f172a.svg?style=flat-square" alt="swiftui" />
    <img src="https://img.shields.io/badge/site-next.js%2016-0f172a.svg?style=flat-square" alt="next.js" />
    <img src="https://img.shields.io/badge/model-local--first-0f172a.svg?style=flat-square" alt="local first" />
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
6. no backend in the current path - pairing and comparison stay on-device

---

## quickstart

### web

```bash
cd /home/ubuntu/workspace/ancla/site
pnpm install
pnpm dev
```

### local verification

```bash
cd /home/ubuntu/workspace/ancla/site
pnpm lint
pnpm build
```

```bash
cd /home/ubuntu/workspace/ancla
docker run --rm \
  -v "$PWD/ios:/workspace" \
  -w /workspace \
  swift:5.10-jammy \
  swift test
```

the docker swift lane validates the framework-free core logic only. real nfc scanning, family controls authorization, and managed settings enforcement still need a mac + physical iphone.

for a sideload-first ipa artifact, run the `ios-sideload-ipa` github action and download the unsigned `.ipa` artifact it produces.

for the sideload notes, see [`docs/sideloading.md`](docs/sideloading.md).

for a windows-first release path, see [`docs/testflight-github-actions.md`](docs/testflight-github-actions.md).

---

## sticker

if you want the default answer, buy:

- `NTAG213`
- standard adhesive
- `38 mm` if the listing offers it
- `https://s.click.aliexpress.com/e/_c3De6uih`

only buy on-metal tags if the sticker will live on metal.

---

## repo layout

```text
ancla/
├── ios/      native iphone app, shield extension, shared core, tests
├── site/     next.js marketing site
└── brand/    logo, palette, naming, shared visual direction
```

---

## current constraint

this repo can be developed and partially verified from linux, but the real product loop is still native-ios-only:

- build/signing needs xcode on macos
- the sideload workflow can produce an unsigned `.ipa`, but users still need a sideload tool or signing service to install it
- family controls entitlement behavior needs apple tooling
- corenfc needs a real iphone
- managedsettings shielding needs a real iphone

that is not a documentation gap. it is the product boundary.
