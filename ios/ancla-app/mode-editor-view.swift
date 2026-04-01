import SwiftUI

struct ModeEditorView: View {
  @Bindable var viewModel: AppViewModel
  let isEditingMode: Bool
  let onChooseSelection: () -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack(alignment: .top) {
      AnclaTheme.background
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
          .font(.ancla(16))
          .foregroundStyle(AnclaTheme.secondaryText)

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
          .font(.ancla(16, weight: .semibold))
          .foregroundStyle(AnclaTheme.primaryText)
          .disabled(viewModel.isBusy || !viewModel.canSaveDraftMode)
          .opacity(viewModel.isBusy || !viewModel.canSaveDraftMode ? 0.55 : 1)
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 0) {
            sectionLabel("IDENTITY")
              .padding(.top, 48)

            TextField("", text: $viewModel.draftModeName)
              .textInputAutocapitalization(.words)
              .font(.ancla(28))
              .foregroundStyle(AnclaTheme.primaryText)
              .padding(.top, 30)

            divider
              .padding(.top, 12)

            if viewModel.isSideloadLiteBuild {
              sectionLabel("INTENT")
                .padding(.top, 60)

              Text("Aggressive notification suppression. High-priority hardware ritualism enabled.")
                .font(.ancla(16))
                .foregroundStyle(AnclaTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 26)
            } else {
              sectionLabel("TARGETS")
                .padding(.top, 60)

              Button {
                onChooseSelection()
              } label: {
                HStack {
                  Text("Choose apps and sites")
                    .font(.ancla(16))
                    .foregroundStyle(AnclaTheme.primaryText)

                  Spacer()

                  Text(viewModel.selectionSummary(for: viewModel.draftSelection))
                    .font(.ancla(12, weight: .medium))
                    .foregroundStyle(AnclaTheme.secondaryText)
                }
              }
              .buttonStyle(.plain)
              .padding(.top, 26)

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
                Text("Set as Primary")
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
            .padding(.top, 64)

            HStack(spacing: 14) {
              Rectangle()
                .fill(AnclaTheme.panelStroke.opacity(0.4))
                .frame(height: 1)

              AnclaMark(color: AnclaTheme.tertiaryText.opacity(0.8), size: 10)
                .opacity(0.55)

              Rectangle()
                .fill(AnclaTheme.panelStroke.opacity(0.4))
                .frame(height: 1)
            }
            .padding(.top, 60)
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

  private func sectionLabel(_ title: String) -> some View {
    Text(title)
      .font(.ancla(10, weight: .semibold))
      .tracking(2)
      .foregroundStyle(AnclaTheme.tertiaryText)
  }

  private var divider: some View {
    Rectangle()
      .fill(AnclaTheme.panelStroke.opacity(0.6))
      .frame(height: 1)
  }
}
