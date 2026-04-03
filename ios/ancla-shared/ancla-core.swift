import Foundation

enum AnclaCore {
  static func sortedModes(_ modes: [BlockMode]) -> [BlockMode] {
    modes.sorted { lhs, rhs in
      if lhs.isDefault != rhs.isDefault {
        return lhs.isDefault
      }

      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
  }

  static func preferredMode(in snapshot: AppSnapshot) -> BlockMode? {
    snapshot.modes.first(where: \.isDefault) ?? snapshot.modes.first
  }

  static func repairedSnapshot(_ snapshot: AppSnapshot) -> AppSnapshot {
    guard !snapshot.modes.isEmpty else {
      return snapshot
    }

    guard !snapshot.modes.contains(where: \.isDefault) else {
      return snapshot
    }

    var repaired = snapshot
    repaired.modes[0].isDefault = true
    return repaired
  }

  static func activeSessionIsBlocking(_ snapshot: AppSnapshot) -> Bool {
    switch snapshot.activeSession?.state {
    case .armed, .mismatchedTag:
      return true
    default:
      return false
    }
  }

  static func canReleaseActiveSession(_ snapshot: AppSnapshot) -> Bool {
    activeSessionIsBlocking(snapshot)
  }

  static func canUseEmergencyUnbrick(_ snapshot: AppSnapshot) -> Bool {
    activeSessionIsBlocking(snapshot) && snapshot.emergencyUnbricksRemaining > 0
  }

  static func canArmSelectedMode(_ snapshot: AppSnapshot) -> Bool {
    snapshot.isAuthorized
      && !snapshot.pairedTags.isEmpty
      && !snapshot.modes.isEmpty
      && !activeSessionIsBlocking(snapshot)
  }

  static func pairedTag(for id: UUID, in snapshot: AppSnapshot) -> PairedTag? {
    snapshot.pairedTags.first(where: { $0.id == id })
  }

  static func matchedPairedTag(for uidHash: String, in snapshot: AppSnapshot) -> PairedTag? {
    snapshot.pairedTags.first(where: { $0.uidHash == uidHash })
  }

  static func recentHistory(
    in snapshot: AppSnapshot,
    limit: Int = 10
  ) -> [SessionHistoryEntry] {
    let entries = snapshot.sessionHistory.sorted { lhs, rhs in
      lhs.releasedAt > rhs.releasedAt
    }

    guard limit < entries.count else {
      return entries
    }

    return Array(entries.prefix(limit))
  }

  static func recordHistory(
    in snapshot: AppSnapshot,
    session: AnchorSession,
    mode: BlockMode,
    pairedTag: PairedTag,
    releaseMethod: SessionReleaseMethod,
    releasedAt: Date
  ) -> AppSnapshot {
    var updated = snapshot
    updated.sessionHistory.append(
      SessionHistoryEntry(
        sessionID: session.id,
        pairedTagId: pairedTag.id,
        pairedTagName: pairedTag.displayName,
        modeId: mode.id,
        modeName: mode.name,
        armedAt: session.armedAt,
        releasedAt: releasedAt,
        releaseMethod: releaseMethod
      )
    )
    return updated
  }
}
