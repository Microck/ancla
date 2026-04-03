import FamilyControls
import XCTest

@MainActor
final class AppViewModelTests: XCTestCase {
  func testSaveModeCanSetNewDefault() async throws {
    let store = InMemorySnapshotStore()
    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: FakeShieldingService(),
      stickerPairingService: FakeStickerPairingService()
    )

    viewModel.draftModeName = "Deep Work"
    await viewModel.saveMode()
    XCTAssertEqual(viewModel.snapshot.modes.count, 1)
    XCTAssertTrue(viewModel.snapshot.modes[0].isDefault)

    viewModel.draftModeName = "Social Lock"
    viewModel.draftModeShouldBeDefault = true
    await viewModel.saveMode()

    XCTAssertEqual(viewModel.snapshot.modes.count, 2)
    XCTAssertFalse(viewModel.snapshot.modes[0].isDefault)
    XCTAssertTrue(viewModel.snapshot.modes[1].isDefault)
  }

  func testDeleteModeClearsArmedSessionAndReassignsDefault() async throws {
    let selection = FamilyActivitySelection()
    let firstMode = try BlockMode(name: "Focus", selection: selection, isDefault: true)
    let secondMode = try BlockMode(name: "Calls", selection: selection, isDefault: false)
    let pairedTag = PairedTag(uidHash: "abc123", displayName: "Desk sticker")
    let session = AnchorSession(
      pairedTagId: pairedTag.id,
      modeId: firstMode.id,
      state: .armed
    )

    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: true,
        pairedTag: pairedTag,
        modes: [firstMode, secondMode],
        activeSession: session
      )
    )
    let shielding = FakeShieldingService()
    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: shielding,
      stickerPairingService: FakeStickerPairingService()
    )

    await viewModel.deleteMode(firstMode.id)

    XCTAssertEqual(viewModel.snapshot.modes.count, 1)
    XCTAssertEqual(viewModel.snapshot.modes[0].id, secondMode.id)
    XCTAssertTrue(viewModel.snapshot.modes[0].isDefault)
    XCTAssertNil(viewModel.snapshot.activeSession)
    XCTAssertEqual(shielding.clearCallCount, 1)
  }

  func testArmSelectedModeNeedsAuthorizationAndPairing() async throws {
    let selection = FamilyActivitySelection()
    let mode = try BlockMode(name: "Work", selection: selection, isDefault: true)
    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: false,
        pairedTag: nil,
        modes: [mode],
        activeSession: nil
      )
    )
    let shielding = FakeShieldingService()
    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: shielding,
      stickerPairingService: FakeStickerPairingService()
    )

    await viewModel.armSelectedMode()
    XCTAssertEqual(viewModel.lastError, ValidationError.missingAuthorization.errorDescription)

    viewModel.snapshot.isAuthorized = true
    await viewModel.armSelectedMode()
    XCTAssertEqual(viewModel.lastError, ValidationError.missingPairedTag.errorDescription)

    viewModel.snapshot.pairedTag = PairedTag(uidHash: "hash", displayName: "Desk sticker")
    await viewModel.armSelectedMode()
    XCTAssertNil(viewModel.lastError)
    XCTAssertEqual(shielding.appliedModeIDs, [mode.id])
    XCTAssertEqual(viewModel.snapshot.activeSession?.state, .armed)
    XCTAssertEqual(viewModel.snapshot.activeSession?.modeId, mode.id)
  }

  func testPairRenameAndUnpairSticker() async {
    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: true,
        pairedTag: nil,
        modes: [],
        activeSession: nil
      )
    )
    let stickerService = FakeStickerPairingService(nextHashes: ["tag-hash-001"])
    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: FakeShieldingService(),
      stickerPairingService: stickerService
    )

    viewModel.draftTagName = " Desk "
    await viewModel.pairSticker()
    XCTAssertEqual(viewModel.snapshot.pairedTag?.displayName, "Desk")
    XCTAssertEqual(viewModel.snapshot.pairedTag?.uidHash, "tag-hash-001")

    await viewModel.renamePairedSticker("Office")
    XCTAssertEqual(viewModel.snapshot.pairedTag?.displayName, "Office")

    await viewModel.unpairSticker()
    XCTAssertNil(viewModel.snapshot.pairedTag)
  }

  func testEditModeCanPromoteDefaultAndRefreshActiveShield() async throws {
    let selection = FamilyActivitySelection()
    let firstMode = try BlockMode(name: "Deep Work", selection: selection, isDefault: true)
    let secondMode = try BlockMode(name: "Social Lock", selection: selection, isDefault: false)
    let pairedTag = PairedTag(uidHash: "paired-hash", displayName: "Desk sticker")
    let activeSession = AnchorSession(
      pairedTagId: pairedTag.id,
      modeId: secondMode.id,
      state: .armed
    )
    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: true,
        pairedTag: pairedTag,
        modes: [firstMode, secondMode],
        activeSession: activeSession
      )
    )
    let shielding = FakeShieldingService()
    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: shielding,
      stickerPairingService: FakeStickerPairingService()
    )

    viewModel.prepareDraftForEditingMode(secondMode.id)
    viewModel.draftModeName = "Social + Video"
    viewModel.draftModeShouldBeDefault = true
    await viewModel.saveMode()

    let updatedSecondMode = try XCTUnwrap(viewModel.snapshot.modes.first { $0.id == secondMode.id })
    XCTAssertEqual(updatedSecondMode.name, "Social + Video")
    XCTAssertTrue(updatedSecondMode.isDefault)

    let updatedFirstMode = try XCTUnwrap(viewModel.snapshot.modes.first { $0.id == firstMode.id })
    XCTAssertFalse(updatedFirstMode.isDefault)

    XCTAssertEqual(shielding.appliedModeIDs, [secondMode.id])
  }

  func testWrongStickerKeepsSessionArmedAndAllowsRetry() async throws {
    let selection = FamilyActivitySelection()
    let mode = try BlockMode(name: "Work", selection: selection, isDefault: true)
    let pairedTag = PairedTag(uidHash: "paired-hash", displayName: "Desk sticker")
    let activeSession = AnchorSession(
      pairedTagId: pairedTag.id,
      modeId: mode.id,
      state: .armed
    )
    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: true,
        pairedTag: pairedTag,
        modes: [mode],
        activeSession: activeSession
      )
    )
    let shielding = FakeShieldingService()
    let stickerService = FakeStickerPairingService(nextHashes: ["wrong-hash", "paired-hash"])
    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: shielding,
      stickerPairingService: stickerService
    )

    await viewModel.releaseActiveSession()
    XCTAssertEqual(viewModel.lastError, ValidationError.mismatchedTag.errorDescription)
    XCTAssertEqual(viewModel.snapshot.activeSession?.state, .mismatchedTag)
    XCTAssertTrue(viewModel.isModeArmed(mode.id))

    await viewModel.releaseActiveSession()
    XCTAssertNil(viewModel.lastError)
    XCTAssertEqual(viewModel.snapshot.activeSession?.state, .released)
    XCTAssertEqual(shielding.clearCallCount, 1)
  }

  func testReleaseAppendsUsageHistoryEntry() async throws {
    let selection = FamilyActivitySelection()
    let mode = try BlockMode(name: "Work", selection: selection, isDefault: true)
    let pairedTag = PairedTag(uidHash: "paired-hash", displayName: "Desk sticker")
    let activeSession = AnchorSession(
      pairedTagId: pairedTag.id,
      modeId: mode.id,
      state: .armed
    )
    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: true,
        pairedTag: pairedTag,
        modes: [mode],
        activeSession: activeSession
      )
    )
    let shielding = FakeShieldingService()
    let stickerService = FakeStickerPairingService(nextHashes: ["paired-hash"])
    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: shielding,
      stickerPairingService: stickerService
    )

    await viewModel.releaseActiveSession()

    XCTAssertEqual(viewModel.snapshot.activeSession?.state, .released)
    XCTAssertEqual(viewModel.snapshot.sessionHistory.count, 1)
    XCTAssertEqual(viewModel.snapshot.sessionHistory[0].modeName, "Work")
    XCTAssertEqual(viewModel.snapshot.sessionHistory[0].pairedTagName, "Desk sticker")
    XCTAssertEqual(viewModel.snapshot.sessionHistory[0].releaseMethod, .anchor)
    XCTAssertEqual(viewModel.recentSessionHistory.count, 1)
  }

  func testEmergencyUnbrickReleasesSessionAndConsumesFailsafe() async throws {
    let selection = FamilyActivitySelection()
    let mode = try BlockMode(name: "Work", selection: selection, isDefault: true)
    let pairedTag = PairedTag(uidHash: "paired-hash", displayName: "Desk sticker")
    let activeSession = AnchorSession(
      pairedTagId: pairedTag.id,
      modeId: mode.id,
      state: .armed
    )
    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: true,
        pairedTag: pairedTag,
        modes: [mode],
        activeSession: activeSession,
        sessionHistory: [],
        emergencyUnbricksRemaining: 2
      )
    )
    let shielding = FakeShieldingService()
    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: shielding,
      stickerPairingService: FakeStickerPairingService()
    )

    await viewModel.useEmergencyUnbrick()

    XCTAssertNil(viewModel.lastError)
    XCTAssertEqual(viewModel.snapshot.activeSession?.state, .released)
    XCTAssertEqual(viewModel.snapshot.emergencyUnbricksRemaining, 1)
    XCTAssertEqual(viewModel.snapshot.sessionHistory.count, 1)
    XCTAssertEqual(viewModel.snapshot.sessionHistory[0].releaseMethod, .emergencyUnbrick)
    XCTAssertEqual(shielding.clearCallCount, 1)
  }

  func testEmergencyUnbrickStopsWhenFailsafesAreExhausted() async throws {
    let selection = FamilyActivitySelection()
    let mode = try BlockMode(name: "Work", selection: selection, isDefault: true)
    let pairedTag = PairedTag(uidHash: "paired-hash", displayName: "Desk sticker")
    let activeSession = AnchorSession(
      pairedTagId: pairedTag.id,
      modeId: mode.id,
      state: .armed
    )
    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: true,
        pairedTag: pairedTag,
        modes: [mode],
        activeSession: activeSession,
        sessionHistory: [],
        emergencyUnbricksRemaining: 0
      )
    )
    let shielding = FakeShieldingService()
    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: shielding,
      stickerPairingService: FakeStickerPairingService()
    )

    await viewModel.useEmergencyUnbrick()

    XCTAssertEqual(viewModel.lastError, ValidationError.noEmergencyUnbricksRemaining.errorDescription)
    XCTAssertEqual(viewModel.snapshot.activeSession?.state, .armed)
    XCTAssertTrue(viewModel.snapshot.sessionHistory.isEmpty)
    XCTAssertEqual(shielding.clearCallCount, 0)
  }

  func testLoadRepairsMissingDefaultAndSelectsFirstMode() async throws {
    let selection = FamilyActivitySelection()
    let firstMode = try BlockMode(name: "Focus", selection: selection, isDefault: false)
    let secondMode = try BlockMode(name: "Calls", selection: selection, isDefault: false)
    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: true,
        pairedTag: nil,
        modes: [firstMode, secondMode],
        activeSession: nil
      )
    )

    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: FakeShieldingService(),
      stickerPairingService: FakeStickerPairingService()
    )

    XCTAssertEqual(viewModel.snapshot.modes.first?.id, firstMode.id)
    XCTAssertTrue(viewModel.snapshot.modes.first?.isDefault == true)
    XCTAssertEqual(viewModel.selectedModeID, firstMode.id)
  }

  func testSideloadLiteCanPairSaveArmAndReleaseLocally() async {
    let store = InMemorySnapshotStore()
    let stickerService = FakeStickerPairingService(nextHashes: ["lite-hash", "lite-hash"])
    let viewModel = AppViewModel(
      buildVariant: .sideloadLite,
      store: store,
      stickerPairingService: stickerService
    )

    XCTAssertTrue(viewModel.snapshot.isAuthorized)

    viewModel.draftTagName = "Desk anchor"
    await viewModel.pairSticker()
    XCTAssertEqual(viewModel.snapshot.pairedTag?.displayName, "Desk anchor")
    XCTAssertNotNil(viewModel.snapshot.pairedTag?.uidHash)

    viewModel.draftModeName = "Phone break"
    await viewModel.saveMode()
    XCTAssertNil(viewModel.lastError)
    XCTAssertEqual(viewModel.snapshot.modes.count, 1)
    XCTAssertEqual(viewModel.selectionSummary(for: viewModel.snapshot.modes[0]), "On-device mode")

    await viewModel.armSelectedMode()
    XCTAssertEqual(viewModel.snapshot.activeSession?.state, .armed)

    await viewModel.releaseActiveSession()
    XCTAssertEqual(viewModel.snapshot.activeSession?.state, .released)
  }

  func testSaveModeRejectsEmptySelection() async {
    let viewModel = AppViewModel(
      store: InMemorySnapshotStore(),
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: FakeShieldingService(),
      stickerPairingService: FakeStickerPairingService()
    )

    viewModel.draftModeName = "Empty mode"
    await viewModel.saveMode()

    XCTAssertEqual(viewModel.lastError, ValidationError.noTargetsSelected.errorDescription)
    XCTAssertTrue(viewModel.snapshot.modes.isEmpty)
  }
}

private final class InMemorySnapshotStore: AppSnapshotStore {
  private(set) var snapshot: AppSnapshot

  init(snapshot: AppSnapshot = AppSnapshot()) {
    self.snapshot = snapshot
  }

  func load() throws -> AppSnapshot {
    snapshot
  }

  func save(_ snapshot: AppSnapshot) throws {
    self.snapshot = snapshot
  }
}

@MainActor
private final class FakeAuthorizationClient: AuthorizationClienting {
  var shouldThrow = false

  func request() async throws {
    if shouldThrow {
      throw TestHarnessError.authorizationDenied
    }
  }
}

@MainActor
private final class FakeShieldingService: Shielding {
  private(set) var appliedModeIDs: [UUID] = []
  private(set) var clearCallCount = 0

  func apply(mode: BlockMode) throws {
    appliedModeIDs.append(mode.id)
  }

  func clear() {
    clearCallCount += 1
  }
}

@MainActor
private final class FakeStickerPairingService: StickerPairing {
  private var nextHashes: [String]

  init(nextHashes: [String] = ["default-hash"]) {
    self.nextHashes = nextHashes
  }

  func scanSticker() async throws -> String {
    if nextHashes.isEmpty {
      throw TestHarnessError.missingStickerHash
    }
    return nextHashes.removeFirst()
  }
}

private enum TestHarnessError: LocalizedError {
  case authorizationDenied
  case missingStickerHash

  var errorDescription: String? {
    switch self {
    case .authorizationDenied:
      return "Authorization denied in test harness."
    case .missingStickerHash:
      return "No sticker hash queued in test harness."
    }
  }
}
