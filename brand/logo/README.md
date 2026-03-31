# Ancla Logo Assets

## Canonical source

- `ancla-app-icon.png`

This is the current selected raster app icon source for Ancla.

## Generation

- Generated with `egaki`
- Model: `vertex/imagen-4.0-ultra-generate-001`
- Direction: real anchor, slate palette, minimal productivity icon, no text

## Derived outputs

- `ios/ancla-app/assets.xcassets/AppIcon.appiconset/` contains iPhone + marketing icon exports derived from the canonical source.
- `site/app/favicon.ico` is derived from the same canonical source for local web branding consistency.

## Notes

- Several alternates were generated during exploration, but `ancla-app-icon.png` is the selected default because it reads cleanly at icon size and does not include hallucinated text.
