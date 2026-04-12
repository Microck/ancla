# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased] – 2025-04-12

### Added — iOS App

- **NFC anchor pairing and release**: pair one or more NTAG213 NFC stickers and use them as physical release tokens for active block sessions.
- **Block modes**: create, edit, and delete named block modes that each store a set of shielded apps and web domains via Apple's Family Controls framework.
- **Locked surface**: when a block session is active the app swaps to a full-screen locked surface that prompts the user to scan their paired anchor to release.
- **Shield extension**: custom Screen Time shield UI showing the active mode name and anchor name on blocked app/domain screens.
- **Unlock presets**: save timed unlock windows (e.g. "Check 2FA" for 10 seconds) that temporarily release the block for a short, countdown-tracked period.
- **Paragraph-accuracy failsafe challenge**: opt-in typing challenge that requires exact-match reproduction of a passage as an alternative release path.
- **Scheduled sessions**: create recurring weekly schedules that auto-arm a block mode on chosen days between configurable start and end times.
- **Setup flow**: guided three-step onboarding (Shortcut → Anchor → Mode) for the sideload-lite build variant.
- **Shortcut setup reference**: in-app reference sheet explaining the iOS Shortcuts automation needed for the sideload-lite variant.
- **Runtime diagnostics**: diagnostic overlay for inspecting session state, snapshot integrity, and schedule sync status during development and testing.
- **Schedule notification service**: local notification scheduling for upcoming scheduled session windows.
- **Anchor rename and unpair**: rename or remove paired anchors directly from the home screen.
- **Mode editor**: modal editor for creating and editing block modes with the Family Activity picker.
- **Schedule editor**: modal editor for creating recurring block schedules with day selection and 15-minute time controls.
- **Unlock preset editor**: modal editor for creating timed unlock presets with a live preview card.
- **Emergency unbrick**: fallback path to release a session when normal NFC scanning is unavailable.
- **Temporary unlock banner**: live countdown banner displayed on the home screen while a preset unlock is active.
- **Session history**: recent session log displayed in the Unlock section of the home screen.
- **Dark-mode-first UI**: custom Ancla design system with slate palette, Google Sans Flex typography, and panel-based chrome throughout.
- **App icon and brand assets**: bundled app icon set, brand mark, and anchor SVG used across the app and shield extension.

### Added — Build and CI

- **XcodeGen project**: `ios/project.yml` defining targets for the app, shield extension, and test bundles with Swift 5.10 and iOS 17 deployment target.
- **Full build variant** (`Ancla`): complete app including Family Controls, shield extension, and NFC pairing.
- **Sideload-lite build variant** (`Ancla-Lite`): simplified variant that skips Screen Time authorization and uses local storage instead of app groups.
- **GitHub Actions workflows**:
  - `ios-full-unsigned-ipa.yml`: build unsigned IPA for sideloading.
  - `ios-sideload-ipa.yml`: build and package the full sideload IPA.
  - `ios-sideload-lite-ipa.yml`: build and package the lite sideload IPA.
  - `ios-testflight.yml`: build and distribute via TestFlight.
- **Linux SwiftPM test lane**: `Package.swift` with test target runnable via `swift test` on Linux (Swift 5.10 / Jammy).

### Added — Testing

- **Core tests** (`ancla-core-tests`): coverage for default mode selection, release gating, arm gating, schedule activation, and repair flows.
- **App-level tests** (`ancla-tests`): view model tests covering session lifecycle, mode management, anchor pairing, unlock presets, and schedule editing.
- **App group store tests**: round-trip persistence tests for the shared app group snapshot store.

### Added — Marketing Site

- **Next.js site**: single-page marketing site under `site/` built with Next.js 16, Tailwind CSS 4, and Google Sans Flex.
- Sections covering how Ancla works, NFC scan flow, sticker buying guide, and TestFlight information.

### Added — Documentation and Brand

- **README**: project overview, feature description, installation instructions, sideloading guide, and sticker buying recommendations.
- **Brand assets**: anchor SVG, app icon, naming conventions, and design tokens.
- **Documentation**:
  - `docs/release-checklist.md`: comprehensive pre-release QA checklist.
  - `docs/sideloading.md`: sideloading setup and distribution notes.
  - `docs/testflight-github-actions.md`: TestFlight CI configuration guide.
  - `docs/non-sideloaded-ancla-requirements.md`: requirements for non-sideloaded distribution.
  - `docs/full-sideload-experiment.md`: full sideload experiment documentation.
- **License**: PolyForm Strict 1.0.0 (source-available, not open source).

[Unreleased]: https://github.com/microck/ancla/tree/main
