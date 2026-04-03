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
  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case selectionData
    case isDefault
    case isStrict
  }

  let id: UUID
  var name: String
  var selectionData: Data
  var isDefault: Bool
  var isStrict: Bool

  init(
    id: UUID = UUID(),
    name: String,
    selectionData: Data = Data(),
    isDefault: Bool = false,
    isStrict: Bool = false
  ) {
    self.id = id
    self.name = name
    self.selectionData = selectionData
    self.isDefault = isDefault
    self.isStrict = isStrict
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    selectionData = try container.decode(Data.self, forKey: .selectionData)
    isDefault = try container.decode(Bool.self, forKey: .isDefault)
    isStrict = try container.decodeIfPresent(Bool.self, forKey: .isStrict) ?? false
  }
}

struct ScheduledSessionPlan: Codable, Equatable, Identifiable {
  let id: UUID
  var modeId: UUID
  var pairedTagId: UUID
  var weekdayNumbers: [Int]
  var startMinuteOfDay: Int
  var endMinuteOfDay: Int
  var isEnabled: Bool
  var lastStartedDayKey: String?
  var lastEndedDayKey: String?

  init(
    id: UUID = UUID(),
    modeId: UUID,
    pairedTagId: UUID,
    weekdayNumbers: [Int],
    startMinuteOfDay: Int,
    endMinuteOfDay: Int,
    isEnabled: Bool = true,
    lastStartedDayKey: String? = nil,
    lastEndedDayKey: String? = nil
  ) {
    self.id = id
    self.modeId = modeId
    self.pairedTagId = pairedTagId
    self.weekdayNumbers = Array(Set(weekdayNumbers)).sorted()
    self.startMinuteOfDay = startMinuteOfDay
    self.endMinuteOfDay = endMinuteOfDay
    self.isEnabled = isEnabled
    self.lastStartedDayKey = lastStartedDayKey
    self.lastEndedDayKey = lastEndedDayKey
  }
}

enum AnchorSessionState: String, Codable {
  case idle
  case armed
  case released
  case mismatchedTag
}

struct AnchorSession: Codable, Equatable, Identifiable {
  private enum CodingKeys: String, CodingKey {
    case id
    case pairedTagId
    case modeId
    case state
    case armedAt
    case releasedAt
    case scheduledPlanID
  }

  let id: UUID
  let pairedTagId: UUID
  let modeId: UUID
  var state: AnchorSessionState
  let armedAt: Date
  var releasedAt: Date?
  var scheduledPlanID: UUID?

  init(
    id: UUID = UUID(),
    pairedTagId: UUID,
    modeId: UUID,
    state: AnchorSessionState,
    armedAt: Date = .now,
    releasedAt: Date? = nil,
    scheduledPlanID: UUID? = nil
  ) {
    self.id = id
    self.pairedTagId = pairedTagId
    self.modeId = modeId
    self.state = state
    self.armedAt = armedAt
    self.releasedAt = releasedAt
    self.scheduledPlanID = scheduledPlanID
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    pairedTagId = try container.decode(UUID.self, forKey: .pairedTagId)
    modeId = try container.decode(UUID.self, forKey: .modeId)
    state = try container.decode(AnchorSessionState.self, forKey: .state)
    armedAt = try container.decode(Date.self, forKey: .armedAt)
    releasedAt = try container.decodeIfPresent(Date.self, forKey: .releasedAt)
    scheduledPlanID = try container.decodeIfPresent(UUID.self, forKey: .scheduledPlanID)
  }
}

enum SessionReleaseMethod: String, Codable {
  case anchor
  case emergencyUnbrick
  case schedule
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
  private enum CodingKeys: String, CodingKey {
    case isAuthorized
    case pairedTag
    case pairedTags
    case modes
    case activeSession
    case sessionHistory
    case emergencyUnbricksRemaining
    case scheduledPlans
  }

  var isAuthorized = false
  var pairedTags: [PairedTag] = []
  var modes: [BlockMode] = []
  var activeSession: AnchorSession?
  var sessionHistory: [SessionHistoryEntry] = []
  var emergencyUnbricksRemaining = 5
  var scheduledPlans: [ScheduledSessionPlan] = []

  init(
    isAuthorized: Bool = false,
    pairedTag: PairedTag? = nil,
    pairedTags: [PairedTag] = [],
    modes: [BlockMode] = [],
    activeSession: AnchorSession? = nil,
    sessionHistory: [SessionHistoryEntry] = [],
    emergencyUnbricksRemaining: Int = 5,
    scheduledPlans: [ScheduledSessionPlan] = []
  ) {
    self.isAuthorized = isAuthorized
    self.pairedTags = pairedTags.isEmpty ? (pairedTag.map { [$0] } ?? []) : pairedTags
    self.modes = modes
    self.activeSession = activeSession
    self.sessionHistory = sessionHistory
    self.emergencyUnbricksRemaining = emergencyUnbricksRemaining
    self.scheduledPlans = scheduledPlans
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    isAuthorized = try container.decodeIfPresent(Bool.self, forKey: .isAuthorized) ?? false
    let decodedPairedTags = try container.decodeIfPresent([PairedTag].self, forKey: .pairedTags)
    if let decodedPairedTags, !decodedPairedTags.isEmpty {
      pairedTags = decodedPairedTags
    } else if let pairedTag = try container.decodeIfPresent(PairedTag.self, forKey: .pairedTag) {
      pairedTags = [pairedTag]
    } else {
      pairedTags = []
    }
    modes = try container.decodeIfPresent([BlockMode].self, forKey: .modes) ?? []
    activeSession = try container.decodeIfPresent(AnchorSession.self, forKey: .activeSession)
    sessionHistory = try container.decodeIfPresent([SessionHistoryEntry].self, forKey: .sessionHistory) ?? []
    emergencyUnbricksRemaining = try container.decodeIfPresent(Int.self, forKey: .emergencyUnbricksRemaining) ?? 5
    scheduledPlans = try container.decodeIfPresent([ScheduledSessionPlan].self, forKey: .scheduledPlans) ?? []
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(isAuthorized, forKey: .isAuthorized)
    try container.encode(pairedTags, forKey: .pairedTags)
    try container.encode(modes, forKey: .modes)
    try container.encodeIfPresent(activeSession, forKey: .activeSession)
    try container.encode(sessionHistory, forKey: .sessionHistory)
    try container.encode(emergencyUnbricksRemaining, forKey: .emergencyUnbricksRemaining)
    try container.encode(scheduledPlans, forKey: .scheduledPlans)
  }

  var pairedTag: PairedTag? {
    get { pairedTags.first }
    set {
      if let newValue {
        if pairedTags.isEmpty {
          pairedTags = [newValue]
        } else {
          pairedTags[0] = newValue
        }
      } else {
        pairedTags = []
      }
    }
  }
}
