import Foundation

protocol AppSnapshotStore {
  func load() throws -> AppSnapshot
  func save(_ snapshot: AppSnapshot) throws
}

@MainActor
protocol AuthorizationClienting {
  func request() async throws
}

@MainActor
protocol Shielding {
  func apply(mode: BlockMode) throws
  func clear()
}

@MainActor
protocol StickerPairing {
  func scanSticker() async throws -> String
}

@MainActor
protocol ScheduleNotifying {
  func refresh(for snapshot: AppSnapshot, now: Date) async
}
