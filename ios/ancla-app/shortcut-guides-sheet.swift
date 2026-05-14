import SwiftUI

struct ShortcutGuidesSheet: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ZStack {
        AnclaTheme.background
          .ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          ShortcutSetupReferenceView(
            showsCompletionState: false,
            isComplete: false,
            onConfirm: nil
          )
          .padding(.horizontal, 24)
          .padding(.top, 24)
          .padding(.bottom, 36)
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Done") {
            dismiss()
          }
          .font(.ancla(14, weight: .medium))
          .foregroundStyle(AnclaTheme.secondaryText)
        }
      }
      .toolbar(.hidden, for: .navigationBar)
      .safeAreaInset(edge: .top, spacing: 0) {
        HStack {
          Button("Done") {
            dismiss()
          }
          .font(.ancla(14, weight: .medium))
          .foregroundStyle(AnclaTheme.secondaryText)

          Spacer()

          Text("Shortcut setup")
            .font(.ancla(18, weight: .bold))
            .foregroundStyle(AnclaTheme.primaryText)

          Spacer()

          Color.clear
            .frame(width: 42, height: 18)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(AnclaTheme.background)
      }
      .preferredColorScheme(.dark)
    }
  }
}
