# BrowserStack Shortcuts Verification

## Goal

Establish what BrowserStack can actually verify for Ancla's Shortcut-based sideload flow, and what still requires a physical iPhone.

## Build under test

- GitHub Actions run: `24281224336`
- Signed IPA: `tmp/run-24281224336/ancla-signed-29.ipa`
- BrowserStack app url: `bs://66b0df4db55cc617754e518733b054af9a8a148b`
- App bundle id: `dev.micr.ancla.sideload`

## What was tested

### BrowserStack-valid flow

The BrowserStack probe opens Ancla, creates a mode, enables strict mode, opens the in-app Shortcut setup sheet, and records whether the Shortcuts system app can be foregrounded from the same Appium session.

- Probe script: `tmp/browserstack-shortcuts-boundary.py`

### Device matrix

1. `iPhone 15 / iOS 17`
2. `iPhone 14 / iOS 18`

## Result

### What BrowserStack can verify

BrowserStack can verify the Ancla-owned part of the flow:

- the mode editor opens
- strict mode can be enabled
- the Shortcut setup sheet opens
- the setup copy is visible and scannable

Artifacts:

- `tmp/run-24281224336/browserstack-shortcuts-boundary-iphone-15`
- `tmp/run-24281224336/browserstack-shortcuts-boundary-iphone-14-ios18`

### What BrowserStack could not do

BrowserStack could not foreground Apple Shortcuts from the same real-device session.

#### `iPhone 15 / iOS 17`

`driver.activate_app("com.apple.shortcuts")` failed with:

`Application "com.apple.shortcuts" is unknown to FrontBoard.`

Source:

- `tmp/run-24281224336/browserstack-shortcuts-boundary-iphone-15/summary.json`

#### `iPhone 14 / iOS 18`

`driver.activate_app("com.apple.shortcuts")` failed with:

`Unable to launch com.apple.shortcuts because it is restricted.`

Source:

- `tmp/run-24281224336/browserstack-shortcuts-boundary-iphone-14-ios18/summary.json`

### Practical conclusion

BrowserStack is valid for:

- verifying Ancla's Shortcut tutorial and setup UI
- verifying the conditional redirect logic that Ancla exposes through App Intents and copy
- verifying visible in-app states before and after block activation

BrowserStack is not valid for:

- opening Apple Shortcuts reliably as part of the same automated session
- proving that a personal automation such as `When App Is Opened` actually fired because iOS triggered it
- proving the end-to-end redirect workaround without a physical iPhone

## Required physical-device-only checks

These still need a real iPhone owned by the tester:

1. Create the personal automation in Apple Shortcuts.
2. Include all target apps in the same automation trigger list.
3. Confirm `Get Block Status` returns `true` during an active block and `false` otherwise.
4. Open a blocked app while the block is active and confirm iOS redirects into Ancla.
5. Open the same app with no active block and confirm it does not redirect.

## Why this matters

This confirms the current sideload product boundary:

- Ancla can guide the Shortcut setup.
- BrowserStack can verify Ancla's side of that setup.
- The Apple Shortcuts execution path remains outside reliable BrowserStack coverage.
