import SwiftUI

extension Font {
  static func ancla(_ size: CGFloat, weight: Weight = .regular) -> Font {
    let postScriptName: String
    if weight == .semibold {
      postScriptName = "GoogleSansFlex-SemiBold"
    } else if weight == .bold || weight == .heavy || weight == .black {
      postScriptName = "GoogleSansFlex-Bold"
    } else if weight == .medium {
      postScriptName = "GoogleSansFlex-Medium"
    } else {
      postScriptName = "GoogleSansFlex-Regular"
    }

    return .custom(postScriptName, size: size)
  }

  static func anclaMono(_ size: CGFloat, weight: Weight = .regular) -> Font {
    .custom("GoogleSansFlex-Regular", size: size)
  }
}
