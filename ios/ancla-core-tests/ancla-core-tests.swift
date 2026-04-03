import XCTest
@testable import AnclaCore

final class AnclaCoreTests: XCTestCase {
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
