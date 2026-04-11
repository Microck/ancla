import SwiftUI

struct ShortcutSetupReferenceView: View {
  let showsCompletionState: Bool
  let isComplete: Bool
  let onConfirm: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 8) {
        Text("One automation")
          .font(.ancla(28, weight: .semibold))
          .foregroundStyle(AnclaTheme.primaryText)

        Text("Include every app you want blocked.")
          .font(.ancla(14))
          .foregroundStyle(AnclaTheme.secondaryText)
      }

      Image("shortcut-automation-reference")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
        }

      VStack(alignment: .leading, spacing: 10) {
        shortcutStep("App", "Is Opened", "Run Immediately")
        shortcutStep("Pick every blocked app")
        shortcutStep("Add Get Block Status")
        shortcutStep("If true", "Open App", "Ancla")
      }

      if showsCompletionState {
        if isComplete {
          statusRow("Marked done")
        } else if let onConfirm {
          Button(action: onConfirm) {
            Text("I've set this up")
              .font(.ancla(15, weight: .semibold))
              .foregroundStyle(AnclaTheme.ctaText)
              .frame(maxWidth: .infinity)
              .frame(height: 52)
              .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .fill(AnclaTheme.ctaFill)
              )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func shortcutStep(_ pieces: String...) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Circle()
        .fill(AnclaTheme.accentFill)
        .frame(width: 7, height: 7)
        .padding(.top, 7)

      Text(pieces.joined(separator: "  •  "))
        .font(.ancla(13, weight: .medium))
        .foregroundStyle(AnclaTheme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func statusRow(_ title: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(AnclaTheme.successText)

      Text(title)
        .font(.ancla(13, weight: .medium))
        .foregroundStyle(AnclaTheme.successText)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(AnclaTheme.panelInteractive)
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(AnclaTheme.panelStroke.opacity(0.7), lineWidth: 1)
        )
    )
  }
}
