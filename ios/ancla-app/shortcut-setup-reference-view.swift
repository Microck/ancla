import SwiftUI

struct ShortcutSetupReferenceView: View {
  let showsCompletionState: Bool
  let isComplete: Bool
  let onConfirm: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Shortcut")
        .font(.ancla(30, weight: .semibold))
        .foregroundStyle(AnclaTheme.primaryText)

      Image("shortcut-automation-reference")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
        }

      VStack(alignment: .leading, spacing: 0) {
        shortcutStep(
          number: 1,
          text: "Tap \"+\" on the top right of the Automation screen."
        )
        shortcutStep(
          number: 2,
          text: "Select \"App\" under Personal Automation."
        )
        shortcutStep(
          number: 3,
          text: "Choose \"Is Opened\". Choose \"Run Immediately\". Toggle off \"Notify When Run\"."
        )
        shortcutStep(
          number: 4,
          text: "Add action \"Get Block Status\". Add action \"If Get Block Status\". Add action \"Open Anchor\" inside If block. Add Else block. Add End If."
        )
      }

      Text("This creates iOS shortcut automation conditionally opening Anchor app based on block status.")
        .font(.ancla(13))
        .foregroundStyle(AnclaTheme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)

      if showsCompletionState {
        if isComplete {
          statusRow("Marked done")
        } else if let onConfirm {
          Button(action: onConfirm) {
            HStack {
              Text("I've set this up")
                .font(.ancla(15, weight: .semibold))
                .foregroundStyle(AnclaTheme.primaryText)

              Spacer()

              Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AnclaTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
              Rectangle()
                .fill(AnclaTheme.panelStroke.opacity(0.6))
                .frame(height: 1)
            }
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func shortcutStep(number: Int, text: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Text("\(number).")
        .font(.anclaMono(12, weight: .semibold))
        .foregroundStyle(AnclaTheme.primaryText)
        .frame(width: 20, alignment: .leading)

      Text(text)
        .font(.ancla(14, weight: .medium))
        .foregroundStyle(AnclaTheme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 12)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(AnclaTheme.panelStroke.opacity(0.45))
        .frame(height: 1)
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
    .padding(.vertical, 10)
  }
}
