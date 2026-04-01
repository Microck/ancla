import FamilyControls
import Foundation
import Observation

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
  var draftTagName = "Desk sticker"
  var selectedModeID: UUID?
  var isPickerPresented = false
  var isBusy = false
  var lastError: String?

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
      self.store = store ?? AppGroupStore()
      self.authorizationClient = authorizationClient ?? AuthorizationClient()
      self.shieldingService = shieldingService ?? ShieldingService()
      self.stickerPairingService = stickerPairingService ?? StickerPairingService()
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
    await runTask { [self] in
      try await authorizationClient.request()
      snapshot.isAuthorized = true
      try persist()
    }
  }

  func saveMode() async {
    await runTask { [self] in
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
    }
  }

  func pairSticker() async {
    await runTask { [self] in
      let uidHash = try await stickerPairingService.scanSticker()
      let trimmedName = draftTagName.trimmingCharacters(in: .whitespacesAndNewlines)
      snapshot.pairedTag = PairedTag(
        uidHash: uidHash,
        displayName: trimmedName.isEmpty ? "Desk sticker" : trimmedName
      )
      try persist()
    }
  }

  func armSelectedMode() async {
    await runTask { [self] in
      guard let mode = selectedMode() ?? preferredMode() else {
        throw ValidationError.missingMode
      }

      try arm(mode: mode)
    }
  }

  func armMode(_ modeID: UUID) async {
    await runTask { [self] in
      guard let mode = snapshot.modes.first(where: { $0.id == modeID }) else {
        throw ValidationError.missingMode
      }
      selectedModeID = mode.id
      try arm(mode: mode)
    }
  }

  func releaseActiveSession() async {
    await runTask { [self] in
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

      shieldingService.clear()
      snapshot.activeSession = AnchorSession(
        id: activeSession.id,
        pairedTagId: activeSession.pairedTagId,
        modeId: activeSession.modeId,
        state: .released,
        armedAt: activeSession.armedAt,
        releasedAt: .now
      )
      try persist()
    }
  }

  func setDefaultMode(_ modeID: UUID) async {
    await runTask { [self] in
      guard snapshot.modes.contains(where: { $0.id == modeID }) else {
        throw ValidationError.missingMode
      }

      clearDefaultFlag()
      if let index = snapshot.modes.firstIndex(where: { $0.id == modeID }) {
        snapshot.modes[index].isDefault = true
      }
      selectedModeID = modeID
      try persist()
    }
  }

  func deleteMode(_ modeID: UUID) async {
    await runTask { [self] in
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
    }
  }

  func renamePairedSticker(_ name: String) async {
    await runTask { [self] in
      guard snapshot.pairedTag != nil else {
        throw ValidationError.missingPairedTag
      }

      let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
      snapshot.pairedTag?.displayName = trimmedName.isEmpty ? "Desk sticker" : trimmedName
      draftTagName = snapshot.pairedTag?.displayName ?? "Desk sticker"
      try persist()
    }
  }

  func unpairSticker() async {
    await runTask { [self] in
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
      return "Local mode only"
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
      return isSideloadLiteBuild ? "Local mode only" : "No targets selected"
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

  private func runTask(_ operation: @escaping () async throws -> Void) async {
    isBusy = true
    lastError = nil

    do {
      try await operation()
    } catch {
      if case StickerPairingError.userCanceled = error {
      } else {
        lastError = error.localizedDescription
      }
    }

    isBusy = false
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
      return "Grant Screen Time access before arming a mode."
    case .missingPairedTag:
      return "Pair a sticker before arming a mode."
    case .missingMode:
      return "Create a block mode before arming Ancla."
    case .noTargetsSelected:
      return "Choose at least one app, category, or domain."
    case .mismatchedTag:
      return "That sticker is not the paired anchor."
    case .sessionNotArmed:
      return "Arm a mode before trying to release."
    }
  }
}
