<div align="center">
  <img src="https://raw.githubusercontent.com/Microck/ancla/main/brand/logo/ancla-app-icon.png" width="140" alt="ancla logo" />

  <h1>ancla</h1>

  <p><strong>iPhone app blocking with a paired NFC anchor</strong></p>

  <p>
    <img src="https://img.shields.io/badge/platform-ios%2017%2B-0f172a.svg?style=flat-square" alt="ios" />
    <img src="https://img.shields.io/badge/ui-swiftui-0f172a.svg?style=flat-square" alt="swiftui" />
    <img src="https://img.shields.io/badge/site-next.js%2016-0f172a.svg?style=flat-square" alt="next.js" />
    <img src="https://img.shields.io/badge/model-local--first-0f172a.svg?style=flat-square" alt="local first" />
  </p>
</div>

Ancla is an iPhone-first blocker that uses Apple App Controls plus one paired NFC anchor to make distracting apps physically inconvenient to reopen. Instead of keeping the override on the same glass surface as the temptation, it moves the release path into the room around you.

---

## Why

Most blockers fail because the escape hatch is still one tap away. Ancla changes the shape of the loop:

- pick the apps and sites you want blocked
- pair one physical anchor
- arm a mode
- walk to the anchor if you really want the apps back

It is meant to create friction, not clever automation.

---

## How It Works

```text
user picks apps + domains
        │
        ▼
App Controls selection is saved as a block mode
        │
        ▼
managedsettings shields the selected targets
        │
        ▼
user scans one NFC anchor with Core NFC
        │
        ▼
Ancla hashes the tag identifier and stores that local fingerprint
        │
        ▼
release is allowed only when a future scan matches the paired fingerprint
```

Wrong tags do not release the session. The block stays active until the paired anchor is scanned.

---

## Features

1. Single-screen native flow for authorize, pair, create mode, arm, and release.
2. Multiple block modes with default-mode support.
3. Paired anchor rename, replace, and unpair flows.
4. Wrong-tag handling that keeps the session active and allows immediate retry.
5. Shield extension subtitle that reflects the active mode and anchor name.
6. No backend in the current path - pairing and comparison stay on-device.

---

## Quickstart

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

The Docker Swift lane validates the framework-free core logic only. Real NFC scanning, App Controls authorization, and Managed Settings enforcement still need a Mac and a physical iPhone.

Run `ios-sideload-ipa` if you want the installable iPhone build that is intended for direct IPA distribution while keeping the real NFC anchor flow.

Run `ios-sideload-lite-ipa` only if you specifically want the older secondary fallback target.

For installation notes, see [`docs/sideloading.md`](docs/sideloading.md).

For a Windows-first release path, see [`docs/testflight-github-actions.md`](docs/testflight-github-actions.md).

---

## Recommended Tag

If you want the default answer, buy:

- `NTAG213`
- standard adhesive
- `38 mm` if the listing offers it
- `https://s.click.aliexpress.com/e/_c3De6uih`

Only buy on-metal tags if the anchor will live on metal.

---

## Repo Layout

```text
ancla/
├── ios/      native iphone app, shield extension, shared core, tests
├── site/     next.js marketing site
└── brand/    logo, palette, naming, shared visual direction
```

---

## Current Constraint

This repo can be developed and partially verified from Linux, but the real product loop is still native iOS:

- build/signing needs xcode on macos
- the IPA workflow can produce an unsigned `.ipa`, but users still need a signing or installation path
- App Controls entitlement behavior needs Apple tooling
- Core NFC needs a real iPhone
- Managed Settings shielding needs a real iPhone

That is not a documentation gap. It is the product boundary.
