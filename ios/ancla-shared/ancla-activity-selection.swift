import FamilyControls
import Foundation

extension BlockMode {
  init(
    id: UUID = UUID(),
    name: String,
    selection: FamilyActivitySelection,
    isDefault: Bool = false
  ) throws {
    self.init(
      id: id,
      name: name,
      selectionData: try JSONEncoder().encode(selection),
      isDefault: isDefault
    )
  }

  func decodedSelection() throws -> FamilyActivitySelection {
    try JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData)
  }
}
