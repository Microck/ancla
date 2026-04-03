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

  func testSaveModePersistsStrictFlagForSideloadMode() async throws {
    let viewModel = AppViewModel(
      buildVariant: .sideloadLite,
      store: InMemorySnapshotStore(),
      stickerPairingService: FakeStickerPairingService()
    )

    viewModel.draftModeName = "Locked down"
    viewModel.draftModeIsStrict = true
    await viewModel.saveMode()

    let savedMode = try XCTUnwrap(viewModel.snapshot.modes.first)
    XCTAssertTrue(savedMode.isStrict)
    XCTAssertTrue(viewModel.currentModeIsStrict)
    XCTAssertFalse(viewModel.draftModeIsStrict)
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
    let stickerService = FakeStickerPairingService(nextHashes: ["wrong-hash", "hash"])
    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: shielding,
      stickerPairingService: stickerService
    )

    await viewModel.armSelectedMode()
    XCTAssertEqual(viewModel.lastError, ValidationError.missingAuthorization.errorDescription)

    viewModel.snapshot.isAuthorized = true
    await viewModel.armSelectedMode()
    XCTAssertEqual(viewModel.lastError, ValidationError.missingPairedTag.errorDescription)

    viewModel.snapshot.pairedTag = PairedTag(uidHash: "hash", displayName: "Desk sticker")
    await viewModel.armSelectedMode()
    XCTAssertEqual(viewModel.lastError, ValidationError.mismatchedTagOnArm.errorDescription)
    XCTAssertTrue(shielding.appliedModeIDs.isEmpty)

    await viewModel.armSelectedMode()
    XCTAssertNil(viewModel.lastError)
    XCTAssertEqual(shielding.appliedModeIDs, [mode.id])
    XCTAssertEqual(viewModel.snapshot.activeSession?.state, .armed)
    XCTAssertEqual(viewModel.snapshot.activeSession?.modeId, mode.id)
  }

  func testPairStickerAppendsAnchorsAndRejectsDuplicates() async {
    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: true,
        pairedTag: nil,
        modes: [],
        activeSession: nil
      )
    )
    let stickerService = FakeStickerPairingService(
      nextHashes: ["tag-hash-001", "tag-hash-002", "tag-hash-002"]
    )
    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: FakeShieldingService(),
      stickerPairingService: stickerService
    )

    viewModel.draftTagName = " Desk "
    await viewModel.pairSticker()
    XCTAssertEqual(viewModel.snapshot.pairedTags.map(\.displayName), ["Desk"])
    XCTAssertEqual(viewModel.snapshot.pairedTags.map(\.uidHash), ["tag-hash-001"])

    viewModel.draftTagName = "Bag anchor"
    await viewModel.pairSticker()
    XCTAssertEqual(viewModel.snapshot.pairedTags.map(\.displayName), ["Desk", "Bag anchor"])
    XCTAssertEqual(viewModel.snapshot.pairedTags.map(\.uidHash), ["tag-hash-001", "tag-hash-002"])

    viewModel.draftTagName = "Duplicate"
    await viewModel.pairSticker()
    XCTAssertEqual(viewModel.lastError, ValidationError.duplicatePairedTag.errorDescription)
    XCTAssertEqual(viewModel.snapshot.pairedTags.map(\.displayName), ["Desk", "Bag anchor"])
  }

  func testRenameAndRemoveSpecificPairedAnchor() async {
    let firstTag = PairedTag(uidHash: "tag-hash-001", displayName: "Desk anchor")
    let secondTag = PairedTag(uidHash: "tag-hash-002", displayName: "Bag anchor")
    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: true,
        pairedTags: [firstTag, secondTag],
        modes: [],
        activeSession: nil
      )
    )
    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: FakeShieldingService(),
      stickerPairingService: FakeStickerPairingService()
    )

    await viewModel.renamePairedSticker(secondTag.id, name: "Office anchor")
    XCTAssertEqual(viewModel.snapshot.pairedTags.map(\.displayName), ["Desk anchor", "Office anchor"])

    await viewModel.unpairSticker(firstTag.id)
    XCTAssertEqual(viewModel.snapshot.pairedTags.map(\.displayName), ["Office anchor"])
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

  func testPrepareDraftForEditingModeLoadsAndUpdatesStrictFlag() async throws {
    let strictMode = BlockMode(
      name: "Locked down",
      selectionData: Data(),
      isDefault: true,
      isStrict: true
    )
    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: true,
        pairedTag: nil,
        modes: [strictMode],
        activeSession: nil
      )
    )
    let viewModel = AppViewModel(
      buildVariant: .sideloadLite,
      store: store,
      stickerPairingService: FakeStickerPairingService()
    )

    viewModel.prepareDraftForEditingMode(strictMode.id)
    XCTAssertTrue(viewModel.draftModeIsStrict)
    XCTAssertTrue(viewModel.currentModeIsStrict)

    viewModel.draftModeIsStrict = false
    await viewModel.saveMode()

    let updatedMode = try XCTUnwrap(viewModel.snapshot.modes.first)
    XCTAssertFalse(updatedMode.isStrict)
    XCTAssertFalse(viewModel.currentModeIsStrict)
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

  func testArmSelectedModeBindsSessionToMatchedAnchorInsteadOfFirstAnchor() async throws {
    let selection = FamilyActivitySelection()
    let mode = try BlockMode(name: "Work", selection: selection, isDefault: true)
    let firstTag = PairedTag(uidHash: "paired-hash-1", displayName: "Desk anchor")
    let secondTag = PairedTag(uidHash: "paired-hash-2", displayName: "Bag anchor")
    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: true,
        pairedTags: [firstTag, secondTag],
        modes: [mode],
        activeSession: nil
      )
    )
    let shielding = FakeShieldingService()
    let stickerService = FakeStickerPairingService(nextHashes: ["paired-hash-2"])
    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: shielding,
      stickerPairingService: stickerService
    )

    await viewModel.armSelectedMode()

    XCTAssertNil(viewModel.lastError)
    XCTAssertEqual(shielding.appliedModeIDs, [mode.id])
    XCTAssertEqual(viewModel.snapshot.activeSession?.state, .armed)
    XCTAssertEqual(viewModel.snapshot.activeSession?.pairedTagId, secondTag.id)
    XCTAssertEqual(viewModel.activePairedTag?.displayName, "Bag anchor")
  }

  func testReleaseRequiresAnchorThatStartedSession() async throws {
    let selection = FamilyActivitySelection()
    let mode = try BlockMode(name: "Work", selection: selection, isDefault: true)
    let firstTag = PairedTag(uidHash: "paired-hash-1", displayName: "Desk anchor")
    let secondTag = PairedTag(uidHash: "paired-hash-2", displayName: "Bag anchor")
    let activeSession = AnchorSession(
      pairedTagId: secondTag.id,
      modeId: mode.id,
      state: .armed
    )
    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: true,
        pairedTags: [firstTag, secondTag],
        modes: [mode],
        activeSession: activeSession
      )
    )
    let shielding = FakeShieldingService()
    let stickerService = FakeStickerPairingService(nextHashes: ["paired-hash-1", "paired-hash-2"])
    let viewModel = AppViewModel(
      store: store,
      authorizationClient: FakeAuthorizationClient(),
      shieldingService: shielding,
      stickerPairingService: stickerService
    )

    await viewModel.releaseActiveSession()
    XCTAssertEqual(viewModel.lastError, ValidationError.mismatchedTag.errorDescription)
    XCTAssertEqual(viewModel.snapshot.activeSession?.state, .mismatchedTag)
    XCTAssertEqual(viewModel.snapshot.sessionHistory.count, 0)

    await viewModel.releaseActiveSession()
    XCTAssertNil(viewModel.lastError)
    XCTAssertEqual(viewModel.snapshot.activeSession?.state, .released)
    XCTAssertEqual(viewModel.snapshot.sessionHistory.count, 1)
    XCTAssertEqual(viewModel.snapshot.sessionHistory[0].pairedTagName, "Bag anchor")
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

  func testRemovingActiveSessionAnchorClearsSessionAndShielding() async throws {
    let selection = FamilyActivitySelection()
    let mode = try BlockMode(name: "Work", selection: selection, isDefault: true)
    let firstTag = PairedTag(uidHash: "paired-hash-1", displayName: "Desk anchor")
    let secondTag = PairedTag(uidHash: "paired-hash-2", displayName: "Bag anchor")
    let activeSession = AnchorSession(
      pairedTagId: secondTag.id,
      modeId: mode.id,
      state: .armed
    )
    let store = InMemorySnapshotStore(
      snapshot: AppSnapshot(
        isAuthorized: true,
        pairedTags: [firstTag, secondTag],
        modes: [mode],
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

    await viewModel.unpairSticker(secondTag.id)

    XCTAssertNil(viewModel.lastError)
    XCTAssertEqual(viewModel.snapshot.pairedTags.map(\.displayName), ["Desk anchor"])
    XCTAssertNil(viewModel.snapshot.activeSession)
    XCTAssertEqual(shielding.clearCallCount, 1)
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
    let stickerService = FakeStickerPairingService(nextHashes: ["lite-hash", "lite-hash", "lite-hash"])
    let viewModel = AppViewModel(
      buildVariant: .sideloadLite,
      store: store,
      stickerPairingService: stickerService
    )

    XCTAssertTrue(viewModel.snapshot.isAuthorized)

    viewModel.draftTagName = "Desk anchor"
    await viewModel.pairSticker()
    XCTAssertEqual(viewModel.snapshot.pairedTags.first?.displayName, "Desk anchor")
    XCTAssertNotNil(viewModel.snapshot.pairedTags.first?.uidHash)

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

  func testSaveScheduledPlanPersistsModeAnchorDaysAndWindow() async throws {
    let mode = BlockMode(name: "Locked down", selectionData: Data(), isDefault: true, isStrict: true)
    let pairedTag = PairedTag(uidHash: "desk-hash", displayName: "Desk anchor")
    let viewModel = AppViewModel(
      buildVariant: .sideloadLite,
      store: InMemorySnapshotStore(
        snapshot: AppSnapshot(
          isAuthorized: true,
          pairedTags: [pairedTag],
          modes: [mode]
        )
      ),
      shieldingService: FakeShieldingService(),
      stickerPairingService: FakeStickerPairingService()
    )

    viewModel.draftScheduleModeID = mode.id
    viewModel.draftSchedulePairedTagID = pairedTag.id
    viewModel.draftScheduleWeekdayNumbers = [2, 4, 6]
    viewModel.draftScheduleStartMinuteOfDay = 8 * 60 + 30
    viewModel.draftScheduleEndMinuteOfDay = 11 * 60
    await viewModel.saveScheduledPlan()

    let savedPlan = try XCTUnwrap(viewModel.snapshot.scheduledPlans.first)
    XCTAssertNil(viewModel.lastError)
    XCTAssertEqual(savedPlan.modeId, mode.id)
    XCTAssertEqual(savedPlan.pairedTagId, pairedTag.id)
    XCTAssertEqual(savedPlan.weekdayNumbers, [2, 4, 6])
    XCTAssertEqual(savedPlan.startMinuteOfDay, 8 * 60 + 30)
    XCTAssertEqual(savedPlan.endMinuteOfDay, 11 * 60)
    XCTAssertTrue(savedPlan.isEnabled)
  }

  func testUseCurrentDraftScheduleWindowMatchesProvidedClock() {
    let now = Date(timeIntervalSince1970: 1_710_150_000)
    let viewModel = AppViewModel(
      buildVariant: .sideloadLite,
      store: InMemorySnapshotStore(),
      stickerPairingService: FakeStickerPairingService(),
      nowProvider: { now }
    )

    viewModel.useCurrentDraftScheduleWindow()

    let minute = AnclaCore.minuteOfDay(for: now)
    XCTAssertEqual(viewModel.draftScheduleWeekdayNumbers, [AnclaCore.weekdayNumber(for: now)])
    XCTAssertEqual(viewModel.draftScheduleStartMinuteOfDay, max(0, minute - 15))
    XCTAssertEqual(viewModel.draftScheduleEndMinuteOfDay, min(23 * 60 + 59, minute + 60))
    XCTAssertTrue(viewModel.draftScheduleIsEnabled)
  }

  func testSyncScheduledSessionsStartsMatchingPlanAutomatically() throws {
    let now = Date(timeIntervalSince1970: 1_710_150_000)
    let mode = BlockMode(name: "Focus", selectionData: Data(), isDefault: true)
    let pairedTag = PairedTag(uidHash: "desk-hash", displayName: "Desk anchor")
    let weekday = AnclaCore.weekdayNumber(for: now)
    let plan = ScheduledSessionPlan(
      modeId: mode.id,
      pairedTagId: pairedTag.id,
      weekdayNumbers: [weekday],
      startMinuteOfDay: AnclaCore.minuteOfDay(for: now) - 5,
      endMinuteOfDay: AnclaCore.minuteOfDay(for: now) + 30
    )
    let shielding = FakeShieldingService()
    let viewModel = AppViewModel(
      buildVariant: .sideloadLite,
      store: InMemorySnapshotStore(
        snapshot: AppSnapshot(
          isAuthorized: true,
          pairedTags: [pairedTag],
          modes: [mode]
        )
      ),
      shieldingService: shielding,
      stickerPairingService: FakeStickerPairingService(),
      nowProvider: { now }
    )

    viewModel.snapshot.scheduledPlans = [plan]
    let changed = viewModel.syncScheduledSessions()

    XCTAssertTrue(changed)
    XCTAssertEqual(viewModel.snapshot.activeSession?.state, .armed)
    XCTAssertEqual(viewModel.snapshot.activeSession?.scheduledPlanID, plan.id)
    XCTAssertEqual(viewModel.snapshot.activeSession?.pairedTagId, pairedTag.id)
    XCTAssertEqual(viewModel.snapshot.activeSession?.modeId, mode.id)
    XCTAssertEqual(viewModel.snapshot.scheduledPlans.first?.lastStartedDayKey, AnclaCore.dayKey(for: now))
    XCTAssertEqual(shielding.appliedModeIDs, [mode.id])
  }

  func testSyncScheduledSessionsEndsExpiredScheduledSessionWithScheduleHistory() throws {
    var currentTime = Date(timeIntervalSince1970: 1_710_150_000)
    let mode = BlockMode(name: "Focus", selectionData: Data(), isDefault: true)
    let pairedTag = PairedTag(uidHash: "desk-hash", displayName: "Desk anchor")
    let dayKey = AnclaCore.dayKey(for: currentTime)
    let plan = ScheduledSessionPlan(
      modeId: mode.id,
      pairedTagId: pairedTag.id,
      weekdayNumbers: [AnclaCore.weekdayNumber(for: currentTime)],
      startMinuteOfDay: AnclaCore.minuteOfDay(for: currentTime) - 120,
      endMinuteOfDay: AnclaCore.minuteOfDay(for: currentTime) - 30,
      isEnabled: true,
      lastStartedDayKey: dayKey
    )
    currentTime = Date(timeIntervalSince1970: 1_710_145_500)
    let activeSession = AnchorSession(
      pairedTagId: pairedTag.id,
      modeId: mode.id,
      state: .armed,
      armedAt: currentTime.addingTimeInterval(-3_600),
      scheduledPlanID: plan.id
    )
    let shielding = FakeShieldingService()
    let viewModel = AppViewModel(
      buildVariant: .sideloadLite,
      store: InMemorySnapshotStore(
        snapshot: AppSnapshot(
          isAuthorized: true,
          pairedTags: [pairedTag],
          modes: [mode],
          activeSession: activeSession,
          scheduledPlans: [plan]
        )
      ),
      shieldingService: shielding,
      stickerPairingService: FakeStickerPairingService(),
      nowProvider: { currentTime }
    )

    currentTime = Date(timeIntervalSince1970: 1_710_150_000)
    let changed = viewModel.syncScheduledSessions()

    XCTAssertTrue(changed)
    XCTAssertEqual(viewModel.snapshot.activeSession?.state, .released)
    XCTAssertEqual(viewModel.snapshot.activeSession?.scheduledPlanID, plan.id)
    XCTAssertEqual(viewModel.snapshot.sessionHistory.count, 1)
    XCTAssertEqual(viewModel.snapshot.sessionHistory.first?.releaseMethod, .schedule)
    XCTAssertEqual(viewModel.snapshot.scheduledPlans.first?.lastEndedDayKey, dayKey)
    XCTAssertEqual(shielding.clearCallCount, 1)
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
