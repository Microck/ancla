---
name: android-release-worker
description: Builds Android release artifacts, wires release traceability, and validates packaged smoke flows with BrowserStack without overclaiming unsupported proof.
---

# Android Release Worker

NOTE: Startup and cleanup are handled by `worker-base`. This skill defines the work procedure.

## When to Use This Skill

Use this worker for:
- Android release packaging
- CI/build workflow updates for release artifacts
- BrowserStack upload/install/launch smoke automation
- artifact provenance and packaged-validation traceability

## Required Skills

None.

## Work Procedure

1. Read mission artifacts, `.factory/library/release.md`, and the assigned release feature carefully.
2. Confirm which packaged artifact set is canonical for the feature (`.apk`, `.aab`, or both) before changing build logic.
3. Add failing or missing verification first:
   - build-script/workflow checks
   - traceability checks
   - BrowserStack smoke automation hooks if they are part of scope
4. Implement packaging and provenance updates.
5. Generate packaged artifacts locally or in CI exactly as the feature requires.
6. Validate the same release candidate through BrowserStack:
   - upload
   - install
   - launch
   - at least one post-launch smoke interaction
7. Explicitly document proof boundaries:
   - what BrowserStack proved
   - what it did not prove (for example NFC or long-running accessibility reliability)
8. Record workflow/job/run linkage in the handoff so the packaged evidence is auditable.

## Example Handoff

```json
{
  "salientSummary": "Implemented Android release packaging with traceable APK/AAB outputs and BrowserStack smoke validation on the same release candidate. Upload, install, launch, and one post-launch smoke interaction passed; the handoff calls out that this does not prove NFC or long-running accessibility reliability.",
  "whatWasImplemented": "Added the Android release packaging workflow, canonical artifact naming, build metadata capture, BrowserStack upload/install/launch smoke automation, and release-candidate traceability from workflow run to BrowserStack app reference.",
  "whatWasLeftUndone": "",
  "verification": {
    "commandsRun": [
      {
        "command": "/home/ubuntu/workspace/ancla/android/gradlew --no-daemon :app:assembleRelease :app:bundleRelease",
        "exitCode": 0,
        "observation": "Release APK and AAB were produced with captured variant metadata."
      },
      {
        "command": "python3 /home/ubuntu/workspace/ancla/android/scripts/browserstack-smoke.py --artifact /home/ubuntu/workspace/ancla/android/app/build/outputs/apk/release/app-release.apk",
        "exitCode": 0,
        "observation": "BrowserStack accepted the upload, installed the same release candidate, launched it, and completed one post-launch smoke interaction."
      }
    ],
    "interactiveChecks": [
      {
        "action": "Reviewed BrowserStack video, screenshots, and device logs for the packaged release candidate.",
        "observed": "The packaged app reached the expected entrypoint and completed the declared smoke interaction; no claim was made for NFC or long-running accessibility reliability."
      }
    ]
  },
  "tests": {
    "added": [
      {
        "file": "android/scripts/browserstack-smoke-test.py",
        "cases": [
          {
            "name": "maps uploaded BrowserStack app reference to the exact build metadata file",
            "verifies": "Release-candidate traceability"
          }
        ]
      }
    ]
  },
  "discoveredIssues": []
}
```

## When to Return to Orchestrator

- BrowserStack credentials are unavailable or invalid.
- Packaging requirements conflict with the approved release scope.
- A build/provenance problem would require changing earlier milestones rather than completing the release feature itself.
- Evidence from BrowserStack is insufficient for the exact contract claim and the feature description needs narrowing.
