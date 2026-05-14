#if !SIDELOAD_LITE
import FamilyControls
#endif
import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

enum AppActionID: Equatable {
  case refresh
  case authorize
  case confirmShortcutSetup
  case pairAnchor
  case armSession
  case releaseSession
  case emergencyUnbrick
  case adjustFailsafes
  case paragraphChallenge
  case presetUnlock
  case renameAnchor
  case removeAnchor
  case saveMode
  case saveSchedule
  case removeSchedule
  case savePreset
  case removePreset
}

enum ActionFeedbackTone {
  case neutral
  case success
  case error
}

struct ActionFeedback: Equatable, Identifiable {
  let id: UUID
  let message: String
  let tone: ActionFeedbackTone

  init(id: UUID = UUID(), message: String, tone: ActionFeedbackTone) {
    self.id = id
    self.message = message
    self.tone = tone
  }
}

@MainActor
@Observable
final class AppViewModel {
  let buildVariant: AppBuildVariant

  var snapshot = AppSnapshot()
  var diagnostics = RuntimeDiagnostics.empty
  var draftModeID: UUID?
  var draftSelection = FamilyActivitySelection()
  var draftModeName = "Work block"
  var draftModeShouldBeDefault = false
  var draftScheduleID: UUID?
  var draftScheduleModeID: UUID?
  var draftSchedulePairedTagID: UUID?
  var draftScheduleWeekdayNumbers: [Int] = []
  var draftScheduleStartMinuteOfDay = 9 * 60
  var draftScheduleEndMinuteOfDay = 17 * 60
  var draftScheduleIsEnabled = true
  var draftPresetID: UUID?
  var draftPresetTitle = "Check 2FA"
  var draftPresetDetail = "Open Messages long enough to read a code."
  var draftPresetDurationSeconds = 10
  var draftTagName = "Desk anchor"
  var selectedModeID: UUID?
  var isPickerPresented = false
  var isBusy = false
  var activeAction: AppActionID?
  var lastError: String?
  var feedback: ActionFeedback?
  var activeParagraphChallengeID: UUID?

  private let store: any AppSnapshotStore
  private let authorizationClient: any AuthorizationClienting
  private let shieldingService: any Shielding
  private let stickerPairingService: any StickerPairing
  private let runtimeDiagnosticsProbe: any RuntimeDiagnosticsProbing
  private let scheduleNotificationService: any ScheduleNotifying
  private let nowProvider: () -> Date
  @ObservationIgnored private var temporaryUnlockTask: Task<Void, Never>?
#if canImport(UIKit)
  @ObservationIgnored private var temporaryUnlockBackgroundTask: UIBackgroundTaskIdentifier = .invalid
#endif

  init(
    buildVariant: AppBuildVariant = .current,
    store: (any AppSnapshotStore)? = nil,
    authorizationClient: (any AuthorizationClienting)? = nil,
    shieldingService: (any Shielding)? = nil,
    stickerPairingService: (any StickerPairing)? = nil,
    runtimeDiagnosticsProbe: (any RuntimeDiagnosticsProbing)? = nil,
    scheduleNotificationService: (any ScheduleNotifying)? = nil,
    nowProvider: @escaping () -> Date = { .now }
  ) {
    self.buildVariant = buildVariant
    self.runtimeDiagnosticsProbe = runtimeDiagnosticsProbe ?? LiveRuntimeDiagnosticsProbe()
    self.scheduleNotificationService = scheduleNotificationService ?? LiveScheduleNotificationService.shared
    self.nowProvider = nowProvider

    switch buildVariant {
    case .full:
#if SIDELOAD_LITE
      self.store = store ?? LocalSnapshotStore()
      self.authorizationClient = authorizationClient ?? LiteAuthorizationClient()
      self.shieldingService = shieldingService ?? LiteShieldingService()
      self.stickerPairingService = stickerPairingService ?? LiteStickerPairingService()
#else
      self.store = store ?? AppGroupStore()
      self.authorizationClient = authorizationClient ?? AuthorizationClient()
      self.shieldingService = shieldingService ?? ShieldingService()
      self.stickerPairingService = stickerPairingService ?? StickerPairingService()
#endif
    case .sideloadLite:
      self.store = store ?? LocalSnapshotStore()
      self.authorizationClient = authorizationClient ?? LiteAuthorizationClient()
      self.shieldingService = shieldingService ?? LiteShieldingService()
      self.stickerPairingService = stickerPairingService ?? LiteStickerPairingService()
    }

    load()
  }

  var isSideloadLiteBuild: Bool {
    buildVariant == .sideloadLite
  }

  var modesForDisplay: [BlockMode] {
    AnclaCore.sortedModes(snapshot.modes)
  }

  var canSaveDraftMode: Bool {
    if isSideloadLiteBuild {
      return true
    }

    return selectionHasTargets(draftSelection)
  }

  var hasAnyMode: Bool {
    !snapshot.modes.isEmpty
  }

  var recentSessionHistory: [SessionHistoryEntry] {
    AnclaCore.recentHistory(in: snapshot)
  }

  var pairedTagsForDisplay: [PairedTag] {
    guard let activePairedTag else {
      return snapshot.pairedTags
    }

    return snapshot.pairedTags.sorted { lhs, rhs in
      if lhs.id == activePairedTag.id {
        return true
      }

      if rhs.id == activePairedTag.id {
        return false
      }

      return lhs.createdAt < rhs.createdAt
    }
  }

  var activePairedTag: PairedTag? {
    guard
      let activeSession = snapshot.activeSession,
      activeSession.state == .armed || activeSession.state == .mismatchedTag
    else {
      return nil
    }

    return AnclaCore.pairedTag(for: activeSession.pairedTagId, in: snapshot)
  }

  var isNFCAvailable: Bool {
    diagnostics.items.first(where: { $0.id == "nfc" })?.value == "Ready"
  }

  var activeSessionIsBlocking: Bool {
    AnclaCore.activeSessionIsBlocking(snapshot)
  }

  var canReleaseActiveSession: Bool {
    AnclaCore.canReleaseActiveSession(snapshot)
  }

  var hasCompletedShortcutSetup: Bool {
    snapshot.hasConfirmedShortcutSetup
  }

  var hasCompletedAnchorSetup: Bool {
    !snapshot.pairedTags.isEmpty
  }

  var hasCompletedModeSetup: Bool {
    !snapshot.modes.isEmpty
  }

  var hasCompletedRequiredSetup: Bool {
    !isSideloadLiteBuild
      || (hasCompletedShortcutSetup && hasCompletedAnchorSetup && hasCompletedModeSetup)
  }

  var canUseEmergencyUnbrick: Bool {
    AnclaCore.canUseEmergencyUnbrick(snapshot)
  }

  var canArmSelectedMode: Bool {
    AnclaCore.canArmSelectedMode(snapshot)
  }

  var scheduledPlansForDisplay: [ScheduledSessionPlan] {
    AnclaCore.sortedScheduledPlans(snapshot.scheduledPlans, at: nowProvider())
  }

  var unlockPresetsForDisplay: [UnlockPreset] {
    AnclaCore.sortedUnlockPresets(snapshot.unlockPresets)
  }

  var paragraphChallengesForDisplay: [ParagraphChallengePassage] {
    snapshot.paragraphChallenges
  }

  var paragraphChallengeEnabled: Bool {
    snapshot.paragraphChallengeEnabled
  }

  var canUseParagraphChallenge: Bool {
    AnclaCore.canUseParagraphChallenge(snapshot)
  }

  var isTemporaryUnlockActive: Bool {
    AnclaCore.temporaryUnlockIsActive(snapshot, at: nowProvider())
  }

  var shouldShowLockedScreen: Bool {
    AnclaCore.blockedPresentationIsActive(snapshot, at: nowProvider())
  }

  var activeTemporaryUnlock: TemporaryUnlockState? {
    guard isTemporaryUnlockActive else {
      return nil
    }

    return snapshot.temporaryUnlock
  }

  var activeParagraphChallenge: ParagraphChallengePassage? {
    guard let activeParagraphChallengeID else {
      return nil
    }

    return snapshot.paragraphChallenges.first(where: { $0.id == activeParagraphChallengeID })
  }

  var temporaryUnlockRemainingSeconds: Int {
    guard let activeTemporaryUnlock else {
      return 0
    }

    return max(0, Int(ceil(activeTemporaryUnlock.expiresAt.timeIntervalSince(nowProvider()))))
  }

  var canSaveDraftSchedule: Bool {
    draftScheduleModeID != nil
      && draftSchedulePairedTagID != nil
      && !draftScheduleWeekdayNumbers.isEmpty
      && draftScheduleEndMinuteOfDay > draftScheduleStartMinuteOfDay
  }

  func load() {
    do {
      snapshot = AnclaCore.repairedSnapshot(try store.load())
    } catch {
      lastError = error.localizedDescription
      feedback = ActionFeedback(message: error.localizedDescription, tone: .error)
    }

    if isSideloadLiteBuild && !snapshot.isAuthorized {
      snapshot.isAuthorized = true
      try? persist()
    }

    selectedModeID = preferredMode()?.id
    prepareDraftForNewMode()
    prepareDraftForNewSchedule()
    prepareDraftForNewPreset()
    _ = syncScheduledSessions()
    refreshScheduleNotifications()
  }

  func requestAuthorization() async {
    await runTask(action: .authorize, successMessage: "App Controls enabled.") { [self] in
      try await authorizationClient.request()
      snapshot.isAuthorized = true
      try persist()
    }
  }

  func saveMode() async {
    await runTask(action: .saveMode) { [self] in
      guard canSaveDraftMode else {
        throw ValidationError.noTargetsSelected
      }

      let trimmedName = draftModeName.trimmingCharacters(in: .whitespacesAndNewlines)
      let modeName = trimmedName.isEmpty ? "Work block" : trimmedName

      if let draftModeID, let index = snapshot.modes.firstIndex(where: { $0.id == draftModeID }) {
        var mode = snapshot.modes[index]
        mode.name = modeName
        mode.selectionData = isSideloadLiteBuild ? Data() : try JSONEncoder().encode(draftSelection)

        let shouldBeDefault = draftModeShouldBeDefault || snapshot.modes.count == 1
        if shouldBeDefault {
          clearDefaultFlag()
        }
        mode.isDefault = shouldBeDefault
        snapshot.modes[index] = mode
        ensureDefaultMode()

        if snapshot.activeSession?.modeId == mode.id, snapshot.activeSession?.state == .armed {
          try shieldingService.apply(mode: mode)
        }

        selectedModeID = mode.id
      } else {
        let mode: BlockMode
        if isSideloadLiteBuild {
          mode = BlockMode(
            name: modeName,
            selectionData: Data(),
            isDefault: snapshot.modes.isEmpty || draftModeShouldBeDefault
          )
        } else {
          mode = try BlockMode(
            name: modeName,
            selection: draftSelection,
            isDefault: snapshot.modes.isEmpty || draftModeShouldBeDefault
          )
        }

        if mode.isDefault {
          clearDefaultFlag()
        }
        snapshot.modes.append(mode)
        selectedModeID = mode.id
      }

      prepareDraftForNewMode()
      try persist()

      feedback = ActionFeedback(
        message: "\"\(modeName)\" saved.",
        tone: .success
      )
    }
  }

  func saveScheduledPlan() async {
    await runTask(action: .saveSchedule) { [self] in
      guard canSaveDraftSchedule else {
        throw ValidationError.invalidScheduledSession
      }

      let weekdayNumbers = Array(Set(draftScheduleWeekdayNumbers)).sorted()
      let schedule = ScheduledSessionPlan(
        id: draftScheduleID ?? UUID(),
        modeId: try draftScheduleModeID.orThrow(ValidationError.missingMode),
        pairedTagId: try draftSchedulePairedTagID.orThrow(ValidationError.missingPairedTag),
        weekdayNumbers: weekdayNumbers,
        startMinuteOfDay: draftScheduleStartMinuteOfDay,
        endMinuteOfDay: draftScheduleEndMinuteOfDay,
        isEnabled: draftScheduleIsEnabled,
        lastStartedDayKey: existingScheduledPlan()?.lastStartedDayKey,
        lastEndedDayKey: existingScheduledPlan()?.lastEndedDayKey
      )

      if let index = snapshot.scheduledPlans.firstIndex(where: { $0.id == schedule.id }) {
        snapshot.scheduledPlans[index] = schedule
      } else {
        snapshot.scheduledPlans.append(schedule)
      }

      try persist()
      prepareDraftForNewSchedule()
      feedback = ActionFeedback(message: "Scheduled session saved.", tone: .success)
    }
  }

  func prepareDraftForNewMode() {
    lastError = nil
    draftModeID = nil
    draftModeName = "Work block"
    draftSelection = FamilyActivitySelection()
    draftModeShouldBeDefault = snapshot.modes.isEmpty
  }

  func prepareDraftForNewSchedule() {
    lastError = nil
    draftScheduleID = nil
    draftScheduleModeID = selectedMode()?.id ?? preferredMode()?.id ?? snapshot.modes.first?.id
    draftSchedulePairedTagID = snapshot.pairedTags.first?.id
    draftScheduleWeekdayNumbers = [AnclaCore.weekdayNumber(for: nowProvider())]
    draftScheduleStartMinuteOfDay = 9 * 60
    draftScheduleEndMinuteOfDay = 17 * 60
    draftScheduleIsEnabled = true
  }

  func prepareDraftForNewPreset() {
    lastError = nil
    draftPresetID = nil
    draftPresetTitle = "Check 2FA"
    draftPresetDetail = "Open Messages long enough to read a code."
    draftPresetDurationSeconds = 10
  }

  func prepareDraftForEditingMode(_ modeID: UUID) {
    lastError = nil
    guard let mode = snapshot.modes.first(where: { $0.id == modeID }) else {
      lastError = ValidationError.missingMode.localizedDescription
      return
    }

    draftModeID = mode.id
    draftModeName = mode.name
    draftModeShouldBeDefault = mode.isDefault

    if isSideloadLiteBuild && mode.selectionData.isEmpty {
      draftSelection = FamilyActivitySelection()
      return
    }

    do {
      draftSelection = try mode.decodedSelection()
    } catch {
      draftSelection = FamilyActivitySelection()
      lastError = "Could not load this mode's saved target selection."
      feedback = ActionFeedback(
        message: "Could not load this mode's saved target selection.",
        tone: .error
      )
    }
  }

  func prepareDraftForEditingScheduledPlan(_ planID: UUID) {
    lastError = nil
    guard let plan = snapshot.scheduledPlans.first(where: { $0.id == planID }) else {
      lastError = ValidationError.missingScheduledSession.localizedDescription
      return
    }

    draftScheduleID = plan.id
    draftScheduleModeID = plan.modeId
    draftSchedulePairedTagID = plan.pairedTagId
    draftScheduleWeekdayNumbers = plan.weekdayNumbers
    draftScheduleStartMinuteOfDay = plan.startMinuteOfDay
    draftScheduleEndMinuteOfDay = plan.endMinuteOfDay
    draftScheduleIsEnabled = plan.isEnabled
  }

  func prepareDraftForEditingPreset(_ presetID: UUID) {
    lastError = nil
    guard let preset = snapshot.unlockPresets.first(where: { $0.id == presetID }) else {
      lastError = ValidationError.missingUnlockPreset.localizedDescription
      return
    }

    draftPresetID = preset.id
    draftPresetTitle = preset.title
    draftPresetDetail = preset.detail
    draftPresetDurationSeconds = preset.durationSeconds
  }

  func deleteScheduledPlan(_ planID: UUID) async {
    await runTask(action: .removeSchedule) { [self] in
      guard let index = snapshot.scheduledPlans.firstIndex(where: { $0.id == planID }) else {
        throw ValidationError.missingScheduledSession
      }

      let deletedPlan = snapshot.scheduledPlans.remove(at: index)
      if snapshot.activeSession?.scheduledPlanID == deletedPlan.id {
        try releaseDeletedScheduledSession(planID: deletedPlan.id)
      } else {
        try persist()
      }

      prepareDraftForNewSchedule()
      feedback = ActionFeedback(message: "Scheduled session removed.", tone: .success)
    }
  }

  func toggleDraftScheduleWeekday(_ weekdayNumber: Int) {
    if let index = draftScheduleWeekdayNumbers.firstIndex(of: weekdayNumber) {
      draftScheduleWeekdayNumbers.remove(at: index)
    } else {
      draftScheduleWeekdayNumbers.append(weekdayNumber)
      draftScheduleWeekdayNumbers.sort()
    }
  }

  func shiftDraftScheduleStart(by minutes: Int) {
    draftScheduleStartMinuteOfDay = max(0, min(draftScheduleStartMinuteOfDay + minutes, max(0, draftScheduleEndMinuteOfDay - 15)))
  }

  func shiftDraftScheduleEnd(by minutes: Int) {
    draftScheduleEndMinuteOfDay = min(23 * 60 + 59, max(draftScheduleEndMinuteOfDay + minutes, draftScheduleStartMinuteOfDay + 15))
  }

  func useCurrentDraftScheduleWindow() {
    let now = nowProvider()
    let minutes = AnclaCore.minuteOfDay(for: now)
    draftScheduleWeekdayNumbers = [AnclaCore.weekdayNumber(for: now)]
    draftScheduleStartMinuteOfDay = max(0, minutes - 15)
    draftScheduleEndMinuteOfDay = min(23 * 60 + 59, minutes + 60)
    draftScheduleIsEnabled = true
  }

  func saveUnlockPreset() async {
    await runTask(action: .savePreset) { [self] in
      let trimmedTitle = draftPresetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedDetail = draftPresetDetail.trimmingCharacters(in: .whitespacesAndNewlines)

      guard !trimmedTitle.isEmpty else {
        throw ValidationError.invalidUnlockPreset
      }

      guard (5...300).contains(draftPresetDurationSeconds) else {
        throw ValidationError.invalidUnlockPreset
      }

      let preset = UnlockPreset(
        id: draftPresetID ?? UUID(),
        title: trimmedTitle,
        detail: trimmedDetail.isEmpty ? "Temporary access." : trimmedDetail,
        durationSeconds: draftPresetDurationSeconds,
        createdAt: existingUnlockPreset()?.createdAt ?? nowProvider()
      )

      if let index = snapshot.unlockPresets.firstIndex(where: { $0.id == preset.id }) {
        snapshot.unlockPresets[index] = preset
      } else {
        snapshot.unlockPresets.append(preset)
      }

      try persist()
      prepareDraftForNewPreset()
      feedback = ActionFeedback(message: "\"\(preset.title)\" preset saved.", tone: .success)
    }
  }

  func confirmShortcutSetup() async {
    await runTask(action: .confirmShortcutSetup) { [self] in
      snapshot.hasConfirmedShortcutSetup = true
      try persist()
      feedback = ActionFeedback(message: "Shortcut setup marked done.", tone: .success)
    }
  }

  func deleteUnlockPreset(_ presetID: UUID) async {
    await runTask(action: .removePreset) { [self] in
      guard let index = snapshot.unlockPresets.firstIndex(where: { $0.id == presetID }) else {
        throw ValidationError.missingUnlockPreset
      }

      let deletedPreset = snapshot.unlockPresets.remove(at: index)
      if snapshot.temporaryUnlock?.presetID == deletedPreset.id {
        try restoreShieldingAfterTemporaryUnlock()
      }
      try persist()
      prepareDraftForNewPreset()
      feedback = ActionFeedback(message: "\"\(deletedPreset.title)\" preset removed.", tone: .success)
    }
  }

  func setParagraphChallengeEnabled(_ isEnabled: Bool) async {
    await runTask(action: .paragraphChallenge) { [self] in
      snapshot.paragraphChallengeEnabled = isEnabled
      try persist()
      feedback = ActionFeedback(
        message: isEnabled ? "Typing challenge enabled." : "Typing challenge disabled.",
        tone: .success
      )
    }
  }

  func adjustEmergencyUnbricks(by delta: Int) async {
    await runTask(action: .adjustFailsafes) { [self] in
      let nextValue = max(0, min(snapshot.emergencyUnbricksRemaining + delta, 99))
      guard nextValue != snapshot.emergencyUnbricksRemaining else {
        return
      }

      snapshot.emergencyUnbricksRemaining = nextValue
      try persist()
      feedback = ActionFeedback(
        message: nextValue == 1 ? "Failsafes set to 1." : "Failsafes set to \(nextValue).",
        tone: .success
      )
    }
  }

  func prepareParagraphChallenge() {
    lastError = nil
    activeParagraphChallengeID = snapshot.paragraphChallenges.first?.id
  }

  func clearParagraphChallenge() {
    activeParagraphChallengeID = nil
  }

  func submitParagraphChallenge(_ typedPassage: String) async {
    await runTask(action: .paragraphChallenge) { [self] in
      guard
        let activeSession = snapshot.activeSession,
        activeSession.state == .armed || activeSession.state == .mismatchedTag
      else {
        throw ValidationError.sessionNotArmed
      }

      guard let challenge = activeParagraphChallenge, canUseParagraphChallenge else {
        throw ValidationError.paragraphChallengeUnavailable
      }

      guard normalizedChallengeText(typedPassage) == normalizedChallengeText(challenge.passage) else {
        throw ValidationError.paragraphChallengeMismatch
      }

      guard
        let pairedTag = AnclaCore.pairedTag(for: activeSession.pairedTagId, in: snapshot),
        let mode = snapshot.modes.first(where: { $0.id == activeSession.modeId })
      else {
        throw ValidationError.missingMode
      }

      clearParagraphChallenge()
      try completeRelease(
        activeSession: activeSession,
        mode: mode,
        pairedTag: pairedTag,
        releaseMethod: .paragraphChallenge
      )
      feedback = ActionFeedback(message: "Failsafe challenge passed. Session released.", tone: .success)
    }
  }

  func activateUnlockPreset(_ presetID: UUID) async {
    await runTask(action: .presetUnlock) { [self] in
      guard
        let activeSession = snapshot.activeSession,
        activeSession.state == .armed || activeSession.state == .mismatchedTag
      else {
        throw ValidationError.sessionNotArmed
      }

      guard let preset = snapshot.unlockPresets.first(where: { $0.id == presetID }) else {
        throw ValidationError.missingUnlockPreset
      }

      shieldingService.clear()
      let now = nowProvider()
      snapshot.temporaryUnlock = TemporaryUnlockState(
        presetID: preset.id,
        reason: preset.title,
        startedAt: now,
        expiresAt: now.addingTimeInterval(TimeInterval(preset.durationSeconds))
      )
      try persist()
      scheduleTemporaryUnlockExpirationIfNeeded()
      feedback = ActionFeedback(
        message: "\"\(preset.title)\" unlocked the phone for \(preset.durationSeconds) seconds.",
        tone: .success
      )
    }
  }

  func pairSticker() async {
    await runTask(action: .pairAnchor) { [self] in
      let uidHash = try await stickerPairingService.scanSticker()
      guard AnclaCore.matchedPairedTag(for: uidHash, in: snapshot) == nil else {
        throw ValidationError.duplicatePairedTag
      }

      let trimmedName = draftTagName.trimmingCharacters(in: .whitespacesAndNewlines)
      let displayName = trimmedName.isEmpty ? "Desk anchor" : trimmedName
      let pairedTag = PairedTag(
        uidHash: uidHash,
        displayName: displayName
      )
      snapshot.pairedTags.append(pairedTag)
      try persist()
      feedback = ActionFeedback(message: "\(displayName) paired.", tone: .success)
    }
  }

  func armSelectedMode() async {
    await runTask(action: .armSession) { [self] in
      guard let mode = selectedMode() ?? preferredMode() else {
        throw ValidationError.missingMode
      }

      try await arm(mode: mode)
      feedback = ActionFeedback(
        message: "Paired anchor confirmed. \"\(mode.name)\" is active.",
        tone: .success
      )
    }
  }

  func armMode(_ modeID: UUID) async {
    await runTask(action: .armSession) { [self] in
      guard let mode = snapshot.modes.first(where: { $0.id == modeID }) else {
        throw ValidationError.missingMode
      }
      selectedModeID = mode.id
      try await arm(mode: mode)
      feedback = ActionFeedback(
        message: "Paired anchor confirmed. \"\(mode.name)\" is active.",
        tone: .success
      )
    }
  }

  func releaseActiveSession() async {
    await runTask(action: .releaseSession, successMessage: "Session released.") { [self] in
      guard
        let activeSession = snapshot.activeSession,
        activeSession.state == .armed || activeSession.state == .mismatchedTag
      else {
        throw ValidationError.sessionNotArmed
      }

      let scannedHash = try await stickerPairingService.scanSticker()
      guard let pairedTag = AnclaCore.pairedTag(for: activeSession.pairedTagId, in: snapshot) else {
        throw ValidationError.missingPairedTag
      }

      guard scannedHash == pairedTag.uidHash else {
        snapshot.activeSession?.state = .mismatchedTag
        try persist()
        throw ValidationError.mismatchedTag
      }

      guard
        let mode = snapshot.modes.first(where: { $0.id == activeSession.modeId })
      else {
        throw ValidationError.missingMode
      }

      try completeRelease(
        activeSession: activeSession,
        mode: mode,
        pairedTag: pairedTag,
        releaseMethod: .anchor
      )
    }
  }

  func useEmergencyUnbrick() async {
    await runTask(
      action: .emergencyUnbrick,
      successMessage: "Emergency unbrick used. Session released."
    ) { [self] in
      guard
        let activeSession = snapshot.activeSession,
        activeSession.state == .armed || activeSession.state == .mismatchedTag
      else {
        throw ValidationError.sessionNotArmed
      }

      guard snapshot.emergencyUnbricksRemaining > 0 else {
        throw ValidationError.noEmergencyUnbricksRemaining
      }

      guard
        let pairedTag = AnclaCore.pairedTag(for: activeSession.pairedTagId, in: snapshot),
        let mode = snapshot.modes.first(where: { $0.id == activeSession.modeId })
      else {
        throw ValidationError.missingMode
      }

      try completeRelease(
        activeSession: activeSession,
        mode: mode,
        pairedTag: pairedTag,
        releaseMethod: .emergencyUnbrick
      )
      snapshot.emergencyUnbricksRemaining -= 1
      try persist()
    }
  }

  func setDefaultMode(_ modeID: UUID) async {
    await runTask(action: .saveMode) { [self] in
      guard snapshot.modes.contains(where: { $0.id == modeID }) else {
        throw ValidationError.missingMode
      }

      clearDefaultFlag()
      if let index = snapshot.modes.firstIndex(where: { $0.id == modeID }) {
        snapshot.modes[index].isDefault = true
      }
      selectedModeID = modeID
      try persist()
      if let mode = snapshot.modes.first(where: { $0.id == modeID }) {
        feedback = ActionFeedback(message: "\"\(mode.name)\" is now primary.", tone: .success)
      }
    }
  }

  func deleteMode(_ modeID: UUID) async {
    await runTask(action: .saveMode) { [self] in
      guard let index = snapshot.modes.firstIndex(where: { $0.id == modeID }) else {
        throw ValidationError.missingMode
      }

      let deletedMode = snapshot.modes[index]
      snapshot.modes.remove(at: index)

      if deletedMode.isDefault, !snapshot.modes.isEmpty {
        clearDefaultFlag()
        snapshot.modes[0].isDefault = true
      }

      snapshot.scheduledPlans.removeAll { $0.modeId == deletedMode.id }

      if snapshot.activeSession?.modeId == deletedMode.id {
        shieldingService.clear()
        snapshot.temporaryUnlock = nil
        clearParagraphChallenge()
        cancelTemporaryUnlockExpiration()
        snapshot.activeSession = nil
      }

      selectedModeID = preferredMode()?.id
      ensureDefaultMode()
      try persist()
      feedback = ActionFeedback(message: "\"\(deletedMode.name)\" removed.", tone: .success)
    }
  }

  func renamePairedSticker(_ tagID: UUID, name: String) async {
    await runTask(action: .renameAnchor) { [self] in
      guard let index = snapshot.pairedTags.firstIndex(where: { $0.id == tagID }) else {
        throw ValidationError.missingPairedTag
      }

      let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
      let displayName = trimmedName.isEmpty ? "Desk anchor" : trimmedName
      snapshot.pairedTags[index].displayName = displayName
      draftTagName = snapshot.pairedTags[index].displayName
      try persist()
      feedback = ActionFeedback(message: "Anchor renamed to \(displayName).", tone: .success)
    }
  }

  func unpairSticker(_ tagID: UUID) async {
    await runTask(action: .removeAnchor, successMessage: "Anchor removed.") { [self] in
      guard let index = snapshot.pairedTags.firstIndex(where: { $0.id == tagID }) else {
        throw ValidationError.missingPairedTag
      }

      let removedTag = snapshot.pairedTags.remove(at: index)
      snapshot.scheduledPlans.removeAll { $0.pairedTagId == removedTag.id }

      if snapshot.activeSession?.pairedTagId == removedTag.id {
        shieldingService.clear()
        snapshot.temporaryUnlock = nil
        clearParagraphChallenge()
        cancelTemporaryUnlockExpiration()
        snapshot.activeSession = nil
      }
      try persist()
    }
  }

  func selectMode(_ modeID: UUID) {
    selectedModeID = modeID
    if let mode = snapshot.modes.first(where: { $0.id == modeID }) {
      feedback = ActionFeedback(message: "\"\(mode.name)\" selected.", tone: .neutral)
    }
  }

  func selectedMode() -> BlockMode? {
    guard let selectedModeID else {
      return nil
    }
    return snapshot.modes.first(where: { $0.id == selectedModeID })
  }

  func pairedTag(_ tagID: UUID) -> PairedTag? {
    snapshot.pairedTags.first(where: { $0.id == tagID })
  }

  func scheduledPlan(_ planID: UUID) -> ScheduledSessionPlan? {
    snapshot.scheduledPlans.first(where: { $0.id == planID })
  }

  func preferredMode() -> BlockMode? {
    AnclaCore.preferredMode(in: snapshot)
  }

  func isModeArmed(_ modeID: UUID) -> Bool {
    guard snapshot.activeSession?.modeId == modeID else {
      return false
    }

    switch snapshot.activeSession?.state {
    case .armed, .mismatchedTag:
      return true
    default:
      return false
    }
  }

  func selectionSummary(for mode: BlockMode) -> String {
    if isSideloadLiteBuild && mode.selectionData.isEmpty {
      return "On-device mode"
    }

    guard let selection = try? mode.decodedSelection() else {
      return "Selection unavailable"
    }
    return selectionSummary(for: selection)
  }

  func selectionSummary(for selection: FamilyActivitySelection) -> String {
    let appCount = selection.applicationTokens.count
    let categoryCount = selection.categoryTokens.count
    let domainCount = selection.webDomainTokens.count
    let totalCount = appCount + categoryCount + domainCount

    if totalCount == 0 {
      return isSideloadLiteBuild ? "On-device mode" : "No targets selected"
    }

    return "\(appCount) apps, \(categoryCount) categories, \(domainCount) domains"
  }

  func refreshDiagnostics() {
    let environment = automationAdjustedEnvironment(
      runtimeDiagnosticsProbe.environment(for: buildVariant)
    )

    if isSideloadLiteBuild {
      snapshot.isAuthorized = true
    } else {
      snapshot.isAuthorized = environment.screenTimeAuthorization.isApproved
    }

    diagnostics = AnclaCore.runtimeDiagnostics(
      snapshot: snapshot,
      environment: environment
    )
  }

  func refreshFromHeader() {
    let changed = syncScheduledSessions()
    if !changed {
      feedback = ActionFeedback(message: "Status refreshed.", tone: .neutral)
    }
  }

  func handleSceneDidBecomeActive() {
    _ = syncScheduledSessions()
    refreshScheduleNotifications()
  }

  func isActionInProgress(_ action: AppActionID) -> Bool {
    isBusy && activeAction == action
  }

  @discardableResult
  func syncScheduledSessions() -> Bool {
    let now = nowProvider()
    let dayKey = AnclaCore.dayKey(for: now)
    var didChange = syncTemporaryUnlockState(at: now)

    if let activeSession = snapshot.activeSession,
       let scheduledPlanID = activeSession.scheduledPlanID {
      if let plan = snapshot.scheduledPlans.first(where: { $0.id == scheduledPlanID }),
         !AnclaCore.scheduledPlanIsActive(plan, at: now),
         let pairedTag = AnclaCore.pairedTag(for: activeSession.pairedTagId, in: snapshot),
         let mode = snapshot.modes.first(where: { $0.id == activeSession.modeId }),
         let index = snapshot.scheduledPlans.firstIndex(where: { $0.id == scheduledPlanID }),
         activeSession.state == .armed || activeSession.state == .mismatchedTag
      {
        snapshot.scheduledPlans[index].lastEndedDayKey = dayKey
        try? completeRelease(
          activeSession: activeSession,
          mode: mode,
          pairedTag: pairedTag,
          releaseMethod: .schedule,
          releasedAt: now
        )
        if lastError == nil {
          feedback = ActionFeedback(message: "\"\(mode.name)\" ended on schedule.", tone: .neutral)
        }
        didChange = true
      }
    }

    if !AnclaCore.activeSessionIsBlocking(snapshot) {
      for index in snapshot.scheduledPlans.indices {
        let plan = snapshot.scheduledPlans[index]
        guard AnclaCore.scheduledPlanIsActive(plan, at: now) else {
          continue
        }
        guard plan.lastStartedDayKey != dayKey else {
          continue
        }
        guard
          let mode = snapshot.modes.first(where: { $0.id == plan.modeId }),
          let pairedTag = AnclaCore.pairedTag(for: plan.pairedTagId, in: snapshot)
        else {
          continue
        }

        do {
          try armScheduledSession(
            plan: plan,
            mode: mode,
            pairedTag: pairedTag,
            armedAt: now,
            dayKey: dayKey
          )
          if lastError == nil {
            feedback = ActionFeedback(message: "\"\(mode.name)\" started on schedule.", tone: .success)
          }
          didChange = true
        } catch {
          lastError = error.localizedDescription
          feedback = ActionFeedback(message: error.localizedDescription, tone: .error)
        }
        break
      }
    }

    refreshDiagnostics()
    return didChange
  }

  private func persist() throws {
    try store.save(snapshot)
    refreshScheduleNotifications()
  }

  private func refreshScheduleNotifications() {
    let snapshot = snapshot
    let now = nowProvider()
    Task { @MainActor [scheduleNotificationService] in
      await scheduleNotificationService.refresh(for: snapshot, now: now)
    }
  }

  private func arm(mode: BlockMode) async throws {
    guard snapshot.isAuthorized else {
      throw ValidationError.missingAuthorization
    }

    guard !snapshot.pairedTags.isEmpty else {
      throw ValidationError.missingPairedTag
    }

    let scannedHash = try await stickerPairingService.scanSticker()
    guard let pairedTag = AnclaCore.matchedPairedTag(for: scannedHash, in: snapshot) else {
      throw ValidationError.mismatchedTagOnArm
    }

    try shieldingService.apply(mode: mode)
    snapshot.temporaryUnlock = nil
    clearParagraphChallenge()
    cancelTemporaryUnlockExpiration()
    snapshot.activeSession = AnchorSession(
      pairedTagId: pairedTag.id,
      modeId: mode.id,
      state: .armed
    )
    try persist()
  }

  private func armScheduledSession(
    plan: ScheduledSessionPlan,
    mode: BlockMode,
    pairedTag: PairedTag,
    armedAt: Date,
    dayKey: String
  ) throws {
    try shieldingService.apply(mode: mode)
    snapshot.temporaryUnlock = nil
    clearParagraphChallenge()
    cancelTemporaryUnlockExpiration()
    snapshot.activeSession = AnchorSession(
      pairedTagId: pairedTag.id,
      modeId: mode.id,
      state: .armed,
      armedAt: armedAt,
      scheduledPlanID: plan.id
    )
    if let index = snapshot.scheduledPlans.firstIndex(where: { $0.id == plan.id }) {
      snapshot.scheduledPlans[index].lastStartedDayKey = dayKey
      snapshot.scheduledPlans[index].lastEndedDayKey = nil
    }
    selectedModeID = mode.id
    try persist()
  }

  private func completeRelease(
    activeSession: AnchorSession,
    mode: BlockMode,
    pairedTag: PairedTag,
    releaseMethod: SessionReleaseMethod,
    releasedAt: Date = .now
  ) throws {
    shieldingService.clear()
    snapshot.temporaryUnlock = nil
    clearParagraphChallenge()
    cancelTemporaryUnlockExpiration()
    let releasedSession = AnchorSession(
      id: activeSession.id,
      pairedTagId: activeSession.pairedTagId,
      modeId: activeSession.modeId,
      state: .released,
      armedAt: activeSession.armedAt,
      releasedAt: releasedAt,
      scheduledPlanID: activeSession.scheduledPlanID
    )
    snapshot.activeSession = releasedSession
    snapshot = AnclaCore.recordHistory(
      in: snapshot,
      session: releasedSession,
      mode: mode,
      pairedTag: pairedTag,
      releaseMethod: releaseMethod,
      releasedAt: releasedAt
    )
    try persist()
  }

  private func clearDefaultFlag() {
    for index in snapshot.modes.indices {
      snapshot.modes[index].isDefault = false
    }
  }

  private func ensureDefaultMode() {
    snapshot = AnclaCore.repairedSnapshot(snapshot)
  }

  private func selectionHasTargets(_ selection: FamilyActivitySelection) -> Bool {
    !selection.applicationTokens.isEmpty
      || !selection.categoryTokens.isEmpty
      || !selection.webDomainTokens.isEmpty
  }

  private func existingScheduledPlan() -> ScheduledSessionPlan? {
    guard let draftScheduleID else {
      return nil
    }

    return snapshot.scheduledPlans.first(where: { $0.id == draftScheduleID })
  }

  private func existingUnlockPreset() -> UnlockPreset? {
    guard let draftPresetID else {
      return nil
    }

    return snapshot.unlockPresets.first(where: { $0.id == draftPresetID })
  }

  private func releaseDeletedScheduledSession(planID: UUID) throws {
    guard
      let activeSession = snapshot.activeSession,
      activeSession.scheduledPlanID == planID,
      let pairedTag = AnclaCore.pairedTag(for: activeSession.pairedTagId, in: snapshot),
      let mode = snapshot.modes.first(where: { $0.id == activeSession.modeId })
    else {
      snapshot.activeSession = nil
      shieldingService.clear()
      try persist()
      return
    }

    try completeRelease(
      activeSession: activeSession,
      mode: mode,
      pairedTag: pairedTag,
      releaseMethod: .schedule,
      releasedAt: nowProvider()
    )
  }

  private func automationAdjustedEnvironment(
    _ environment: RuntimeEnvironmentSnapshot
  ) -> RuntimeEnvironmentSnapshot {
    guard AutomatedTestConfig.usesSimulatedNFC else {
      return environment
    }

    return RuntimeEnvironmentSnapshot(
      buildLabel: environment.buildLabel,
      buildDetail: environment.buildDetail,
      storageLabel: environment.storageLabel,
      storageDetail: environment.storageDetail,
      storageTone: environment.storageTone,
      nfcAvailable: true,
      screenTimeAuthorization: environment.screenTimeAuthorization
    )
  }

  private func normalizedChallengeText(_ text: String) -> String {
    text.replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
  }

  private func syncTemporaryUnlockState(at now: Date) -> Bool {
    guard let temporaryUnlock = snapshot.temporaryUnlock else {
      cancelTemporaryUnlockExpiration()
      return false
    }

    guard AnclaCore.activeSessionIsBlocking(snapshot) else {
      snapshot.temporaryUnlock = nil
      cancelTemporaryUnlockExpiration()
      try? persist()
      return true
    }

    guard temporaryUnlock.expiresAt <= now else {
      scheduleTemporaryUnlockExpirationIfNeeded()
      return false
    }

    do {
      try restoreShieldingAfterTemporaryUnlock()
      feedback = ActionFeedback(message: "\"\(temporaryUnlock.reason)\" ended. Block restored.", tone: .neutral)
      return true
    } catch {
      lastError = error.localizedDescription
      feedback = ActionFeedback(message: error.localizedDescription, tone: .error)
      return false
    }
  }

  private func restoreShieldingAfterTemporaryUnlock() throws {
    guard snapshot.temporaryUnlock != nil else {
      cancelTemporaryUnlockExpiration()
      return
    }

    guard
      let activeSession = snapshot.activeSession,
      activeSession.state == .armed || activeSession.state == .mismatchedTag,
      let mode = snapshot.modes.first(where: { $0.id == activeSession.modeId })
    else {
      snapshot.temporaryUnlock = nil
      cancelTemporaryUnlockExpiration()
      try persist()
      return
    }

    try shieldingService.apply(mode: mode)
    snapshot.temporaryUnlock = nil
    cancelTemporaryUnlockExpiration()
    try persist()
  }

  private func scheduleTemporaryUnlockExpirationIfNeeded() {
    guard !AutomatedTestConfig.isRunningTests else {
      return
    }

    temporaryUnlockTask?.cancel()

    guard let temporaryUnlock = snapshot.temporaryUnlock else {
      cancelTemporaryUnlockExpiration()
      return
    }

    let remaining = temporaryUnlock.expiresAt.timeIntervalSince(nowProvider())
    guard remaining > 0 else {
      Task { @MainActor [weak self] in
        _ = self?.syncScheduledSessions()
      }
      return
    }

    beginTemporaryUnlockBackgroundTask()
    temporaryUnlockTask = Task { @MainActor [weak self] in
      let nanoseconds = UInt64(remaining * 1_000_000_000)
      try? await Task.sleep(nanoseconds: nanoseconds)
      guard !Task.isCancelled else {
        return
      }
      _ = self?.syncScheduledSessions()
    }
  }

  private func cancelTemporaryUnlockExpiration() {
    temporaryUnlockTask?.cancel()
    temporaryUnlockTask = nil
    endTemporaryUnlockBackgroundTask()
  }

#if canImport(UIKit)
  private func beginTemporaryUnlockBackgroundTask() {
    guard temporaryUnlockBackgroundTask == .invalid else {
      return
    }

    temporaryUnlockBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ancla-preset-unlock") { [weak self] in
      Task { @MainActor in
        self?.endTemporaryUnlockBackgroundTask()
      }
    }
  }

  private func endTemporaryUnlockBackgroundTask() {
    guard temporaryUnlockBackgroundTask != .invalid else {
      return
    }

    UIApplication.shared.endBackgroundTask(temporaryUnlockBackgroundTask)
    temporaryUnlockBackgroundTask = .invalid
  }
#else
  private func beginTemporaryUnlockBackgroundTask() {}

  private func endTemporaryUnlockBackgroundTask() {}
#endif

  private func runTask(
    action: AppActionID,
    successMessage: String? = nil,
    _ operation: @escaping () async throws -> Void
  ) async {
    isBusy = true
    activeAction = action
    lastError = nil
    feedback = nil

    do {
      try await operation()
      if let successMessage {
        feedback = ActionFeedback(message: successMessage, tone: .success)
      }
    } catch {
      if case StickerPairingError.userCanceled = error {
        feedback = ActionFeedback(message: "Anchor scan canceled.", tone: .neutral)
      } else {
        lastError = error.localizedDescription
        feedback = ActionFeedback(message: error.localizedDescription, tone: .error)
      }
    }

    isBusy = false
    activeAction = nil
    _ = syncScheduledSessions()
  }
}

enum ValidationError: LocalizedError {
  case missingAuthorization
  case missingPairedTag
  case missingMode
  case missingUnlockPreset
  case noTargetsSelected
  case noEmergencyUnbricksRemaining
  case duplicatePairedTag
  case mismatchedTagOnArm
  case mismatchedTag
  case sessionNotArmed
  case missingScheduledSession
  case invalidScheduledSession
  case invalidUnlockPreset
  case paragraphChallengeUnavailable
  case paragraphChallengeMismatch

  var errorDescription: String? {
    switch self {
    case .missingAuthorization:
      return "Enable App Controls before starting a session."
    case .missingPairedTag:
      return "Pair an anchor before starting a session."
    case .missingMode:
      return "Create a mode before starting a session."
    case .missingUnlockPreset:
      return "Create a preset before trying to use it."
    case .noTargetsSelected:
      return "Choose at least one app, category, or domain."
    case .noEmergencyUnbricksRemaining:
      return "No emergency unbricks remain on this iPhone."
    case .duplicatePairedTag:
      return "That NFC anchor is already paired on this iPhone."
    case .mismatchedTagOnArm:
      return "Scan any paired anchor to start this session."
    case .mismatchedTag:
      return "That anchor does not match the release anchor for this session."
    case .sessionNotArmed:
      return "Start a session before attempting release."
    case .missingScheduledSession:
      return "Create a scheduled session before editing it."
    case .invalidScheduledSession:
      return "Pick a mode, pick an anchor, choose at least one day, and keep the end time after the start time."
    case .invalidUnlockPreset:
      return "Give the preset a name and keep the duration between 5 and 300 seconds."
    case .paragraphChallengeUnavailable:
      return "No paragraph challenge is available for this session."
    case .paragraphChallengeMismatch:
      return "The text must match exactly, including punctuation."
    }
  }
}

private extension Optional {
  func orThrow(_ error: some Error) throws -> Wrapped {
    guard let self else {
      throw error
    }
    return self
  }
}
