import SwiftUI

struct StartupSplashView: View {
  var body: some View {
    ZStack {
      AnclaBackgroundSurface(isWarningTinted: false)
        .ignoresSafeArea()

      VStack(spacing: 22) {
        ZStack {
          Circle()
            .fill(AnclaTheme.panelRaised)
            .frame(width: 108, height: 108)
            .overlay(
              Circle()
                .stroke(AnclaTheme.panelStroke.opacity(0.78), lineWidth: 1)
            )

          AnclaMark(color: AnclaTheme.primaryText, size: 56)
        }

        Text("Ancla")
          .font(.ancla(34, weight: .semibold))
          .foregroundStyle(AnclaTheme.primaryText)
      }
      .padding(.bottom, 18)
    }
    .allowsHitTesting(false)
    .preferredColorScheme(.dark)
  }
}
