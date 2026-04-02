# Ancla Logo Assets

## Canonical source

- `ancla-app-icon.png`
- `ancla-anchor.svg`

The PNG is the canonical app icon source.
The SVG is the canonical in-app anchor mark source.

## Source

- Replaced with the user-provided skeuomorphic anchor icon.
- Visual direction: slate palette, beveled anchor mark, rounded-square app icon, no text.

## Derived outputs

- `ios/ancla-app/assets.xcassets/AppIcon.appiconset/` contains iPhone + marketing icon exports derived from the canonical source.
- `ios/ancla-app/assets.xcassets/brand-mark.imageset/brand-mark.png` is derived from the SVG and should keep a transparent background for templated in-app rendering.
- `site/app/favicon.ico` is derived from the same canonical source for local web branding consistency.

## Notes

- The current source is the uploaded final icon, not the earlier generated alternates.
