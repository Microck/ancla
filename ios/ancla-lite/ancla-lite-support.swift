import Foundation

#if SIDELOAD_LITE
enum AppBuildVariant {
  case full
  case sideloadLite

  static let current: AppBuildVariant = .sideloadLite
}
#else
enum AppBuildVariant {
  case full
  case sideloadLite

  static let current: AppBuildVariant = .full
}
#endif

enum SideloadLiteError: LocalizedError {
  case unavailable(String)

  var errorDescription: String? {
    switch self {
    case let .unavailable(message):
      return message
    }
  }
}

enum AutomatedTestConfig {
  private static let stickerHashesKey = "ANCLA_TEST_STICKER_HASHES"

  static var simulatedStickerHashes: [String] {
    ProcessInfo.processInfo.environment[stickerHashesKey]?
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty } ?? []
  }

  static var usesSimulatedNFC: Bool {
    !simulatedStickerHashes.isEmpty
  }
}

struct LocalSnapshotStore: AppSnapshotStore {
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init() {
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  }

  func load() throws -> AppSnapshot {
    let url = snapshotURL()
    guard FileManager.default.fileExists(atPath: url.path) else {
      return AppSnapshot()
    }

    let data = try Data(contentsOf: url)
    return try decoder.decode(AppSnapshot.self, from: data)
  }

  func save(_ snapshot: AppSnapshot) throws {
    let url = snapshotURL()
    let data = try encoder.encode(snapshot)
    try data.write(to: url, options: [.atomic])
  }

  private func snapshotURL() -> URL {
    let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("ancla-lite", isDirectory: true)

    if !FileManager.default.fileExists(atPath: directory.path) {
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
    }

    return directory.appendingPathComponent(AppGroupConfiguration.snapshotFilename)
  }
}

@MainActor
final class LiteAuthorizationClient: AuthorizationClienting {
  func request() async throws {
    // Sideload-lite skips Apple-managed Screen Time authorization.
  }
}

@MainActor
final class LiteShieldingService: Shielding {
  func apply(mode _: BlockMode) throws {}

  func clear() {}
}

@MainActor
final class LiteStickerPairingService: StickerPairing {
  private let scanner = StickerPairingService()
  private var simulatedHashes = AutomatedTestConfig.simulatedStickerHashes

  func scanSticker() async throws -> String {
    if !simulatedHashes.isEmpty {
      return simulatedHashes.removeFirst()
    }

    return try await scanner.scanSticker()
  }
}
