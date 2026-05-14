# User Testing

Validation surface findings, tool choices, limitations, and concurrency guidance.

**What belongs here:** primary user-testing surfaces, tooling, accepted limitations, and concurrency/resource notes for validators.

---

## Validation Surface

- **Build/test execution lane:** Dockerized Android Gradle runner once established for this mission.
- **Primary remote validation surface:** BrowserStack App Automate on packaged Android artifacts.
- **Primary product under test:** the Android app built in `/home/ubuntu/workspace/ancla/android`.
- **Primary packaged artifact goals:** release `.apk` and/or `.aab` outputs declared by the Android release workflow.
- **Main flows BrowserStack should cover when feasible:**
  - install packaged build
  - launch packaged build
  - setup/readiness shell
  - mode management shell
  - blocked/lock UI checkpoints
  - unlock/failsafe UI checkpoints that do not require physical NFC
  - history/recent-session surfaces

## Accepted Limitations

- BrowserStack is the primary lane, but it is **not** strong proof for:
  - physical NFC anchor scans
  - long-running accessibility-enforcement reliability across OEM/device conditions
- The current Dockerized Android lane does **not** provide a supported local connected-test/ADB path on this host.
- Validators must not overclaim those areas from BrowserStack-only evidence.
- If BrowserStack can only reach UI checkpoints rather than true end-to-end physical-release behavior, syntheses must say so explicitly.

## Validation Concurrency

- Dry-run environment summary:
  - 4 vCPUs
  - ~24 GiB RAM total
  - ~14-15 GiB available during planning dry run
  - swap effectively exhausted during dry run
- Recommended max validator concurrency for this mission: **4**
- Practical starting point: **2-3** concurrent local orchestration jobs, scaling toward 4 remote BrowserStack sessions only if stable.

## Resource Notes

- BrowserStack remote sessions shift much of the runtime load off-machine, but local build/package/upload orchestration still consumes CPU and memory.
- Release packaging plus BrowserStack upload should be treated as moderately heavy local work.
- Avoid unnecessary parallel local Gradle builds on this machine.
