import Foundation
import UserNotifications

@MainActor
final class LiveScheduleNotificationService: ScheduleNotifying {
  static let shared = LiveScheduleNotificationService()

  private let center = UNUserNotificationCenter.current()
  private let identifierPrefix = "ancla.schedule."
  private var requestedAuthorizationThisLaunch = false

  func refresh(for snapshot: AppSnapshot, now: Date) async {
    guard !AutomatedTestConfig.isRunningTests else {
      return
    }

    let existingIdentifiers = await pendingScheduleIdentifiers()
    if !existingIdentifiers.isEmpty {
      center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)
      center.removeDeliveredNotifications(withIdentifiers: existingIdentifiers)
    }

    let plans = snapshot.scheduledPlans.filter { plan in
      plan.isEnabled && plan.endMinuteOfDay > plan.startMinuteOfDay
    }
    guard !plans.isEmpty else {
      return
    }

    guard await canScheduleNotifications() else {
      return
    }

    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: now)
    var requests: [UNNotificationRequest] = []

    for dayOffset in 0..<7 {
      guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else {
        continue
      }

      let weekday = calendar.component(.weekday, from: day)
      let dayKey = AnclaCore.dayKey(for: day, calendar: calendar)

      for plan in plans where plan.weekdayNumbers.contains(weekday) {
        guard
          let mode = snapshot.modes.first(where: { $0.id == plan.modeId }),
          let pairedTag = AnclaCore.pairedTag(for: plan.pairedTagId, in: snapshot)
        else {
          continue
        }

        if let startDate = date(on: day, minuteOfDay: plan.startMinuteOfDay, calendar: calendar),
           startDate > now
        {
          requests.append(
            notificationRequest(
              identifier: "\(identifierPrefix)\(plan.id.uuidString).\(dayKey).start",
              title: "\(mode.name) is scheduled now",
              body: "Open Ancla to start the scheduled session. \(pairedTag.displayName) stays the release anchor.",
              date: startDate,
              calendar: calendar
            )
          )
        }

        if let endDate = date(on: day, minuteOfDay: plan.endMinuteOfDay, calendar: calendar),
           endDate > now
        {
          requests.append(
            notificationRequest(
              identifier: "\(identifierPrefix)\(plan.id.uuidString).\(dayKey).end",
              title: "\(mode.name) schedule window ended",
              body: "Open Ancla to sync the session state if this schedule was active.",
              date: endDate,
              calendar: calendar
            )
          )
        }
      }
    }

    for request in requests {
      try? await add(request)
    }
  }

  private func canScheduleNotifications() async -> Bool {
    let settings = await notificationSettings()
    switch settings.authorizationStatus {
    case .authorized, .provisional, .ephemeral:
      return true
    case .notDetermined:
      guard !requestedAuthorizationThisLaunch else {
        return false
      }
      requestedAuthorizationThisLaunch = true
      return (try? await center.requestAuthorization(options: [.alert, .sound])) == true
    case .denied:
      return false
    @unknown default:
      return false
    }
  }

  private func notificationRequest(
    identifier: String,
    title: String,
    body: String,
    date: Date,
    calendar: Calendar
  ) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute],
      from: date
    )
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
  }

  private func date(on day: Date, minuteOfDay: Int, calendar: Calendar) -> Date? {
    calendar.date(byAdding: .minute, value: minuteOfDay, to: day)
  }

  private func notificationSettings() async -> UNNotificationSettings {
    await withCheckedContinuation { continuation in
      center.getNotificationSettings { settings in
        continuation.resume(returning: settings)
      }
    }
  }

  private func pendingScheduleIdentifiers() async -> [String] {
    await withCheckedContinuation { continuation in
      center.getPendingNotificationRequests { requests in
        continuation.resume(
          returning: requests
            .map(\.identifier)
            .filter { $0.hasPrefix(self.identifierPrefix) }
        )
      }
    }
  }

  private func add(_ request: UNNotificationRequest) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      center.add(request) { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: ())
        }
      }
    }
  }
}
