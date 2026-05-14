# Release

Release packaging and BrowserStack validation notes for the Android mission.

**What belongs here:** artifact expectations, traceability rules, BrowserStack boundaries, and packaged-validation evidence rules.

---

- Release packaging is in scope.
- Play submission is out of scope unless new credentials/workflows are explicitly added later.
- If host-local Gradle remains broken, packaged artifacts may be built through the approved Dockerized Android Gradle lane.
- Packaged validation must be traceable to:
  - the exact release artifact path
  - the release variant
  - the producing workflow/job/run or equivalent immutable provenance
- BrowserStack proof should be limited to:
  - upload acceptance
  - installability
  - launch to the expected entrypoint
  - post-launch packaged smoke interaction(s)
  - packaged UI checkpoints reachable without overclaiming NFC/accessibility reliability
- If a packaged validation claim cannot be proven on BrowserStack, validators must either:
  - support it with deterministic tests and narrower wording, or
  - leave it outside the BrowserStack proof lane and state that clearly.
