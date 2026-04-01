# GitHub Actions TestFlight

This is the lowest-friction path for `ancla` if you only have Windows plus an iPhone.

It uses:

- GitHub-hosted macOS runners to build
- XcodeGen to generate the Xcode project from `ios/project.yml`
- App Store Connect API auth for provisioning and upload
- one Apple Distribution certificate secret for code signing

It does **not** remove the Apple-side prerequisites. The biggest one is still `Family Controls` entitlement approval.

## What this workflow does

The workflow at `.github/workflows/ios-testflight.yml` will:

1. generate the Xcode project on a macOS runner
2. stamp a unique numeric build number into both iOS `Info.plist` files
3. archive `Ancla`
4. export an `.ipa`
5. upload the `.ipa` as a workflow artifact
6. optionally validate and upload it to TestFlight

## Apple-side setup you must finish first

Do this once in the Apple Developer portal and App Store Connect.

### 1. Request and receive the Family Controls entitlement

Without this, the main app and shield extension will not sign correctly for the real product behavior.

### 2. Create the app group

Create:

- `group.dev.micr.ancla`

### 3. Create both bundle identifiers

Create these App IDs:

- `dev.micr.ancla`
- `dev.micr.ancla.shield`

Enable the capabilities that match the repo:

- main app `dev.micr.ancla`
  - App Groups
  - Family Controls
  - Near Field Communication Tag Reading
- extension `dev.micr.ancla.shield`
  - App Groups
  - Family Controls

Attach both targets to:

- `group.dev.micr.ancla`

### 4. Create the App Store Connect app record

Create the app in App Store Connect with the primary bundle ID:

- `dev.micr.ancla`

## GitHub secrets you need

Create these repository secrets in `Microck/ancla`:

| Secret | What it is |
| --- | --- |
| `APPLE_TEAM_ID` | Your Apple Developer Team ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect API issuer ID |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | The full `.p8` private key contents |
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded Apple Distribution `.p12` |
| `P12_PASSWORD` | Password used when exporting the `.p12` |

This workflow intentionally does **not** require provisioning profile secrets. It relies on automatic signing plus `-allowProvisioningUpdates` to keep the setup smaller.

## Windows-friendly certificate path

You do not need a Mac to create the certificate material.

Use Git Bash, WSL, or another OpenSSL-capable shell on Windows.

### 1. Generate a private key and CSR

```bash
openssl req \
  -new \
  -newkey rsa:2048 \
  -nodes \
  -keyout ancla-distribution.key \
  -out ancla-distribution.csr
```

### 2. Create an Apple Distribution certificate

In the Apple Developer portal:

1. go to Certificates
2. create an `Apple Distribution` certificate
3. upload `ancla-distribution.csr`
4. download the resulting `.cer`

### 3. Convert it and export a `.p12`

```bash
openssl x509 \
  -inform DER \
  -in ios_distribution.cer \
  -out ancla-distribution.pem

openssl pkcs12 \
  -export \
  -inkey ancla-distribution.key \
  -in ancla-distribution.pem \
  -out ancla-distribution.p12
```

### 4. Base64-encode the `.p12`

```bash
base64 -w 0 ancla-distribution.p12
```

Save the output as the `BUILD_CERTIFICATE_BASE64` secret.

## App Store Connect API key

Create an App Store Connect API key with permissions that can manage builds for this app.

You need three pieces from that screen:

- issuer ID
- key ID
- downloaded private key `.p8`

Store the `.p8` file contents as the `APP_STORE_CONNECT_PRIVATE_KEY` secret.

## Running the workflow

In GitHub:

1. open `Actions`
2. open `ios-testflight`
3. click `Run workflow`
4. leave `build_number` empty unless you need a manual override
5. leave `upload_to_testflight` enabled for the normal path

If you want a dry run first, set `upload_to_testflight` to `false`. That will still produce an `.ipa` artifact without uploading it.

## What to expect on first failure

If the first run fails, it is usually one of these:

- Family Controls entitlement has not been approved yet
- one or both bundle IDs do not have the right capabilities
- the app group is missing or not attached to both targets
- the distribution certificate secret is wrong
- the App Store Connect API key lacks the needed access

Those are external configuration failures, not repo-code failures.

## What still cannot be proven from this Linux box

I can validate the workflow file shape locally, but not the actual Apple build/upload path here.

Still unverified from this environment:

- signing against your real Apple account
- automatic profile creation for the app and extension
- archive success on the GitHub macOS image
- TestFlight processing in App Store Connect
- on-device NFC + Screen Time behavior after distribution
