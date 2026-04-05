# Nightshift Dead Code Analysis

**Repo:** Microck/ancla
**Date:** 2026-04-05
**Task:** dead-code

## Summary

Ancla is a SwiftUI iOS app for screen time management. Dead code analysis was performed using static inspection (no Xcode/Periphery available on Linux). The codebase is notably clean with no obvious dead code detected.

## Analysis Method

- Manual inspection of all 26 Swift source files
- Cross-reference of Package.swift exclusions against project.yml (XcodeGen) targets
- Grep for unused imports, commented-out code, TODO/FIXME markers
- Check for unreferenced types/functions

## Findings

### No Dead Code Found

**Result:** No actionable dead code detected.

Details:
1. **Commented-out code:** Zero instances across all Swift files
2. **TODO/FIXME markers:** None found
3. **Package.swift exclusions verified non-dead:** Three files excluded from the SPM `AnclaCore` library target (`ancla-activity-selection.swift`, `ancla-services.swift`, `ancla-store.swift`) are compiled by all Xcode targets via `project.yml` — they are NOT dead code
4. **Unreferenced types:** None found — all defined types are used within their respective targets
5. **Unused imports:** SwiftUI imports are used across all view files; Foundation used in model/service files

### Codebase Stats

| Metric | Value |
|--------|-------|
| Swift files | 26 |
| SPM target sources | 4 (AnclaCore) |
| Xcode targets | 6 (Ancla, AnclaLite, AnclaSideload, AnclaShieldExtension, AnclaTests, AnclaCore) |
| Commented-out code blocks | 0 |
| TODO/FIXME markers | 0 |

### Note on Package.swift Exclusion Pattern

The `Package.swift` explicitly excludes 3 files from the `AnclaCore` library:

```swift
exclude: [
    "ancla-activity-selection.swift",
    "ancla-services.swift",
    "ancla-store.swift"
]
```

These files contain iOS-specific types (`FamilyActivitySelection`, `AppGroupStore`, `StickerPairingError`) that depend on `FamilyControls`/`DeviceActivity` frameworks not available in SPM CLI builds. They are correctly included in the Xcode app targets via `project.yml`. This is an intentional design pattern, not dead code.

## Recommendation

The codebase is well-maintained. No dead code removal is needed at this time. Consider running [Periphery](https://github.com/peripheryapp/periphery) periodically in CI for automated dead code detection on macOS runners.
