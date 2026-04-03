import Foundation

enum AppGroupConfiguration {
  static let identifier = "group.dev.micr.ancla"
  static let snapshotFilename = "ancla-snapshot.json"
}

struct PairedTag: Codable, Equatable, Identifiable {
  let id: UUID
  let uidHash: String
  var displayName: String
  let createdAt: Date

  init(id: UUID = UUID(), uidHash: String, displayName: String, createdAt: Date = .now) {
    self.id = id
    self.uidHash = uidHash
    self.displayName = displayName
    self.createdAt = createdAt
  }
}

struct BlockMode: Codable, Equatable, Identifiable {
  let id: UUID
  var name: String
  var selectionData: Data
  var isDefault: Bool

  init(id: UUID = UUID(), name: String, selectionData: Data = Data(), isDefault: Bool = false) {
    self.id = id
    self.name = name
    self.selectionData = selectionData
    self.isDefault = isDefault
  }
}

enum AnchorSessionState: String, Codable {
  case idle
  case armed
  case released
  case mismatchedTag
}

struct AnchorSession: Codable, Equatable, Identifiable {
  let id: UUID
  let pairedTagId: UUID
  let modeId: UUID
  var state: AnchorSessionState
  let armedAt: Date
  var releasedAt: Date?

  init(
    id: UUID = UUID(),
    pairedTagId: UUID,
    modeId: UUID,
    state: AnchorSessionState,
    armedAt: Date = .now,
    releasedAt: Date? = nil
  ) {
    self.id = id
    self.pairedTagId = pairedTagId
    self.modeId = modeId
    self.state = state
    self.armedAt = armedAt
    self.releasedAt = releasedAt
  }
}

enum SessionReleaseMethod: String, Codable {
  case anchor
  case emergencyUnbrick
}

struct SessionHistoryEntry: Codable, Equatable, Identifiable {
  let id: UUID
  let sessionID: UUID
  let pairedTagId: UUID
  let pairedTagName: String
  let modeId: UUID
  let modeName: String
  let armedAt: Date
  let releasedAt: Date
  let releaseMethod: SessionReleaseMethod

  init(
    id: UUID = UUID(),
    sessionID: UUID,
    pairedTagId: UUID,
    pairedTagName: String,
    modeId: UUID,
    modeName: String,
    armedAt: Date,
    releasedAt: Date,
    releaseMethod: SessionReleaseMethod
  ) {
    self.id = id
    self.sessionID = sessionID
    self.pairedTagId = pairedTagId
    self.pairedTagName = pairedTagName
    self.modeId = modeId
    self.modeName = modeName
    self.armedAt = armedAt
    self.releasedAt = releasedAt
    self.releaseMethod = releaseMethod
  }

  var duration: TimeInterval {
    max(0, releasedAt.timeIntervalSince(armedAt))
  }
}

struct AppSnapshot: Codable, Equatable {
  var isAuthorized = false
  var pairedTag: PairedTag?
  var modes: [BlockMode] = []
  var activeSession: AnchorSession?
  var sessionHistory: [SessionHistoryEntry] = []
  var emergencyUnbricksRemaining = 5
}
