import SwiftUI

struct UnlockPresetEditorView: View {
  @Bindable var viewModel: AppViewModel
  let isEditingPreset: Bool

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack(alignment: .top) {
      AnclaBackgroundSurface(isWarningTinted: false)
        .ignoresSafeArea()

      VStack(spacing: 0) {
        Capsule(style: .continuous)
          .fill(AnclaTheme.tertiaryText.opacity(0.7))
          .frame(width: 40, height: 4)
          .padding(.top, 16)

        HStack {
          Button("Cancel") {
            dismiss()
          }
          .font(.ancla(14, weight: .medium))
          .foregroundStyle(AnclaTheme.secondaryText)
          .padding(.horizontal, 14)
          .frame(height: 38)
          .background(buttonBackground)

          Spacer()

          Text(isEditingPreset ? "Edit Preset" : "New Preset")
            .font(.ancla(18, weight: .bold))
            .foregroundStyle(AnclaTheme.primaryText)

          Spacer()

          Button("Save") {
            Task {
              await viewModel.saveUnlockPreset()
              if viewModel.lastError == nil {
                dismiss()
              }
            }
          }
          .font(.ancla(14, weight: .semibold))
          .foregroundStyle(AnclaTheme.ctaText)
          .padding(.horizontal, 14)
          .frame(height: 38)
          .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(AnclaTheme.ctaFill)
          )
          .overlay {
            if viewModel.isActionInProgress(.savePreset) {
              ProgressView()
                .tint(AnclaTheme.ctaText)
            }
          }
          .disabled(viewModel.isBusy)
          .opacity(viewModel.isBusy ? 0.55 : 1)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 28) {
            editorField(
              title: "Preset name",
              prompt: "Check 2FA",
              text: $viewModel.draftPresetTitle
            )

            editorField(
              title: "What this is for",
              prompt: "Open Messages long enough to read a code.",
              text: $viewModel.draftPresetDetail,
              axis: .vertical
            )

            VStack(alignment: .leading, spacing: 14) {
              Text("Duration")
                .font(.ancla(11, weight: .medium))
                .foregroundStyle(AnclaTheme.tertiaryText)

              HStack(spacing: 12) {
                durationButton(symbol: "minus", action: {
                  viewModel.draftPresetDurationSeconds = max(5, viewModel.draftPresetDurationSeconds - 5)
                })

                Text("\(viewModel.draftPresetDurationSeconds)s")
                  .font(.ancla(28, weight: .medium))
                  .foregroundStyle(AnclaTheme.primaryText)
                  .frame(minWidth: 88)

                durationButton(symbol: "plus", action: {
                  viewModel.draftPresetDurationSeconds = min(300, viewModel.draftPresetDurationSeconds + 5)
                })
              }
            }

            VStack(alignment: .leading, spacing: 10) {
              Text("Preview")
                .font(.ancla(11, weight: .medium))
                .foregroundStyle(AnclaTheme.tertiaryText)

              HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                  Text(viewModel.draftPresetTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Check 2FA" : viewModel.draftPresetTitle)
                    .font(.ancla(16, weight: .medium))
                    .foregroundStyle(AnclaTheme.primaryText)

                  Text(viewModel.draftPresetDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Temporary access." : viewModel.draftPresetDetail)
                    .font(.ancla(12))
                    .foregroundStyle(AnclaTheme.secondaryText)
                }

                Spacer()

                Text("\(viewModel.draftPresetDurationSeconds)s")
                  .font(.ancla(12, weight: .medium))
                  .foregroundStyle(AnclaTheme.secondaryText)
              }
              .padding(16)
              .background(cardBackground)
            }

            if let lastError = viewModel.lastError {
              Text(lastError)
                .font(.ancla(12, weight: .medium))
                .foregroundStyle(AnclaTheme.errorText)
            }
          }
          .padding(.horizontal, 28)
          .padding(.top, 36)
          .padding(.bottom, 36)
        }
      }
    }
    .preferredColorScheme(.dark)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.hidden)
  }

  private var buttonBackground: some View {
    RoundedRectangle(cornerRadius: 14, style: .continuous)
      .fill(AnclaTheme.panelInteractive)
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
      )
  }

  private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 18, style: .continuous)
      .fill(AnclaTheme.panelInteractive)
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
      )
  }

  private func editorField(
    title: String,
    prompt: String,
    text: Binding<String>,
    axis: Axis = .horizontal
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.ancla(11, weight: .medium))
        .foregroundStyle(AnclaTheme.tertiaryText)

      TextField(prompt, text: text, axis: axis)
        .font(.ancla(axis == .horizontal ? 28 : 16))
        .foregroundStyle(AnclaTheme.primaryText)
        .lineLimit(axis == .vertical ? 3...5 : 1)

      Rectangle()
        .fill(AnclaTheme.panelStroke.opacity(0.6))
        .frame(height: 1)
    }
  }

  private func durationButton(symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(AnclaTheme.primaryText)
        .frame(width: 42, height: 42)
        .background(
          Circle()
            .fill(AnclaTheme.panelInteractive)
            .overlay(
              Circle()
                .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
            )
        )
    }
    .buttonStyle(.plain)
  }
}
