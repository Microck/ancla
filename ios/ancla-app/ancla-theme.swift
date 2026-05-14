import SwiftUI

enum AnclaTheme {
  static let background = Color(red: 0.047, green: 0.055, blue: 0.066)
  static let panel = Color(red: 0.082, green: 0.094, blue: 0.113)
  static let panelRaised = Color(red: 0.102, green: 0.115, blue: 0.137)
  static let panelInteractive = Color(red: 0.090, green: 0.104, blue: 0.124)
  static let panelStroke = Color(red: 0.145, green: 0.161, blue: 0.188)
  static let liveTint = Color(red: 0.835, green: 0.280, blue: 0.270)
  static let liveGlow = Color(red: 0.422, green: 0.080, blue: 0.094)
  static let livePanel = Color(red: 0.132, green: 0.054, blue: 0.062)
  static let livePanelRaised = Color(red: 0.168, green: 0.068, blue: 0.078)
  static let livePanelInteractive = Color(red: 0.152, green: 0.061, blue: 0.072)
  static let livePanelStroke = Color(red: 0.365, green: 0.137, blue: 0.149)
  static let primaryText = Color(red: 0.878, green: 0.902, blue: 0.945)
  static let headerText = Color(red: 0.80, green: 0.812, blue: 0.828)
  static let secondaryText = Color(red: 0.592, green: 0.620, blue: 0.659)
  static let tertiaryText = Color(red: 0.439, green: 0.463, blue: 0.502)
  static let accentFill = Color(red: 0.709, green: 0.764, blue: 0.834)
  static let accentStroke = Color(red: 0.568, green: 0.616, blue: 0.686)
  static let ctaFill = Color(red: 0.82, green: 0.84, blue: 0.86)
  static let ctaText = Color(red: 0.20, green: 0.22, blue: 0.24)
  static let successText = Color(red: 0.698, green: 0.850, blue: 0.760)
  static let warningText = Color(red: 0.933, green: 0.490, blue: 0.467)
  static let errorText = Color(red: 0.90, green: 0.42, blue: 0.42)
}

struct AnclaBackgroundSurface: View {
  let isWarningTinted: Bool

  var body: some View {
    ZStack {
      AnclaTheme.background

      if isWarningTinted {
        LinearGradient(
          colors: [
            AnclaTheme.liveGlow.opacity(0.56),
            AnclaTheme.livePanel.opacity(0.24),
            Color.clear,
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )

        RadialGradient(
          colors: [
            AnclaTheme.liveTint.opacity(0.22),
            Color.clear,
          ],
          center: .bottom,
          startRadius: 18,
          endRadius: 320
        )
        .blur(radius: 12)
      }
    }
  }
}
