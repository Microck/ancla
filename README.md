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

[installation notes](docs/sideloading.md)

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

if you want the default buy, use `ntag213`, prefer `25 mm` minimum, and choose `38 mm` when the listing offers it.

## sticker buying guide

buy `ntag213`. that is the clean default for `ancla`.

why this one:

- iphone compatibility is the main priority, not extra tag memory
- `ancla` only needs a reliable unique tag identifier for pairing and release
- larger round stickers are easier to scan on iphone than tiny tags
- `on-metal` only matters when you are mounting the sticker on metal

avoid these as the default:

- `mifare classic`
- tiny `10 x 10 mm` stickers
- `ntag215` or `ntag216` unless you have some other memory-heavy use case
- standard stickers on metal surfaces

recommended buys:

| marketplace | pick | notes | link |
| --- | --- | --- | --- |
| aliExpress | `ntag213` round sticker, `38 mm` if available | best default buy for `ancla` | https://s.click.aliexpress.com/e/_c3De6uih |
| aliExpress | `ntag213` round sticker, `25 mm` | smaller fallback if you want a cheaper pack | https://s.click.aliexpress.com/e/_c3SMBZ1j |
| aliExpress | `ntag213` anti-metal tag | only if the sticker will live on metal | https://s.click.aliexpress.com/e/_c3GSnHd7 |
| amazon | fongwah `ntag213` sticker pack | straightforward non-metal default | https://www.amazon.com/Stickers-Adhesive-Compatible-NFC-Enabled-Smartphones/dp/B07GFHLZD1 |
| amazon | gotoTags on-metal `ntag213` | use only for metal mounting | https://www.amazon.com/Blank-White-Metal-NFC-Tag/dp/B01135KABO |

## installation

if you just want to get the app onto your phone, use the direct ipa path in [docs/sideloading.md](docs/sideloading.md). that keeps installation brief here and keeps the changing signing details out of the README.

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
├── docs/     sideloading notes and working prompts
└── brand/    canonical brand assets and visual direction
```
