import Foundation

enum AnclaCore {
  static func minuteOfDay(for date: Date, calendar: Calendar = .current) -> Int {
    let components = calendar.dateComponents([.hour, .minute], from: date)
    return (components.hour ?? 0) * 60 + (components.minute ?? 0)
  }

  static func weekdayNumber(for date: Date, calendar: Calendar = .current) -> Int {
    calendar.component(.weekday, from: date)
  }

  static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
  }

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

  static func sortedScheduledPlans(
    _ plans: [ScheduledSessionPlan],
    at date: Date = .now,
    calendar: Calendar = .current
  ) -> [ScheduledSessionPlan] {
    plans.sorted { lhs, rhs in
      let lhsIsActive = scheduledPlanIsActive(lhs, at: date, calendar: calendar)
      let rhsIsActive = scheduledPlanIsActive(rhs, at: date, calendar: calendar)
      if lhsIsActive != rhsIsActive {
        return lhsIsActive
      }

      if lhs.isEnabled != rhs.isEnabled {
        return lhs.isEnabled
      }

      if lhs.startMinuteOfDay != rhs.startMinuteOfDay {
        return lhs.startMinuteOfDay < rhs.startMinuteOfDay
      }

      return lhs.id.uuidString < rhs.id.uuidString
    }
  }

  static func scheduledPlanIsActive(
    _ plan: ScheduledSessionPlan,
    at date: Date,
    calendar: Calendar = .current
  ) -> Bool {
    guard plan.isEnabled else {
      return false
    }

    guard plan.endMinuteOfDay > plan.startMinuteOfDay else {
      return false
    }

    guard plan.weekdayNumbers.contains(weekdayNumber(for: date, calendar: calendar)) else {
      return false
    }

    let minutes = minuteOfDay(for: date, calendar: calendar)
    return minutes >= plan.startMinuteOfDay && minutes < plan.endMinuteOfDay
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
