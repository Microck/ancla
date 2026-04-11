import SwiftUI

struct ShortcutGuidesSheet: View {
  @Environment(\.dismiss) private var dismiss
  private let guide = NativeAppleShortcutGuides.guide

  var body: some View {
    NavigationStack {
      ZStack {
        AnclaTheme.background
          .ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 20) {
            hero
            guideCard(guide)
          }
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

  private var hero: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Use one automation for every app you want Ancla to gate.")
        .font(.ancla(30, weight: .medium))
        .foregroundStyle(AnclaTheme.primaryText)

      Text("iOS still will not let Ancla hard-block those apps directly. The practical workaround is one personal automation that includes the full app list and only redirects into Ancla while a block is active.")
        .font(.ancla(14))
        .foregroundStyle(AnclaTheme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func guideCard(_ guide: NativeAppleShortcutGuide) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Text(guide.title)
          .font(.ancla(18, weight: .semibold))
          .foregroundStyle(AnclaTheme.primaryText)

        Text(guide.summary)
          .font(.ancla(13))
          .foregroundStyle(AnclaTheme.secondaryText)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      VStack(alignment: .leading, spacing: 10) {
        ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
          HStack(alignment: .top, spacing: 10) {
            Text("\(index + 1)")
              .font(.anclaMono(11))
              .foregroundStyle(AnclaTheme.primaryText)
              .frame(width: 18, alignment: .leading)

            Text(step)
              .font(.ancla(13))
              .foregroundStyle(AnclaTheme.secondaryText)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
      .padding(14)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(AnclaTheme.panelInteractive)
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(AnclaTheme.panelStroke.opacity(0.7), lineWidth: 1)
          )
      )

      VStack(alignment: .leading, spacing: 10) {
        Text("Common apps to add")
          .font(.ancla(12, weight: .semibold))
          .foregroundStyle(AnclaTheme.tertiaryText)

        Text(guide.suggestedApps.joined(separator: " • "))
          .font(.ancla(13))
          .foregroundStyle(AnclaTheme.secondaryText)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(14)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(AnclaTheme.panelInteractive)
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(AnclaTheme.panelStroke.opacity(0.7), lineWidth: 1)
          )
      )
    }
    .padding(18)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(AnclaTheme.panel)
        .overlay(
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(AnclaTheme.panelStroke.opacity(0.8), lineWidth: 1)
        )
    )
  }
}
