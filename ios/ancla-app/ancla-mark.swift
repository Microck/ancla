import SwiftUI

struct AnclaMark: View {
  var color: Color = AnclaTheme.headerText
  var size: CGFloat = 18

  var body: some View {
    ZStack {
      Circle()
        .stroke(color, lineWidth: size * 0.085)
        .frame(width: size * 0.27, height: size * 0.27)
        .offset(y: -size * 0.33)

      Capsule(style: .continuous)
        .fill(color)
        .frame(width: size * 0.1, height: size * 0.62)
        .offset(y: size * 0.02)

      Capsule(style: .continuous)
        .fill(color)
        .frame(width: size * 0.5, height: size * 0.085)
        .offset(y: -size * 0.08)

      AnchorFlukes()
        .fill(color)
        .frame(width: size * 0.72, height: size * 0.4)
        .offset(y: size * 0.22)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

private struct AnchorFlukes: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()

    path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.addCurve(
      to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.height * 0.42),
      control1: CGPoint(x: rect.midX - rect.width * 0.04, y: rect.maxY - rect.height * 0.1),
      control2: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY)
    )
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.width * 0.28, y: rect.height * 0.16))
    path.addCurve(
      to: CGPoint(x: rect.midX, y: rect.maxY),
      control1: CGPoint(x: rect.width * 0.33, y: rect.maxY - rect.height * 0.06),
      control2: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.maxY - rect.height * 0.02)
    )

    path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.addCurve(
      to: CGPoint(x: rect.maxX - rect.width * 0.14, y: rect.height * 0.42),
      control1: CGPoint(x: rect.midX + rect.width * 0.04, y: rect.maxY - rect.height * 0.1),
      control2: CGPoint(x: rect.maxX - rect.width * 0.3, y: rect.maxY)
    )
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.width * 0.72, y: rect.height * 0.16))
    path.addCurve(
      to: CGPoint(x: rect.midX, y: rect.maxY),
      control1: CGPoint(x: rect.width * 0.67, y: rect.maxY - rect.height * 0.06),
      control2: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.maxY - rect.height * 0.02)
    )

    return path
  }
}
