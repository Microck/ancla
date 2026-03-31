# Ancla Sticker Buying Guide

This is the current buying guidance for Ancla's paired NFC sticker flow.

## Exact recommendation

If you want the single best default buy for Ancla, buy this:

- `https://s.click.aliexpress.com/e/_c3De6uih`
- choose the `38 mm` variant if the listing offers it
- use the normal adhesive version, not an anti-metal version

Why this one:

- it matches the right chip family: `NTAG213`
- it matches the right size guidance for iPhone reliability
- it is the cleanest default recommendation for a user who just wants one answer

## Default spec

- Buy `NTAG213`.
- Prefer `25 mm` round stickers at minimum.
- Prefer `38 mm` if a seller offers it at a reasonable price because larger antennas are easier to scan on iPhone.
- Use standard adhesive tags for plastic, paper, wood, glass, desks, walls, and cases that are not metal-backed.
- Use `on-metal` or `anti-metal` NTAG213 tags only when the sticker will sit on aluminum, steel, or another metal surface.

## Why this is the default

- Apple Core NFC supports the tag-reading path Ancla needs on iPhone.
- NXP's official `NTAG213/215/216` line is NFC Forum Type 2 and the main difference between those three is user memory size: `144 / 504 / 888 bytes`.
- Ancla only needs the tag identifier for pairing and release, so extra memory from `NTAG215` or `NTAG216` does not materially help the v1 product.
- Community reports consistently point toward `NTAG21x` working better on iPhone than MIFARE-class alternatives.
- Community reports also warn against very small stickers because iPhone scan reliability drops as the antenna gets smaller.

## Avoid these as the default

- `MIFARE Classic`
- tiny `10 x 10 mm` style stickers
- metal mounting with a standard sticker
- paying extra for `NTAG215` or `NTAG216` unless you have a separate tag-storage use case

## Marketplace picks

Prices drift. Use these as current verified listing targets, not permanent price guarantees.

| Marketplace | Pick | Why | URL |
| --- | --- | --- | --- |
| Amazon | Best overall: Fongwah `NTAG213` sticker pack | Stable standard NTAG213 adhesive listing and a good default for non-metal placements. | https://www.amazon.com/Stickers-Adhesive-Compatible-NFC-Enabled-Smartphones/dp/B07GFHLZD1 |
| Amazon | Cheapest acceptable: `25 mm` NTAG213 circular sticker pack | Smaller upfront pack and explicit `25 mm` round NTAG213 form factor. | https://www.amazon.com/Sticker-Circular-writable-programmable-Compatible/dp/B0GFMDJX4Q |
| Amazon | On-metal fallback: GoToTags `30 mm` on-metal NTAG213 | Use only if the sticker must live on metal. | https://www.amazon.com/Blank-White-Metal-NFC-Tag/dp/B01135KABO |
| AliExpress | Best overall: `50Pcs/Lot 25mm/38mm White NFC 213 Stickers` | Choose the `38 mm` option when available for easier iPhone reads. This is the default Ancla recommendation. | https://s.click.aliexpress.com/e/_c3De6uih |
| AliExpress | Cheapest acceptable: `Round 25mm NFC Stickers NTAG213` | Smaller-pack fallback with the right chip and enough marketplace traction to be usable. | https://s.click.aliexpress.com/e/_c3SMBZ1j |
| AliExpress | On-metal fallback: `Diameter 25mm Ntag213/215 Anti-Metal NFC Tag` | Only for metal surfaces. | https://s.click.aliexpress.com/e/_c3GSnHd7 |

## TestFlight note

- Other users can use Ancla through TestFlight as `external testers`.
- Apple allows up to `10,000` external testers per app.
- External testing can use direct email invites or a public link.
- The first external build requires TestFlight review before the public link route is available.

## Research notes

- Official Apple sources used:
  - `Invite external testers - App Store Connect Help`
  - `TestFlight overview - App Store Connect Help`
  - `TestFlight - Apple Developer`
- Official NFC chip source used:
  - NXP `NTAG213/215/216` product page and datasheet
- Community validation used:
  - Reddit threads on iPhone NFC compatibility and larger antenna recommendations
