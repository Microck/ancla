import SwiftUI

struct AnclaPressableButtonStyle: ButtonStyle {
  var background: Color = AnclaTheme.panelInteractive
  var pressedBackground: Color = AnclaTheme.panelRaised
  var stroke: Color = AnclaTheme.panelStroke.opacity(0.75)
  var cornerRadius: CGFloat = 18
  var scale: CGFloat = 0.988

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(configuration.isPressed ? pressedBackground : background)
          .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              .stroke(stroke, lineWidth: 1)
          )
      )
      .scaleEffect(configuration.isPressed ? scale : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
