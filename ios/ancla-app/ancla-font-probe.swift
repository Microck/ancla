import UIKit

enum AnclaFontProbe {
  private static let expectedFiles = [
    "google-sans-flex-400.ttf",
    "google-sans-flex-500.ttf",
    "google-sans-flex-600.ttf",
    "google-sans-flex-700.ttf",
  ]

  private static let expectedPostScriptNames = [
    "GoogleSansFlex-Regular",
    "GoogleSansFlex-Medium",
    "GoogleSansFlex-SemiBold",
    "GoogleSansFlex-Bold",
  ]

  static var diagnosticItem: RuntimeDiagnosticItem {
    let missingFiles = expectedFiles.filter { fileName in
      let parts = fileName.split(separator: ".", maxSplits: 1).map(String.init)
      guard parts.count == 2 else {
        return true
      }
      return Bundle.main.url(forResource: parts[0], withExtension: parts[1]) == nil
    }

    let registeredNames = expectedPostScriptNames.filter { postScriptName in
      UIFont(name: postScriptName, size: 17) != nil
    }

    let value: String
    let detail: String
    let tone: RuntimeDiagnosticTone

    if registeredNames.count == expectedPostScriptNames.count {
      value = "Google Sans Flex"
      detail = "Regular, Medium, SemiBold, and Bold resolved from the app bundle."
      tone = .ready
    } else if !missingFiles.isEmpty {
      value = "Fallback active"
      detail = "The app bundle is missing \(missingFiles.count) expected Google Sans Flex font file" + (missingFiles.count == 1 ? "." : "s.")
      tone = .blocked
    } else {
      value = "Fallback active"
      detail = "The font files exist, but iOS did not register the expected Google Sans Flex names."
      tone = .attention
    }

    return RuntimeDiagnosticItem(
      id: "font",
      title: "Typography",
      value: value,
      detail: detail,
      tone: tone
    )
  }
}
