import SwiftUI

struct AnclaMark: View {
  var color: Color = AnclaTheme.headerText
  var size: CGFloat = 18

  var body: some View {
    Image("brand-mark")
      .renderingMode(.template)
      .resizable()
      .scaledToFit()
      .foregroundStyle(color)
      .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}
