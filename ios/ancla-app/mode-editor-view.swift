import SwiftUI

struct ModeEditorView: View {
  @Bindable var viewModel: AppViewModel
  let isEditingMode: Bool
  let onChooseSelection: () -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var isShortcutGuidesPresented = false

  private var isWarningThemeActive: Bool {
    viewModel.activeSessionIsBlocking
  }

  private var chromePanelInteractive: Color {
    isWarningThemeActive ? AnclaTheme.livePanelInteractive : AnclaTheme.panelInteractive
  }

  private var chromePanelRaised: Color {
    isWarningThemeActive ? AnclaTheme.livePanelRaised : AnclaTheme.panelRaised
  }

  private var chromePanelStroke: Color {
    isWarningThemeActive ? AnclaTheme.livePanelStroke : AnclaTheme.panelStroke
  }

  private var chromeCtaFill: Color {
    isWarningThemeActive ? AnclaTheme.liveTint : AnclaTheme.ctaFill
  }

  var body: some View {
    ZStack(alignment: .top) {
      AnclaBackgroundSurface(isWarningTinted: isWarningThemeActive)
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
              sectionLabel("RELEASE")
                .padding(.top, 60)

              Text("This mode uses the paired anchor and keeps its session state on this iPhone. Turn on strict mode if you want the harder-to-bypass version of this ritual.")
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

            strictModePanel
              .padding(.top, 40)

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
            .padding(.horizontal, 16)
            .frame(minHeight: 68)
            .background(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(chromePanelInteractive)
                .overlay(
                  RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(chromePanelStroke.opacity(0.75), lineWidth: 1)
                )
            )
            .padding(.top, 64)

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
    .sheet(isPresented: $isShortcutGuidesPresented) {
      ShortcutGuidesSheet()
        .presentationBackground(.clear)
    }
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

  private var strictModePanel: some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionLabel("STRICT MODE")

      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .center) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Use stricter mode copy")
              .font(.ancla(16))
              .foregroundStyle(AnclaTheme.primaryText)

            Text("Highlight the stricter version of this mode and surface the Apple app shortcut guides that close easy loopholes.")
              .font(.ancla(12))
              .foregroundStyle(AnclaTheme.tertiaryText)
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          Spacer()

          Toggle("", isOn: $viewModel.draftModeIsStrict)
            .labelsHidden()
            .tint(AnclaTheme.ctaFill)
        }

        if viewModel.draftModeIsStrict {
          Text("Native Apple apps still need Shortcuts automations because iOS does not let Ancla hard-block every built-in app directly.")
            .font(.ancla(13))
            .foregroundStyle(AnclaTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)

          Button {
            isShortcutGuidesPresented = true
          } label: {
            HStack {
              Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnclaTheme.primaryText)

              Text("Review Apple app shortcut guides")
                .font(.ancla(15, weight: .medium))
                .foregroundStyle(AnclaTheme.primaryText)

              Spacer()

              Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AnclaTheme.tertiaryText)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
          }
          .buttonStyle(AnclaPressableButtonStyle())
        }
      }
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(chromePanelInteractive)
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(chromePanelStroke.opacity(0.75), lineWidth: 1)
          )
      )
    }
  }
}
