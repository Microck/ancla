import XCTest
@testable import AnclaCore

final class AnclaCoreTests: XCTestCase {
  func testBlockModeDefaultsToNonStrictAndCanOptIn() {
    let defaultMode = BlockMode(name: "Work", selectionData: Data(), isDefault: true)
    let strictMode = BlockMode(name: "Locked down", selectionData: Data(), isDefault: false, isStrict: true)

    XCTAssertFalse(defaultMode.isStrict)
    XCTAssertTrue(strictMode.isStrict)
  }

  func testBlockModeDecodeDefaultsStrictFlagWhenMissing() throws {
    let encoded = """
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Work",
      "selectionData": "",
      "isDefault": true
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(BlockMode.self, from: encoded)

    XCTAssertFalse(decoded.isStrict)
    XCTAssertEqual(decoded.name, "Work")
  }

  func testSortedModesPlacesDefaultFirstThenAlphabetical() {
    let laterDefault = BlockMode(name: "Work", selectionData: Data(), isDefault: true)
    let alpha = BlockMode(name: "Calls", selectionData: Data(), isDefault: false)
    let beta = BlockMode(name: "Social", selectionData: Data(), isDefault: false)

    let sorted = AnclaCore.sortedModes([beta, laterDefault, alpha])

    XCTAssertEqual(sorted.map(\.name), ["Work", "Calls", "Social"])
    XCTAssertEqual(sorted.first?.id, laterDefault.id)
  }

  func testPreferredModeReturnsDefaultBeforeFirstMode() {
    let first = BlockMode(name: "Calls", selectionData: Data(), isDefault: false)
    let second = BlockMode(name: "Work", selectionData: Data(), isDefault: true)
    let snapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: nil,
      modes: [first, second],
      activeSession: nil
    )

    XCTAssertEqual(AnclaCore.preferredMode(in: snapshot)?.id, second.id)
  }

  func testPreferredModeFallsBackToFirstMode() {
    let first = BlockMode(name: "Calls", selectionData: Data(), isDefault: false)
    let second = BlockMode(name: "Work", selectionData: Data(), isDefault: false)
    let snapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: nil,
      modes: [first, second],
      activeSession: nil
    )

    XCTAssertEqual(AnclaCore.preferredMode(in: snapshot)?.id, first.id)
  }

  func testRepairedSnapshotAssignsDefaultToFirstModeWhenMissing() {
    let first = BlockMode(name: "Calls", selectionData: Data(), isDefault: false)
    let second = BlockMode(name: "Work", selectionData: Data(), isDefault: false)
    let snapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: nil,
      modes: [first, second],
      activeSession: nil
    )

    let repaired = AnclaCore.repairedSnapshot(snapshot)

    XCTAssertTrue(repaired.modes[0].isDefault)
    XCTAssertFalse(repaired.modes[1].isDefault)
    XCTAssertEqual(repaired.modes[0].id, first.id)
  }

  func testRepairedSnapshotLeavesExistingDefaultUntouched() {
    let first = BlockMode(name: "Calls", selectionData: Data(), isDefault: false)
    let second = BlockMode(name: "Work", selectionData: Data(), isDefault: true)
    let snapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: nil,
      modes: [first, second],
      activeSession: nil
    )

    let repaired = AnclaCore.repairedSnapshot(snapshot)

    XCTAssertFalse(repaired.modes[0].isDefault)
    XCTAssertTrue(repaired.modes[1].isDefault)
    XCTAssertEqual(repaired.modes[1].id, second.id)
  }

  func testBlockingAndReleaseEligibilityTrackSessionState() {
    let pairedTag = PairedTag(uidHash: "paired-hash", displayName: "Desk sticker")
    let mode = BlockMode(name: "Work", selectionData: Data(), isDefault: true)

    let armedSnapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: pairedTag,
      modes: [mode],
      activeSession: AnchorSession(
        pairedTagId: pairedTag.id,
        modeId: mode.id,
        state: .armed
      )
    )
    XCTAssertTrue(AnclaCore.activeSessionIsBlocking(armedSnapshot))
    XCTAssertTrue(AnclaCore.canReleaseActiveSession(armedSnapshot))
    XCTAssertTrue(AnclaCore.canUseEmergencyUnbrick(armedSnapshot))

    let mismatchedSnapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: pairedTag,
      modes: [mode],
      activeSession: AnchorSession(
        pairedTagId: pairedTag.id,
        modeId: mode.id,
        state: .mismatchedTag
      )
    )
    XCTAssertTrue(AnclaCore.activeSessionIsBlocking(mismatchedSnapshot))
    XCTAssertTrue(AnclaCore.canReleaseActiveSession(mismatchedSnapshot))
    XCTAssertTrue(AnclaCore.canUseEmergencyUnbrick(mismatchedSnapshot))

    let releasedSnapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: pairedTag,
      modes: [mode],
      activeSession: AnchorSession(
        pairedTagId: pairedTag.id,
        modeId: mode.id,
        state: .released
      )
    )
    XCTAssertFalse(AnclaCore.activeSessionIsBlocking(releasedSnapshot))
    XCTAssertFalse(AnclaCore.canReleaseActiveSession(releasedSnapshot))
    XCTAssertFalse(AnclaCore.canUseEmergencyUnbrick(releasedSnapshot))

    let exhaustedSnapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: pairedTag,
      modes: [mode],
      activeSession: AnchorSession(
        pairedTagId: pairedTag.id,
        modeId: mode.id,
        state: .armed
      ),
      emergencyUnbricksRemaining: 0
    )
    XCTAssertFalse(AnclaCore.canUseEmergencyUnbrick(exhaustedSnapshot))
  }

  func testCanArmSelectedModeRequiresAuthorizationPairingModeAndNoBlockingSession() {
    let pairedTag = PairedTag(uidHash: "paired-hash", displayName: "Desk sticker")
    let mode = BlockMode(name: "Work", selectionData: Data(), isDefault: true)

    XCTAssertFalse(AnclaCore.canArmSelectedMode(AppSnapshot()))

    let readySnapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: pairedTag,
      modes: [mode],
      activeSession: nil
    )
    XCTAssertTrue(AnclaCore.canArmSelectedMode(readySnapshot))

    let blockingSnapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: pairedTag,
      modes: [mode],
      activeSession: AnchorSession(
        pairedTagId: pairedTag.id,
        modeId: mode.id,
        state: .armed
      )
    )
    XCTAssertFalse(AnclaCore.canArmSelectedMode(blockingSnapshot))
  }

  func testShortcutRedirectIsActiveOnlyWhileBlockingSurfaceShouldBeVisible() {
    let pairedTag = PairedTag(uidHash: "paired-hash", displayName: "Desk sticker")
    let mode = BlockMode(name: "Work", selectionData: Data(), isDefault: true)
    let now = Date(timeIntervalSince1970: 1_710_000_000)

    let blockedSnapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: pairedTag,
      modes: [mode],
      activeSession: AnchorSession(
        pairedTagId: pairedTag.id,
        modeId: mode.id,
        state: .armed,
        armedAt: now.addingTimeInterval(-300)
      )
    )
    XCTAssertTrue(AnclaCore.shortcutRedirectIsActive(blockedSnapshot, at: now))

    let temporarilyUnlockedSnapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: pairedTag,
      modes: [mode],
      activeSession: AnchorSession(
        pairedTagId: pairedTag.id,
        modeId: mode.id,
        state: .armed,
        armedAt: now.addingTimeInterval(-300)
      ),
      temporaryUnlock: TemporaryUnlockState(
        reason: "Check 2FA",
        startedAt: now.addingTimeInterval(-1),
        expiresAt: now.addingTimeInterval(9)
      )
    )
    XCTAssertFalse(AnclaCore.shortcutRedirectIsActive(temporarilyUnlockedSnapshot, at: now))

    let releasedSnapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: pairedTag,
      modes: [mode],
      activeSession: AnchorSession(
        pairedTagId: pairedTag.id,
        modeId: mode.id,
        state: .released,
        armedAt: now.addingTimeInterval(-300),
        releasedAt: now
      )
    )
    XCTAssertFalse(AnclaCore.shortcutRedirectIsActive(releasedSnapshot, at: now))
  }

  func testRecordHistoryAppendsEntryAndRecentHistorySortsLatestFirst() {
    let pairedTag = PairedTag(uidHash: "paired-hash", displayName: "Desk sticker")
    let mode = BlockMode(name: "Work", selectionData: Data(), isDefault: true)
    let firstRelease = Date(timeIntervalSince1970: 1_710_000_000)
    let secondRelease = firstRelease.addingTimeInterval(600)

    let firstSession = AnchorSession(
      pairedTagId: pairedTag.id,
      modeId: mode.id,
      state: .released,
      armedAt: firstRelease.addingTimeInterval(-1_800),
      releasedAt: firstRelease
    )
    let secondSession = AnchorSession(
      pairedTagId: pairedTag.id,
      modeId: mode.id,
      state: .released,
      armedAt: secondRelease.addingTimeInterval(-900),
      releasedAt: secondRelease
    )

    var snapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: pairedTag,
      modes: [mode],
      activeSession: secondSession
    )

    snapshot = AnclaCore.recordHistory(
      in: snapshot,
      session: firstSession,
      mode: mode,
      pairedTag: pairedTag,
      releaseMethod: .anchor,
      releasedAt: firstRelease
    )
    snapshot = AnclaCore.recordHistory(
      in: snapshot,
      session: secondSession,
      mode: mode,
      pairedTag: pairedTag,
      releaseMethod: .anchor,
      releasedAt: secondRelease
    )

    let recent = AnclaCore.recentHistory(in: snapshot)

    XCTAssertEqual(recent.count, 2)
    XCTAssertEqual(recent.map(\.releasedAt), [secondRelease, firstRelease])
    XCTAssertEqual(recent[0].modeName, "Work")
    XCTAssertEqual(recent[0].pairedTagName, "Desk sticker")
    XCTAssertEqual(recent[0].releaseMethod, .anchor)
  }

  func testScheduledPlanIsActiveRequiresEnabledMatchingWeekdayAndWindow() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let mondayMorning = Date(timeIntervalSince1970: 1_710_150_000)
    let mondayWeekday = AnclaCore.weekdayNumber(for: mondayMorning, calendar: calendar)

    let activePlan = ScheduledSessionPlan(
      modeId: UUID(),
      pairedTagId: UUID(),
      weekdayNumbers: [mondayWeekday],
      startMinuteOfDay: 8 * 60,
      endMinuteOfDay: 10 * 60,
      isEnabled: true
    )
    XCTAssertTrue(AnclaCore.scheduledPlanIsActive(activePlan, at: mondayMorning, calendar: calendar))

    let disabledPlan = ScheduledSessionPlan(
      modeId: UUID(),
      pairedTagId: UUID(),
      weekdayNumbers: [mondayWeekday],
      startMinuteOfDay: 8 * 60,
      endMinuteOfDay: 10 * 60,
      isEnabled: false
    )
    XCTAssertFalse(AnclaCore.scheduledPlanIsActive(disabledPlan, at: mondayMorning, calendar: calendar))

    let wrongWeekdayPlan = ScheduledSessionPlan(
      modeId: UUID(),
      pairedTagId: UUID(),
      weekdayNumbers: [((mondayWeekday % 7) + 1)],
      startMinuteOfDay: 8 * 60,
      endMinuteOfDay: 10 * 60,
      isEnabled: true
    )
    XCTAssertFalse(AnclaCore.scheduledPlanIsActive(wrongWeekdayPlan, at: mondayMorning, calendar: calendar))

    let expiredPlan = ScheduledSessionPlan(
      modeId: UUID(),
      pairedTagId: UUID(),
      weekdayNumbers: [mondayWeekday],
      startMinuteOfDay: 6 * 60,
      endMinuteOfDay: 8 * 60,
      isEnabled: true
    )
    XCTAssertFalse(AnclaCore.scheduledPlanIsActive(expiredPlan, at: mondayMorning, calendar: calendar))
  }

  func testSortedScheduledPlansPlacesActiveThenEnabledThenDisabled() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = Date(timeIntervalSince1970: 1_710_150_000)
    let weekday = AnclaCore.weekdayNumber(for: now, calendar: calendar)

    let activePlan = ScheduledSessionPlan(
      modeId: UUID(),
      pairedTagId: UUID(),
      weekdayNumbers: [weekday],
      startMinuteOfDay: 8 * 60,
      endMinuteOfDay: 10 * 60,
      isEnabled: true
    )
    let laterEnabledPlan = ScheduledSessionPlan(
      modeId: UUID(),
      pairedTagId: UUID(),
      weekdayNumbers: [weekday],
      startMinuteOfDay: 12 * 60,
      endMinuteOfDay: 14 * 60,
      isEnabled: true
    )
    let disabledPlan = ScheduledSessionPlan(
      modeId: UUID(),
      pairedTagId: UUID(),
      weekdayNumbers: [weekday],
      startMinuteOfDay: 7 * 60,
      endMinuteOfDay: 9 * 60,
      isEnabled: false
    )

    let sorted = AnclaCore.sortedScheduledPlans(
      [disabledPlan, laterEnabledPlan, activePlan],
      at: now,
      calendar: calendar
    )

    XCTAssertEqual(sorted.map(\.id), [activePlan.id, laterEnabledPlan.id, disabledPlan.id])
  }

  func testSnapshotAndSessionDecodeScheduleDefaultsAndLegacyAnchorFallback() throws {
    let pairedTagID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    let modeID = UUID(uuidString: "00000000-0000-0000-0000-000000000022")!

    let encodedSnapshot = """
    {
      "isAuthorized": true,
      "pairedTag": {
        "id": "\(pairedTagID.uuidString)",
        "uidHash": "legacy-hash",
        "displayName": "Desk anchor",
        "createdAt": "2026-04-03T10:00:00Z"
      },
      "modes": [
        {
          "id": "\(modeID.uuidString)",
          "name": "Work",
          "selectionData": "",
          "isDefault": true
        }
      ],
      "activeSession": {
        "id": "00000000-0000-0000-0000-000000000033",
        "pairedTagId": "\(pairedTagID.uuidString)",
        "modeId": "\(modeID.uuidString)",
        "state": "armed",
        "armedAt": "2026-04-03T10:10:00Z"
      }
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let snapshot = try decoder.decode(AppSnapshot.self, from: encodedSnapshot)

    XCTAssertEqual(snapshot.pairedTags.count, 1)
    XCTAssertEqual(snapshot.pairedTags.first?.displayName, "Desk anchor")
    XCTAssertTrue(snapshot.scheduledPlans.isEmpty)
    XCTAssertNil(snapshot.activeSession?.scheduledPlanID)
  }

  func testRuntimeDiagnosticsFlagMissingStorageBeforeAnythingElse() {
    let diagnostics = AnclaCore.runtimeDiagnostics(
      snapshot: AppSnapshot(),
      environment: RuntimeEnvironmentSnapshot(
        buildLabel: "Full blocker experiment",
        buildDetail: "Uses Family Controls.",
        storageLabel: "App Group missing",
        storageDetail: "Signing is not honoring the app-group entitlement.",
        storageTone: .blocked,
        nfcAvailable: true,
        screenTimeAuthorization: .approved
      )
    )

    XCTAssertEqual(diagnostics.headline, "Storage unavailable")
    XCTAssertEqual(diagnostics.message, "Signing is not honoring the app-group entitlement.")
    XCTAssertEqual(diagnostics.items.first { $0.id == "storage" }?.tone, .blocked)
  }

  func testRuntimeDiagnosticsSurfaceBlockingWhenAuthorizationIsMissing() {
    let diagnostics = AnclaCore.runtimeDiagnostics(
      snapshot: AppSnapshot(),
      environment: RuntimeEnvironmentSnapshot(
        buildLabel: "Full blocker experiment",
        buildDetail: "Uses Family Controls.",
        storageLabel: "App Group live",
        storageDetail: "The shared App Group container is available.",
        storageTone: .ready,
        nfcAvailable: true,
        screenTimeAuthorization: .notDetermined
      )
    )

    XCTAssertEqual(diagnostics.headline, "Controls unavailable")
    XCTAssertEqual(diagnostics.items.first { $0.id == "screen-time" }?.value, "Not granted")
  }

  func testRuntimeDiagnosticsBecomeReadyAfterPairingAndModeCreation() {
    let pairedTag = PairedTag(uidHash: "paired-hash", displayName: "Desk sticker")
    let mode = BlockMode(name: "Work", selectionData: Data(), isDefault: true)
    let snapshot = AppSnapshot(
      isAuthorized: true,
      pairedTag: pairedTag,
      modes: [mode],
      activeSession: nil
    )

    let diagnostics = AnclaCore.runtimeDiagnostics(
      snapshot: snapshot,
      environment: RuntimeEnvironmentSnapshot(
        buildLabel: "Full blocker experiment",
        buildDetail: "Uses Family Controls.",
        storageLabel: "App Group live",
        storageDetail: "The shared App Group container is available.",
        storageTone: .ready,
        nfcAvailable: true,
        screenTimeAuthorization: .approved
      )
    )

    XCTAssertEqual(diagnostics.headline, "Ready to start")
    XCTAssertEqual(diagnostics.items.first { $0.id == "sticker" }?.value, "Desk sticker")
    XCTAssertEqual(diagnostics.items.first { $0.id == "mode" }?.value, "Work")
  }
}
