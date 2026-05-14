---
name: android-core-worker
description: Builds Android foundation, stateful product logic, setup/readiness flows, schedules, unlocks, and history for the Ancla port.
---

# Android Core Worker

NOTE: Startup and cleanup are handled by `worker-base`. This skill defines the work procedure.

## When to Use This Skill

Use this worker for:
- Android project foundation and core app shell work
- setup gating and readiness diagnostics
- mode management and explicit app/browser selection UI
- schedules, timed unlock presets, emergency/failsafe flows
- history, attribution, and other deterministic state-machine work

## Required Skills

- `clanker-discipline` - invoke when designing or refactoring session, readiness, unlock, or history state so the Android port does not drift into ambiguous boolean/optional-field state models.

## Work Procedure

1. Read `mission.md`, mission `AGENTS.md`, `.factory/library/*.md`, and the assigned feature carefully.
2. Inspect the matching iOS source/tests that define the behavior being ported before changing Android code.
3. Invoke `clanker-discipline` before finalizing any new or substantially changed state model.
4. Write or extend failing Android tests first:
   - unit tests for state-machine behavior
   - instrumentation/UI tests when the feature is user-visible
5. Implement the smallest Android-native change set that makes the tests pass.
6. Verify persistence, cleanup, and release-attribution side effects explicitly. Do not assume they are covered by happy-path tests.
7. Run targeted validators first, then broader commands from `.factory/services.yaml` as the feature stabilizes.
   - If the assigned feature is specifically a Gradle/bootstrap repair, a baseline Gradle failure is part of the problem you are fixing. Continue diagnosis within scope instead of stopping immediately, but record the exact failing command and environment evidence.
   - On this host, local connected Android tests are not currently a supported lane. Unless your feature is explicitly about verification infrastructure, do not block completion on `connectedDebugAndroidTest`; use deterministic local tests and let the approved BrowserStack milestone validation cover UI proof.
8. Do one manual sanity pass for the affected Android surface when feasible and record what you actually observed.
9. Leave no watch processes running and include exact commands/observations in the handoff.

## Example Handoff

```json
{
  "salientSummary": "Implemented Android setup gating, readiness diagnostics, and mode CRUD with explicit app/browser selection. Added red-first tests for blocker precedence, default-mode repair, and start gating, then wired the Compose shell to the new state. Ran unit and instrumentation coverage plus a manual clean-install sanity pass.",
  "whatWasImplemented": "Added the Android setup shell, readiness diagnostics surface, persisted setup acknowledgments for the manual Android-only step, mode create/edit/delete flows, explicit target selection, preferred-mode repair logic, and start gating that blocks arming until runtime prerequisites are satisfied.",
  "whatWasLeftUndone": "",
  "verification": {
    "commandsRun": [
      {
        "command": "/home/ubuntu/workspace/ancla/android/gradlew --no-daemon :app:testDebugUnitTest --tests '*Setup*' --tests '*Mode*'",
        "exitCode": 0,
        "observation": "All new setup/mode tests passed, including blocker precedence, default-mode repair, and no-rearm-while-active coverage."
      },
      {
        "command": "/home/ubuntu/workspace/ancla/android/gradlew --no-daemon :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=dev.micr.ancla.setup.SetupFlowTest",
        "exitCode": 0,
        "observation": "Instrumentation smoke passed for setup gating and mode CRUD UI."
      }
    ],
    "interactiveChecks": [
      {
        "action": "Clean-installed the Android app, launched it, completed the manual setup acknowledgment, created a mode, and verified the start CTA stayed disabled until an anchor prerequisite existed.",
        "observed": "Setup remained gated until the required steps were complete, readiness headline changed with the top blocker, and the home shell appeared only after setup completion."
      }
    ]
  },
  "tests": {
    "added": [
      {
        "file": "android/app/src/test/java/dev/micr/ancla/setup/setup-state-test.kt",
        "cases": [
          {
            "name": "ready-state requires capability nfc anchor mode and no active blocking session",
            "verifies": "Runtime ready predicate"
          },
          {
            "name": "default-mode repair promotes first saved mode when persisted data has no default",
            "verifies": "Deterministic preferred-mode repair"
          }
        ]
      }
    ]
  },
  "discoveredIssues": []
}
```

## When to Return to Orchestrator

- Android behavior would require changing the approved product scope or adding domain/network blocking.
- The iOS source-of-truth is ambiguous enough that you cannot tell which behavior to preserve.
- The feature depends on NFC/accessibility/platform wiring that does not exist yet.
- Local Android tooling or build commands from `.factory/services.yaml` are broken in a way you cannot fix within the feature scope.
