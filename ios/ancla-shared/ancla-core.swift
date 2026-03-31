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

  static func canArmSelectedMode(_ snapshot: AppSnapshot) -> Bool {
    snapshot.isAuthorized
      && snapshot.pairedTag != nil
      && !snapshot.modes.isEmpty
      && !activeSessionIsBlocking(snapshot)
  }
}
