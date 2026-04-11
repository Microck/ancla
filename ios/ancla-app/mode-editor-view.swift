import SwiftUI

struct ModeEditorView: View {
  @Bindable var viewModel: AppViewModel
  let isEditingMode: Bool
  let onChooseSelection: () -> Void

  @Environment(\.dismiss) private var dismiss

  private var chromePanelInteractive: Color {
    AnclaTheme.panelInteractive
  }

  private var chromePanelRaised: Color {
    AnclaTheme.panelRaised
  }

  private var chromePanelStroke: Color {
    AnclaTheme.panelStroke
  }

  private var chromeCtaFill: Color {
    AnclaTheme.ctaFill
  }

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
          .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(chromePanelInteractive)
              .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .stroke(chromePanelStroke.opacity(0.75), lineWidth: 1)
              )
          )

          Spacer()

          Text(isEditingMode ? "Edit Mode" : "New Mode")
            .font(.ancla(18, weight: .bold))
            .foregroundStyle(AnclaTheme.primaryText)

          Spacer()

          Button("Save") {
            Task {
              await viewModel.saveMode()
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
              .fill(chromeCtaFill)
          )
          .overlay {
            if viewModel.isActionInProgress(.saveMode) {
              ProgressView()
                .tint(AnclaTheme.ctaText)
            }
          }
          .disabled(viewModel.isBusy || !viewModel.canSaveDraftMode)
          .opacity(viewModel.isBusy || !viewModel.canSaveDraftMode ? 0.55 : 1)
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 0) {
            TextField("", text: $viewModel.draftModeName)
              .textInputAutocapitalization(.words)
              .font(.ancla(28))
              .foregroundStyle(AnclaTheme.primaryText)
              .padding(.top, 48)

            divider
              .padding(.top, 12)

            if viewModel.isSideloadLiteBuild {
              Text("Name the block ready next.")
                .font(.ancla(15))
                .foregroundStyle(AnclaTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 24)
            } else {
              Button {
                onChooseSelection()
              } label: {
                HStack {
                  Image(systemName: "square.grid.2x2")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AnclaTheme.primaryText)

                  Text("Choose apps and sites")
                    .font(.ancla(16))
                    .foregroundStyle(AnclaTheme.primaryText)

                  Spacer()

                  Text(viewModel.selectionSummary(for: viewModel.draftSelection))
                    .font(.ancla(12, weight: .medium))
                    .foregroundStyle(AnclaTheme.secondaryText)
                }
                .padding(.horizontal, 16)
                .frame(height: 54)
              }
              .buttonStyle(AnclaPressableButtonStyle())
              .padding(.top, 24)

              if !viewModel.canSaveDraftMode {
                Text("Choose at least one app, category, or domain.")
                  .font(.ancla(12, weight: .medium))
                  .foregroundStyle(AnclaTheme.warningText)
                  .padding(.top, 10)
              }
            }

            divider
              .padding(.top, 24)

            HStack(alignment: .center) {
              VStack(alignment: .leading, spacing: 6) {
                Text("Set as primary")
                  .font(.ancla(16))
                  .foregroundStyle(AnclaTheme.primaryText)

                Text("Prioritize this mode globally")
                  .font(.ancla(12))
                  .foregroundStyle(AnclaTheme.tertiaryText)
              }

              Spacer()

              Toggle("", isOn: $viewModel.draftModeShouldBeDefault)
                .labelsHidden()
                .tint(AnclaTheme.ctaFill)
            }
            .padding(.top, 40)

            divider
              .padding(.top, 14)

            if let lastError = viewModel.lastError {
              Text(lastError)
                .font(.ancla(12, weight: .medium))
                .foregroundStyle(AnclaTheme.errorText)
                .padding(.top, 18)
            } else if let feedback = viewModel.feedback, feedback.tone == .success {
              Text(feedback.message)
                .font(.ancla(12, weight: .medium))
                .foregroundStyle(AnclaTheme.successText)
                .padding(.top, 18)
            }

            Spacer(minLength: 12)
          }
          .padding(.horizontal, 32)
          .padding(.bottom, 36)
        }
      }
    }
    .preferredColorScheme(.dark)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.hidden)
  }

  private var divider: some View {
    Rectangle()
      .fill(AnclaTheme.panelStroke.opacity(0.6))
      .frame(height: 1)
  }
}
