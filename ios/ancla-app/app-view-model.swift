#if !SIDELOAD_LITE
import FamilyControls
#endif
import Foundation
import Observation

enum AppActionID: Equatable {
  case refresh
  case authorize
  case pairAnchor
  case replaceAnchor
  case armSession
  case releaseSession
  case renameAnchor
  case removeAnchor
  case saveMode
}

enum ActionFeedbackTone {
  case neutral
  case success
  case error
}

struct ActionFeedback: Equatable {
  let message: String
  let tone: ActionFeedbackTone
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
  var draftTagName = "Desk anchor"
  var selectedModeID: UUID?
  var isPickerPresented = false
  var isBusy = false
  var activeAction: AppActionID?
  var lastError: String?
  var feedback: ActionFeedback?

  private let store: any AppSnapshotStore
  private let authorizationClient: any AuthorizationClienting
  private let shieldingService: any Shielding
  private let stickerPairingService: any StickerPairing
  private let runtimeDiagnosticsProbe: any RuntimeDiagnosticsProbing

  init(
    buildVariant: AppBuildVariant = .current,
    store: (any AppSnapshotStore)? = nil,
    authorizationClient: (any AuthorizationClienting)? = nil,
    shieldingService: (any Shielding)? = nil,
    stickerPairingService: (any StickerPairing)? = nil,
    runtimeDiagnosticsProbe: (any RuntimeDiagnosticsProbing)? = nil
  ) {
    self.buildVariant = buildVariant
    self.runtimeDiagnosticsProbe = runtimeDiagnosticsProbe ?? LiveRuntimeDiagnosticsProbe()

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

  var isNFCAvailable: Bool {
    diagnostics.items.first(where: { $0.id == "nfc" })?.value == "Ready"
  }

  var activeSessionIsBlocking: Bool {
    AnclaCore.activeSessionIsBlocking(snapshot)
  }

  var canReleaseActiveSession: Bool {
    AnclaCore.canReleaseActiveSession(snapshot)
  }

  var canArmSelectedMode: Bool {
    AnclaCore.canArmSelectedMode(snapshot)
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
    refreshDiagnostics()
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

  func prepareDraftForNewMode() {
    lastError = nil
    draftModeID = nil
    draftModeName = "Work block"
    draftSelection = FamilyActivitySelection()
    draftModeShouldBeDefault = snapshot.modes.isEmpty
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

  func pairSticker() async {
    await runTask(action: .pairAnchor) { [self] in
      let uidHash = try await stickerPairingService.scanSticker()
      let trimmedName = draftTagName.trimmingCharacters(in: .whitespacesAndNewlines)
      let displayName = trimmedName.isEmpty ? "Desk anchor" : trimmedName
      snapshot.pairedTag = PairedTag(
        uidHash: uidHash,
        displayName: displayName
      )
      try persist()
      feedback = ActionFeedback(message: "\(displayName) paired.", tone: .success)
    }
  }

  func replaceSticker() async {
    await runTask(action: .replaceAnchor) { [self] in
      let uidHash = try await stickerPairingService.scanSticker()
      let trimmedName = draftTagName.trimmingCharacters(in: .whitespacesAndNewlines)
      let displayName = trimmedName.isEmpty ? "Desk anchor" : trimmedName
      snapshot.pairedTag = PairedTag(
        uidHash: uidHash,
        displayName: displayName
      )
      try persist()
      feedback = ActionFeedback(message: "\(displayName) paired as the new anchor.", tone: .success)
    }
  }

  func armSelectedMode() async {
    await runTask(action: .armSession) { [self] in
      guard let mode = selectedMode() ?? preferredMode() else {
        throw ValidationError.missingMode
      }

      try arm(mode: mode)
      feedback = ActionFeedback(message: "\"\(mode.name)\" is active.", tone: .success)
    }
  }

  func armMode(_ modeID: UUID) async {
    await runTask(action: .armSession) { [self] in
      guard let mode = snapshot.modes.first(where: { $0.id == modeID }) else {
        throw ValidationError.missingMode
      }
      selectedModeID = mode.id
      try arm(mode: mode)
      feedback = ActionFeedback(message: "\"\(mode.name)\" is active.", tone: .success)
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
      guard scannedHash == snapshot.pairedTag?.uidHash else {
        snapshot.activeSession?.state = .mismatchedTag
        try persist()
        throw ValidationError.mismatchedTag
      }

      guard
        let pairedTag = snapshot.pairedTag,
        let mode = snapshot.modes.first(where: { $0.id == activeSession.modeId })
      else {
        throw ValidationError.missingMode
      }

      let releasedAt = Date.now
      shieldingService.clear()
      let releasedSession = AnchorSession(
        id: activeSession.id,
        pairedTagId: activeSession.pairedTagId,
        modeId: activeSession.modeId,
        state: .released,
        armedAt: activeSession.armedAt,
        releasedAt: releasedAt
      )
      snapshot.activeSession = releasedSession
      snapshot = AnclaCore.recordHistory(
        in: snapshot,
        session: releasedSession,
        mode: mode,
        pairedTag: pairedTag,
        releaseMethod: .anchor,
        releasedAt: releasedAt
      )
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

      if snapshot.activeSession?.modeId == deletedMode.id {
        shieldingService.clear()
        snapshot.activeSession = nil
      }

      selectedModeID = preferredMode()?.id
      ensureDefaultMode()
      try persist()
      feedback = ActionFeedback(message: "\"\(deletedMode.name)\" removed.", tone: .success)
    }
  }

  func renamePairedSticker(_ name: String) async {
    await runTask(action: .renameAnchor) { [self] in
      guard snapshot.pairedTag != nil else {
        throw ValidationError.missingPairedTag
      }

      let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
      let displayName = trimmedName.isEmpty ? "Desk anchor" : trimmedName
      snapshot.pairedTag?.displayName = displayName
      draftTagName = snapshot.pairedTag?.displayName ?? "Desk anchor"
      try persist()
      feedback = ActionFeedback(message: "Anchor renamed to \(displayName).", tone: .success)
    }
  }

  func unpairSticker() async {
    await runTask(action: .removeAnchor, successMessage: "Anchor removed.") { [self] in
      snapshot.pairedTag = nil
      if snapshot.activeSession != nil {
        shieldingService.clear()
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
    let environment = runtimeDiagnosticsProbe.environment(for: buildVariant)

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
    refreshDiagnostics()
    feedback = ActionFeedback(message: "Status refreshed.", tone: .neutral)
  }

  func isActionInProgress(_ action: AppActionID) -> Bool {
    isBusy && activeAction == action
  }

  private func persist() throws {
    try store.save(snapshot)
  }

  private func arm(mode: BlockMode) throws {
    guard snapshot.isAuthorized else {
      throw ValidationError.missingAuthorization
    }

    guard let pairedTag = snapshot.pairedTag else {
      throw ValidationError.missingPairedTag
    }

    try shieldingService.apply(mode: mode)
    snapshot.activeSession = AnchorSession(
      pairedTagId: pairedTag.id,
      modeId: mode.id,
      state: .armed
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
    refreshDiagnostics()
  }
}

enum ValidationError: LocalizedError {
  case missingAuthorization
  case missingPairedTag
  case missingMode
  case noTargetsSelected
  case mismatchedTag
  case sessionNotArmed

  var errorDescription: String? {
    switch self {
    case .missingAuthorization:
      return "Enable App Controls before starting a session."
    case .missingPairedTag:
      return "Pair an anchor before starting a session."
    case .missingMode:
      return "Create a mode before starting a session."
    case .noTargetsSelected:
      return "Choose at least one app, category, or domain."
    case .mismatchedTag:
      return "That anchor does not match the paired release key."
    case .sessionNotArmed:
      return "Start a session before attempting release."
    }
  }
}
