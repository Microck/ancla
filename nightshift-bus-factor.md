# Nightshift: Bus-Factor Analysis — Ancla

**Repo:** Microck/ancla  
**Task:** Bus-Factor Analyzer  
**Date:** 2026-04-03  
**Analyzer:** Nightshift v3 (GLM 5.1)

## Executive Summary

Ancla is a Swift iOS app implementing screen-time management via Apple's Family Controls / Screen Time API. The codebase is a single-developer project with **25 Swift files** across 5 modules. The bus factor is **1** — a single contributor authored all code, and several critical modules lack test coverage or documentation.

The architecture is well-structured (shared core, app layer, tests, shield extension, lite variant) but concentrates critical domain logic in two files: `ancla-core.swift` (business rules) and `app-view-model.swift` (state management). Both are 160-500 lines with no supplementary documentation.

### Bus Factor Score: 1/10 (single point of failure)

---

## Findings

### P1 — Critical Bus-Factor Risks

#### 1. Single-author codebase — no knowledge distribution
- **Files:** All 25 Swift files
- **Severity:** P1
- **Description:** Every file in the repo appears authored by a single developer. There are no CONTRIBUTING.md, no architecture docs (beyond a brief README), and no code comments explaining "why" decisions. If the author is unavailable, onboarding a new developer requires reverse-engineering the entire codebase.
- **Recommendation:** Add ARCHITECTURE.md documenting module boundaries, data flow, and key design decisions. Add inline doc comments to public APIs in `ancla-shared/`.

#### 2. AppViewModel is a god object (501 lines)
- **File:** `ios/ancla-app/app-view-model.swift`
- **Severity:** P1
- **Description:** `AppViewModel` handles 11+ action types (refresh, authorize, pairAnchor, armSession, releaseSession, emergencyUnbrick, renameAnchor, removeAnchor, saveMode, saveSchedule, removeSchedule) plus all draft state management. It's the single point where UI, business logic, and persistence converge. Any change to the app must touch this file.
- **Recommendation:** Split into focused view models: `SessionViewModel`, `AnchorViewModel`, `ScheduleViewModel`, `ModeViewModel`. Each manages its own state and actions.

#### 3. AnclaCore is irreplaceable domain logic (162 lines)
- **File:** `ios/ancla-shared/ancla-core.swift`
- **Severity:** P1
- **Description:** Contains all scheduling algorithms (minuteOfDay, sortedScheduledPlans, schedule activation logic), block mode management, and the core business rules. No documentation exists for the scheduling algorithm — its correctness depends on subtle calendar/timezone behavior.
- **Recommendation:** Add doc comments to every function. Write a DESIGN.md explaining the scheduling model (plans, sessions, weekday matching).

#### 4. Shield Configuration Extension has zero tests
- **File:** `ios/ancla-shield-extension/shield-configuration-extension.swift`
- **Severity:** P1
- **Description:** The shield extension is what actually enforces screen time blocking. It's the critical path — if it fails, blocking doesn't work. Yet it has no unit tests and no documentation of expected behavior for different shield configurations.
- **Recommendation:** Add XCTest target for shield extension. Test all ShieldConfiguration cases.

### P2 — Moderate Bus-Factor Risks

#### 5. Test coverage is sparse — only 3 test files
- **Files:** `ios/ancla-core-tests/`, `ios/ancla-tests/`
- **Severity:** P2
- **Description:** Only 3 test files exist: `ancla-core-tests.swift`, `app-view-model-tests.swift`, `app-group-store-tests.swift`. Missing test coverage for: `ancla-services.swift` (3 classes), `ancla-runtime-diagnostics.swift`, shield extension, `content-view.swift`, all editor views.
- **Recommendation:** Prioritize tests for `ancla-services.swift` (AuthorizationClient, ShieldingService, StickerPairingService) since these interact with Apple system APIs.

#### 6. AnclaServices contains 3 unrelated service classes (179 lines)
- **File:** `ios/ancla-shared/ancla-services.swift`
- **Severity:** P2
- **Description:** `AuthorizationClient`, `ShieldingService`, and `StickerPairingService` are all in one file. They have no relationship to each other beyond being "services." A developer fixing one service must parse unrelated code.
- **Recommendation:** Split into separate files: `AuthorizationClient.swift`, `ShieldingService.swift`, `StickerPairingService.swift`.

#### 7. Runtime diagnostics module is undocumented (291 lines)
- **File:** `ios/ancla-shared/ancla-runtime-diagnostics.swift`
- **Severity:** P2
- **Description:** The diagnostics system is 291 lines with 3 structs and 8 functions but no documentation explaining what it tracks, when it's triggered, or how to interpret the output. It's used in production (live implementation in `ancla-runtime-diagnostics-live.swift`) but would be opaque to a new developer.
- **Recommendation:** Add module-level doc comment explaining the diagnostics philosophy. Add inline comments to `RuntimeDiagnostics` struct fields.

#### 8. Content view is a monolithic SwiftUI file (501 lines)
- **File:** `ios/ancla-app/content-view.swift`
- **Severity:** P2
- **Description:** The main content view is 501 lines — unusual for SwiftUI where composition into subviews is idiomatic. This suggests the view hierarchy is deeply nested rather than decomposed. A new contributor must understand the entire file to modify any single screen.
- **Recommendation:** Extract logical sections into child views (e.g., `DashboardView`, `AnchorListView`, `ScheduleListView`).

### P3 — Low Bus-Factor Risks

#### 9. No Package.swift documentation (36 lines)
- **File:** `ios/Package.swift`
- **Severity:** P3
- **Description:** The SPM manifest has no comments explaining why certain dependencies are chosen or what targets are for. The `AnclaCore` library target and test targets lack description.
- **Recommendation:** Add comments to Package.swift explaining module structure.

#### 10. Sideload lite variant is minimally documented
- **File:** `ios/ancla-lite/ancla-lite-support.swift`
- **Severity:** P3
- **Description:** The lite variant exists but there's no documentation explaining what features it omits, when to use it vs the full app, or how the `SIDELOAD_LITE` conditional compilation affects behavior.
- **Recommendation:** Add README section explaining lite variant differences.

#### 11. No CI/CD configuration
- **Severity:** P3
- **Description:** No GitHub Actions, Fastlane, or Xcode Cloud configuration exists. Builds and tests are presumably run manually. This means there's no automated safety net for regressions.
- **Recommendation:** Add a basic GitHub Actions workflow for `xcodebuild test`.

#### 12. Editor views lack documentation
- **Files:** `ios/ancla-app/schedule-editor-view.swift`, `ios/ancla-app/mode-editor-view.swift`
- **Severity:** P3
- **Description:** The editor views are SwiftUI forms but have no documentation about expected data flow, validation rules, or how they interact with AppViewModel's draft state.
- **Recommendation:** Add doc comments explaining the draft pattern (edit → validate → commit).

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| Total Swift files | 25 |
| Total lines (Swift) | ~2,461 |
| Test files | 3 |
| Test-to-source ratio | 12% |
| Files > 200 lines | 5 |
| Largest file (lines) | content-view.swift (501) |
| Classes | 4 |
| Structs | 13 |
| Documented APIs | ~0% |
| Contributors (estimated) | 1 |

## Top 5 Recommendations

1. **Write ARCHITECTURE.md** — document module boundaries, data flow from AppViewModel → Store → Core, and the scheduling model. This is the single highest-ROI documentation investment.
2. **Split AppViewModel** — decompose into 3-4 focused view models to reduce the god-object risk.
3. **Add tests for services** — `AuthorizationClient`, `ShieldingService`, `StickerPairingService` are the interface to Apple system APIs and have zero test coverage.
4. **Add doc comments to AnclaCore** — every function in the core module should have a doc comment explaining purpose and edge cases.
5. **Add CI workflow** — even a basic `xcodebuild test` on PR would catch regressions automatically.
