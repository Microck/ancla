import AppIntents
import Foundation

struct CheckBlockStatusIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Block Status"
  static var description = IntentDescription(
    "Returns whether Ancla is currently blocking this iPhone, excluding temporary preset unlock windows."
  )
  static var openAppWhenRun = false

  @MainActor
  func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
    let snapshot = try loadSnapshot()
    let isBlocking = AnclaCore.shortcutRedirectIsActive(snapshot, at: .now)

    return .result(
      value: isBlocking,
      dialog: IntentDialog(
        stringLiteral: isBlocking
          ? "Ancla is actively blocking this iPhone."
          : "Ancla is not actively blocking this iPhone."
      )
    )
  }

  @MainActor
  private func loadSnapshot() throws -> AppSnapshot {
#if SIDELOAD_LITE
    return AnclaCore.repairedSnapshot(try LocalSnapshotStore().load())
#else
    return AnclaCore.repairedSnapshot(try AppGroupStore().load())
#endif
  }
}

struct AnclaAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: CheckBlockStatusIntent(),
      phrases: [
        "Get \(.applicationName) block status",
        "Is \(.applicationName) blocking this iPhone",
        "Check whether \(.applicationName) is blocking"
      ],
      shortTitle: "Block Status",
      systemImageName: "lock"
    )
  }
}
