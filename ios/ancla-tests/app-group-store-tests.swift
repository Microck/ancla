import FamilyControls
import XCTest

final class AppGroupStoreTests: XCTestCase {
  func testBlockModeRoundTripKeepsName() throws {
    let selection = FamilyActivitySelection()
    let mode = try BlockMode(name: "Work block", selection: selection, isDefault: true)

    XCTAssertEqual(mode.name, "Work block")
    XCTAssertEqual(try mode.decodedSelection(), selection)
  }
}
