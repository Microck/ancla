import SwiftUI

private enum SetupSection: String, CaseIterable, Identifiable {
  case shortcut
  case anchor
  case mode

  var id: String { rawValue }

  var title: String {
    switch self {
    case .shortcut:
      return "Shortcut"
    case .anchor:
      return "Anchor"
    case .mode:
      return "Mode"
    }
  }
}

struct SetupFlowView: View {
  @Bindable var viewModel: AppViewModel
  let showsDismissButton: Bool
  let onDismiss: (() -> Void)?
  let onPairAnchor: () -> Void
  let onCreateMode: () -> Void

  @State private var selectedSection: SetupSection = .shortcut

  var body: some View {
    ZStack {
      AnclaBackgroundSurface(isWarningTinted: false)
        .ignoresSafeArea()

      VStack(spacing: 0) {
        topBar
        setupTabs

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 24) {
            progressRow
            sectionContent
          }
          .padding(.horizontal, 24)
          .padding(.top, 24)
          .padding(.bottom, 36)
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  private var topBar: some View {
    HStack {
      if showsDismissButton {
        Button("Done") {
          onDismiss?()
        }
        .font(.ancla(14, weight: .medium))
        .foregroundStyle(AnclaTheme.secondaryText)
      } else {
        Color.clear
          .frame(width: 42, height: 18)
      }

      Spacer()

      VStack(spacing: 4) {
        Text("Finish setup")
          .font(.ancla(22, weight: .semibold))
          .foregroundStyle(AnclaTheme.primaryText)

        Text("Do this once.")
          .font(.ancla(12))
          .foregroundStyle(AnclaTheme.tertiaryText)
      }

      Spacer()

      Color.clear
        .frame(width: 42, height: 18)
    }
    .padding(.horizontal, 24)
    .padding(.top, 20)
    .padding(.bottom, 16)
  }

  private var setupTabs: some View {
    HStack(spacing: 10) {
      ForEach(SetupSection.allCases) { section in
        Button {
          selectedSection = section
        } label: {
          HStack(spacing: 8) {
            Circle()
              .fill(isSectionComplete(section) ? AnclaTheme.successText : Color.white.opacity(0.18))
              .frame(width: 8, height: 8)

            Text(section.title)
              .font(.ancla(13, weight: .medium))
              .foregroundStyle(selectedSection == section ? AnclaTheme.primaryText : AnclaTheme.secondaryText)
          }
          .frame(maxWidth: .infinity)
          .frame(height: 42)
          .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .fill(selectedSection == section ? AnclaTheme.panelRaised : AnclaTheme.panelInteractive)
              .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
              )
          )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 24)
  }

  private var progressRow: some View {
    HStack(spacing: 10) {
      Text("\(completedCount) / 3 ready")
        .font(.ancla(13, weight: .medium))
        .foregroundStyle(AnclaTheme.primaryText)

      Spacer()

      if viewModel.hasCompletedRequiredSetup {
        Text("All set")
          .font(.ancla(12, weight: .medium))
          .foregroundStyle(AnclaTheme.successText)
      }
    }
  }

  @ViewBuilder
  private var sectionContent: some View {
    switch selectedSection {
    case .shortcut:
      shortcutContent
    case .anchor:
      anchorContent
    case .mode:
      modeContent
    }
  }

  private var shortcutContent: some View {
    VStack(alignment: .leading, spacing: 18) {
      ShortcutSetupReferenceView(
        showsCompletionState: true,
        isComplete: viewModel.hasCompletedShortcutSetup,
        onConfirm: {
          Task { await viewModel.confirmShortcutSetup() }
        }
      )
    }
  }

  private var anchorContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      setupStatusCard(
        title: viewModel.hasCompletedAnchorSetup ? "\(viewModel.pairedTagsForDisplay.count) paired" : "No anchor yet",
        detail: viewModel.hasCompletedAnchorSetup
          ? viewModel.pairedTagsForDisplay.map(\.displayName).joined(separator: " • ")
          : "Pair one NFC anchor."
      )

      Button(action: onPairAnchor) {
        setupActionRow(
          icon: "dot.radiowaves.left.and.right",
          title: viewModel.hasCompletedAnchorSetup ? "Pair another anchor" : "Pair anchor",
          detail: "Scan it on this iPhone."
        )
      }
      .buttonStyle(.plain)
      .disabled(viewModel.isBusy)
      .opacity(viewModel.isBusy ? 0.6 : 1)
    }
  }

  private var modeContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      setupStatusCard(
        title: viewModel.hasCompletedModeSetup ? "\(viewModel.modesForDisplay.count) ready" : "No mode yet",
        detail: viewModel.hasCompletedModeSetup
          ? viewModel.modesForDisplay.map(\.name).joined(separator: " • ")
          : "Save one mode."
      )

      Button(action: onCreateMode) {
        setupActionRow(
          icon: "plus",
          title: viewModel.hasCompletedModeSetup ? "Add mode" : "Create mode",
          detail: "Pick the block you want ready next."
        )
      }
      .buttonStyle(.plain)
      .disabled(viewModel.isBusy)
      .opacity(viewModel.isBusy ? 0.6 : 1)
    }
  }

  private func setupStatusCard(title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.ancla(20, weight: .semibold))
        .foregroundStyle(AnclaTheme.primaryText)

      Text(detail)
        .font(.ancla(13))
        .foregroundStyle(AnclaTheme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
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

  private func setupActionRow(icon: String, title: String, detail: String) -> some View {
    HStack(spacing: 14) {
      ZStack {
        Circle()
          .fill(AnclaTheme.accentFill.opacity(0.14))
          .frame(width: 38, height: 38)

        Image(systemName: icon)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(AnclaTheme.accentFill)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.ancla(15, weight: .medium))
          .foregroundStyle(AnclaTheme.primaryText)

        Text(detail)
          .font(.ancla(12))
          .foregroundStyle(AnclaTheme.secondaryText)
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(AnclaTheme.tertiaryText)
    }
    .padding(18)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(AnclaTheme.panelInteractive)
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(AnclaTheme.panelStroke.opacity(0.7), lineWidth: 1)
        )
    )
  }

  private func isSectionComplete(_ section: SetupSection) -> Bool {
    switch section {
    case .shortcut:
      return viewModel.hasCompletedShortcutSetup
    case .anchor:
      return viewModel.hasCompletedAnchorSetup
    case .mode:
      return viewModel.hasCompletedModeSetup
    }
  }

  private var completedCount: Int {
    SetupSection.allCases.filter(isSectionComplete).count
  }
}
