import Foundation

enum AppGroupStoreError: Error {
  case missingContainer
}

extension AppGroupStoreError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .missingContainer:
      return "App Group container is unavailable. Verify entitlements and signing."
    }
  }
}

struct AppGroupStore: AppSnapshotStore {
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init() {
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  }

  func load() throws -> AppSnapshot {
    let url = try snapshotURL()
    guard FileManager.default.fileExists(atPath: url.path) else {
      return AppSnapshot()
    }

    let data = try Data(contentsOf: url)
    return try decoder.decode(AppSnapshot.self, from: data)
  }

  func save(_ snapshot: AppSnapshot) throws {
    let url = try snapshotURL()
    let data = try encoder.encode(snapshot)
    try data.write(to: url, options: [.atomic])
  }

  private func snapshotURL() throws -> URL {
    guard let directory = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: AppGroupConfiguration.identifier
    ) else {
      throw AppGroupStoreError.missingContainer
    }

    return directory.appendingPathComponent(AppGroupConfiguration.snapshotFilename)
  }
}
