---
name: android-platform-worker
description: Implements Android platform integrations for the Ancla port, including NFC, accessibility-driven blocking, and lock-surface behavior.
---

# Android Platform Worker

NOTE: Startup and cleanup are handled by `worker-base`. This skill defines the work procedure.

## When to Use This Skill

Use this worker for:
- NFC anchor pairing/scan integration
- session binding to specific anchors
- accessibility-driven blocking behavior
- lock-surface presentation and blocked-state UX
- Android-specific permission/capability plumbing tied directly to enforcement

## Required Skills

None.

## Work Procedure

1. Read the assigned feature, mission artifacts, and the matching iOS platform behavior before changing Android code.
2. Identify which parts are true platform responsibilities versus product-state logic. Keep product rules in shared Android core/state code where possible.
3. Write failing tests first:
   - unit tests for state transitions and cleanup invariants
   - instrumentation tests for user-visible blocking/lock behavior
4. Implement platform hooks carefully:
   - NFC pairing/scan paths
   - accessibility capability wiring
   - blocked/lock UI surfaces
5. Verify negative paths explicitly:
   - wrong anchor
   - duplicate pairing
   - unpaired anchor
   - unselected app open
   - blocked presentation suppression during temporary unlock
6. Run targeted Gradle tests and at least one manual platform sanity check when feasible.
   - On this host, local connected Android tests are not currently a supported lane. Unless your feature is explicitly about verification infrastructure, do not block completion on `connectedDebugAndroidTest`; use deterministic local tests and leave UI proof to the approved BrowserStack milestone validation.
7. If BrowserStack cannot truthfully prove a platform claim, say so in the handoff rather than overstating proof.
8. On this mission, workers may create the clean local commits required for mission success handoffs, but only on branch `mission/ancla-android-port`. Never push and never modify git config.
9. Stop any long-running platform/debug processes you started.

## Example Handoff

```json
{
  "salientSummary": "Implemented Android NFC pairing/session binding and accessibility-driven blocked UI for selected targets. Added tests for duplicate pairing, wrong-anchor mismatch, selected-vs-unselected target enforcement, and blocked-presentation suppression during temporary unlock. Manual check confirmed the blocked surface and retry flow.",
  "whatWasImplemented": "Added NFC anchor persistence and scan matching, bound live sessions to the scanned paired anchor, surfaced mismatch feedback for wrong-anchor release attempts, wired selected-target interception to the Android blocked surface, and kept the blocked UI tied to the active session details.",
  "whatWasLeftUndone": "",
  "verification": {
    "commandsRun": [
      {
        "command": "/home/ubuntu/workspace/ancla/android/gradlew --no-daemon :app:testDebugUnitTest --tests '*Anchor*' --tests '*Blocking*'",
        "exitCode": 0,
        "observation": "All NFC/session-binding and blocking contract tests passed."
      },
      {
        "command": "/home/ubuntu/workspace/ancla/android/gradlew --no-daemon :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=dev.micr.ancla.blocking.BlockingFlowTest",
        "exitCode": 0,
        "observation": "Instrumentation checks passed for blocked-surface rendering and selected-target routing."
      }
    ],
    "interactiveChecks": [
      {
        "action": "Paired two anchors, armed with the second anchor, attempted wrong-anchor release, then retried with the correct anchor.",
        "observed": "Wrong-anchor attempt left the session blocking with visible mismatch feedback, and the correct anchor ended the same session."
      }
    ]
  },
  "tests": {
    "added": [
      {
        "file": "android/app/src/test/java/dev/micr/ancla/nfc/anchor-session-test.kt",
        "cases": [
          {
            "name": "arming binds the exact scanned anchor",
            "verifies": "Session ownership follows the scanned paired anchor"
          },
          {
            "name": "wrong-anchor release attempt does not create history or clear blocking",
            "verifies": "Mismatch behavior"
          }
        ]
      }
    ]
  },
  "discoveredIssues": []
}
```

## When to Return to Orchestrator

- Android platform behavior needed for the feature conflicts with the approved BrowserStack/validation limits.
- A claim would require VPN/domain blocking or another out-of-scope platform layer.
- The feature needs hardware/device proof that cannot be responsibly represented with the currently available validation lane.
- The Android permission or platform model requires a product decision not captured in mission artifacts.
