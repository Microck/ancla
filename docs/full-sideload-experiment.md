# Full Sideload Experiment

This is the exact operator path for the installable sideload `Ancla` experiment:

- sideload-safe app target
- real `CoreNFC`
- local mode/session state
- no embedded blocker extension

It is intentionally tuned to install and open under Feather. The true blocker build with the embedded extension and privileged entitlements still belongs to Apple-managed distribution paths.

## 1. Push the current branch

If you are on the branch you want to test:

```bash
cd /home/ubuntu/workspace/ancla
git status -s -u
git add README.md docs/sideloading.md docs/full-sideload-experiment.md .github/workflows/ios-sideload-ipa.yml ios/Package.swift ios/ancla-shared/ancla-runtime-diagnostics.swift ios/ancla-app/ancla-runtime-diagnostics-live.swift ios/ancla-app/app-view-model.swift ios/ancla-app/content-view.swift ios/ancla-core-tests/ancla-core-tests.swift
GIT_AUTHOR_NAME="Microck" GIT_AUTHOR_EMAIL="contact@micr.dev" \
GIT_COMMITTER_NAME="Microck" GIT_COMMITTER_EMAIL="contact@micr.dev" \
git commit -m "feat: prepare full sideload experiment diagnostics"
git push origin HEAD
```

Only do this after reviewing the diff. Do not blindly stage unrelated files if you do not want them in the experiment build.

## 2. Run the full IPA workflow

From GitHub UI:

1. open `Actions`
2. open `ios-sideload-ipa`
3. click `Run workflow`
4. leave `build_number` empty unless you need a manual override

Or from `gh`:

```bash
cd /home/ubuntu/workspace/ancla
gh workflow run ios-sideload-ipa.yml
gh run watch
```

## 3. Download the artifacts

You want these two artifacts at minimum:

- `ancla-unsigned-ipa-*`
- `ancla-build-report-*`

Optional:

- `ancla-unsigned-xcarchive-*`

If using `gh`:

```bash
cd /home/ubuntu/workspace/ancla
mkdir -p tmp/full-sideload-artifacts
gh run download --dir tmp/full-sideload-artifacts
```

## 4. Check the build report before signing

Open the downloaded `ancla-build-report-*` text file.

Good:

- main app bundle exists
- `AnclaShieldExtension.appex` exists
- bundle ids look like the expected full target
- entitlement source blocks are present in the report

Bad:

- missing shield extension
- wrong bundle ids
- obviously incomplete app bundle layout

If the report is already wrong, do not waste time signing that `.ipa`.

## 5. Sign in Feather

In Feather:

1. import your certificate material
2. import the provisioning profile that matches the app
3. open the unsigned `ancla-unsigned-*.ipa`
4. sign it
5. install it

Bias:

- prefer preserving the default bundle identifiers if Feather gives you that option
- avoid aggressive rewrite options unless the app fails to sign otherwise

## 6. First launch checklist on iPhone

Open the app and read the diagnostics surface before trying to trust the block flow.

What you want:

- `Build` = `Sideload-safe build`
- `NFC` = `Ready`
- `Storage` = `Local store`
- `Screen Time` = `Not required`

What failure usually means:

- generic icon
  - the signed install is still invalid
- immediate exit on open
  - the signed install is still invalid
- `NFC` = `Unavailable`
  - this phone cannot do the sticker scan path

## 7. Real device test order

Once diagnostics look good:

1. tap `Grant Screen Time access` if needed
2. pair the sticker
3. create one block mode
4. arm the mode
5. scan the paired sticker to release
6. scan a different sticker if you want to confirm mismatch handling

## 8. Decision rule after testing

If the app opens cleanly and NFC pairing/release works, the sideload path is good enough for the physical sticker experiment.

If the app still installs with a generic icon or exits immediately, the signed install is still invalid and the next problem is Feather/certificate/profile behavior, not app UI code.

If you need the true blocker build later, you are back in one of these lanes:

- proper Apple-distributed build
- alternate signer/profile setup that truly preserves the needed entitlements
- this sideload-safe build for NFC-only validation
