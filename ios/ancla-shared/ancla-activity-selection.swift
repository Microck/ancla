import Foundation

#if !SIDELOAD_LITE
import FamilyControls
#endif

#if SIDELOAD_LITE
struct FamilyActivitySelection: Codable, Equatable {
  var applicationTokens: Set<String> = []
  var categoryTokens: Set<String> = []
  var webDomainTokens: Set<String> = []
}
#endif

extension BlockMode {
  init(
    id: UUID = UUID(),
    name: String,
    selection: FamilyActivitySelection,
    isDefault: Bool = false,
    isStrict: Bool = false
  ) throws {
    self.init(
      id: id,
      name: name,
      selectionData: try JSONEncoder().encode(selection),
      isDefault: isDefault,
      isStrict: isStrict
    )
  }

  func decodedSelection() throws -> FamilyActivitySelection {
    try JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData)
  }
}
