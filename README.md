<p align="center">
  <img src=".github/assets/ancla-readme-icon.png" alt="ancla" width="100">
</p>

<h1 align="center">ancla</h1>

<p align="center">
  <strong>an iphone app blocker built around one paired nfc anchor</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-ios%2017%2B-0f172a.svg?style=flat-square" alt="ios badge">
  <img src="https://img.shields.io/badge/unlock-paired%20nfc-0f172a.svg?style=flat-square" alt="nfc badge">
  <img src="https://img.shields.io/badge/model-on--device-0f172a.svg?style=flat-square" alt="on-device badge">
  <img src="https://img.shields.io/badge/ui-swiftui-0f172a.svg?style=flat-square" alt="swiftui badge">
</p>

<p align="center">
  <img src=".github/assets/ancla-readme-banner.jpg" alt="ancla banner" width="800">
</p>

---

`ancla` is a native iphone blocker that makes the release path physical. you pick the apps and sites you want blocked, pair one nfc anchor, arm a mode, and walk back to that same anchor when you want the block lifted.

the point is not automation for its own sake. the point is friction.

[sticker guide](docs/sticker-buying-guide.md) | [installation notes](docs/sideloading.md) | [local testing](docs/local-testing.md) | [implementation guide](docs/implementation-guide.md)

## why

most blockers fail because the override lives on the same screen as the temptation. `ancla` changes that loop.

- pair one specific anchor instead of trusting any random nfc tag
- keep pairing and session state on the device
- use apple screen time surfaces for the full blocker path
- make the unblock ritual annoying on purpose

## how it works

1. grant screen time access on iphone
2. choose the apps and domains you want blocked
3. pair one physical nfc anchor
4. arm a mode
5. scan the paired anchor later to release it

wrong tags do not release the session. the point is to tie the exit path to one object in the room, not another tap in the app.

## what you need

- an iphone with nfc support
- one `ntag213` sticker
- normal adhesive for desks, walls, wood, glass, or plastic
- `on-metal` only if the sticker will live on metal

if you want the default buy, use `ntag213`, prefer `25 mm` minimum, and choose `38 mm` when the listing offers it. the exact links are in [docs/sticker-buying-guide.md](docs/sticker-buying-guide.md).

## installation

if you just want to get the app onto your phone, use the direct ipa path in [docs/sideloading.md](docs/sideloading.md). that keeps installation brief here and keeps the changing signing details out of the README.

if you want the full entitlement-backed blocker loop on a real iphone, use the native iOS path described in [docs/implementation-guide.md](docs/implementation-guide.md).

## local verification

run the web surface:

```bash
cd site
pnpm install
pnpm dev
```

run the checks:

```bash
cd site
pnpm lint
pnpm build
```

run the shared swift logic tests from linux:

```bash
cd /path/to/ancla

docker run --rm \
  -v "$PWD/ios:/workspace" \
  -w /workspace \
  swift:5.10-jammy \
  swift test
```

the linux lane covers the shared core logic. real nfc reads, screen time authorization, and managed settings enforcement still need a physical iphone.

## repo layout

```text
ancla/
├── ios/      native iphone app, shared logic, shield extension, tests
├── site/     next.js site
├── docs/     install, testing, implementation, and sticker notes
└── brand/    canonical brand assets and visual direction
```
