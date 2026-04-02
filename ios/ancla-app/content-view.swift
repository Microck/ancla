#if !SIDELOAD_LITE
import FamilyControls
#endif
import SwiftUI

private enum NextStep {
  case authorize
  case pairAnchor
  case createMode
  case release
  case arm
  case rearm
}

struct ContentView: View {
  @Bindable var viewModel: AppViewModel

  @State private var isModeEditorPresented = false
  @State private var isRenamingAnchor = false
  @State private var anchorNameDraft = ""

  var body: some View {
    NavigationStack {
      ZStack {
        AnclaTheme.background
          .ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 24) {
            header
            headlineSection
            sessionSurface
            modeSurface
            anchorSurface
            systemSurface

            if let lastError = viewModel.lastError, !lastError.isEmpty {
              errorSection(lastError)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 24)
          .padding(.top, 24)
          .padding(.bottom, 24)
        }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        bottomActionBar
      }
      .toolbar(.hidden, for: .navigationBar)
      .preferredColorScheme(.dark)
      .sheet(isPresented: $isModeEditorPresented) {
        ModeEditorView(
          viewModel: viewModel,
          isEditingMode: viewModel.draftModeID != nil,
          onChooseSelection: { viewModel.isPickerPresented = true }
        )
        .presentationBackground(.clear)
      }
      .sheet(isPresented: $isRenamingAnchor) {
        renameAnchorSheet
          .presentationBackground(.clear)
      }
      .anclaFamilyActivityPicker(
        isPresented: $viewModel.isPickerPresented,
        selection: $viewModel.draftSelection
      )
      .task {
        viewModel.refreshDiagnostics()
      }
      .onChange(of: isRenamingAnchor) { _, isOpen in
        if isOpen {
          anchorNameDraft = viewModel.snapshot.pairedTag?.displayName ?? ""
        }
      }
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 12) {
      HStack(spacing: 10) {
        AnclaMark(color: AnclaTheme.primaryText, size: 20)

        Text("Ancla")
          .font(.ancla(18, weight: .semibold))
          .foregroundStyle(AnclaTheme.primaryText)
      }

      Spacer()

      Button {
        viewModel.refreshDiagnostics()
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 12, weight: .semibold))

          Text("Refresh")
            .font(.ancla(12, weight: .medium))
        }
        .foregroundStyle(AnclaTheme.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
          Capsule(style: .continuous)
            .fill(AnclaTheme.panelRaised)
            .overlay(
              Capsule(style: .continuous)
                .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
            )
        )
      }
      .buttonStyle(.plain)
    }
  }

  private var headlineSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(viewModel.diagnostics.headline)
        .font(.ancla(40, weight: .medium))
        .foregroundStyle(AnclaTheme.primaryText)

      Text(viewModel.diagnostics.message)
        .font(.ancla(15))
        .foregroundStyle(AnclaTheme.secondaryText)
        .frame(maxWidth: 340, alignment: .leading)
    }
  }

  private var sessionSurface: some View {
    surface(title: "Overview") {
      VStack(spacing: 16) {
        surfaceRow(
          label: "Current mode",
          value: currentMode?.name ?? "None",
          detail: currentModeDetail
        )

        surfaceDivider

        surfaceRow(
          label: "Anchor",
          value: viewModel.snapshot.pairedTag?.displayName ?? "Not paired",
          detail: anchorDetail
        )

        if viewModel.snapshot.pairedTag != nil {
          surfaceDivider

          surfaceRow(
            label: "Anchor ID",
            value: fingerprintValue,
            detail: "Short preview of the paired anchor fingerprint.",
            monospaced: true
          )
        }

        surfaceDivider

        surfaceRow(
          label: "Session",
          value: sessionValue,
          detail: sessionDetail,
          accentColor: sessionAccent
        )
      }
    }
  }

  private var modeSurface: some View {
    surface(title: "Modes") {
      VStack(spacing: 12) {
        if viewModel.modesForDisplay.isEmpty {
          informativeRow(
            title: "No modes saved",
            detail: "Create the first mode you want ready before starting a session.",
            accentColor: AnclaTheme.primaryText,
            highlight: false,
            trailingSymbol: "plus"
          )
        } else {
          ForEach(viewModel.modesForDisplay) { mode in
            Button {
              viewModel.selectMode(mode.id)
            } label: {
              modeRow(mode)
            }
            .buttonStyle(.plain)
          }
        }

        Menu {
          if let currentMode {
            Button("Edit selected mode") {
              viewModel.prepareDraftForEditingMode(currentMode.id)
              isModeEditorPresented = true
            }
          }

          Button("Create mode") {
            viewModel.prepareDraftForNewMode()
            isModeEditorPresented = true
          }
        } label: {
          interactiveRow(
            title: "Manage modes",
            detail: "Create a new mode or update the selected one."
          )
        }
      }
    }
  }

  private var anchorSurface: some View {
    surface(title: "Anchor") {
      VStack(spacing: 12) {
        if let pairedTag = viewModel.snapshot.pairedTag {
          informativeRow(
            title: pairedTag.displayName,
            detail: "This anchor is currently paired to release active sessions on this iPhone.",
            accentColor: AnclaTheme.primaryText,
            highlight: true,
            trailingText: "Paired"
          )

          Menu {
            Button("Rename anchor") {
              isRenamingAnchor = true
            }

            Button("Pair replacement anchor") {
              Task { await viewModel.pairSticker() }
            }

            Button("Remove anchor", role: .destructive) {
              Task { await viewModel.unpairSticker() }
            }
          } label: {
            interactiveRow(
              title: "Manage anchor",
              detail: "Rename, replace, or remove the paired anchor."
            )
          }
        } else if let anchorTagURL {
          informativeRow(
            title: "No anchor paired",
            detail: "Pair one NFC anchor to set the physical release key for this iPhone.",
            accentColor: AnclaTheme.primaryText,
            highlight: false
          )

          Link(destination: anchorTagURL) {
            interactiveRow(
              title: "Compatible NFC tags",
              detail: "Purchase a compatible NFC adhesive tag for pairing."
            )
          }
        }
      }
    }
  }

  private var systemSurface: some View {
    surface(title: "Device status") {
      VStack(spacing: 16) {
        ForEach(systemItems.indices, id: \.self) { index in
          let item = systemItems[index]

          VStack(spacing: 0) {
            surfaceRow(
              label: item.title,
              value: item.value,
              detail: item.detail,
              accentColor: toneColor(item.tone)
            )

            if index < systemItems.count - 1 {
              surfaceDivider
                .padding(.top, 16)
            }
          }
        }
      }
    }
  }

  private func surface<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(title)
        .font(.ancla(12, weight: .medium))
        .foregroundStyle(AnclaTheme.tertiaryText)

      content()
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(AnclaTheme.panel)
        .overlay(
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(AnclaTheme.panelStroke.opacity(0.8), lineWidth: 1)
        )
    )
  }

  private func surfaceRow(
    label: String,
    value: String,
    detail: String,
    accentColor: Color = AnclaTheme.primaryText,
    monospaced: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 16) {
        Text(label)
          .font(.ancla(12, weight: .medium))
          .foregroundStyle(AnclaTheme.tertiaryText)

        Spacer(minLength: 0)

        Text(value)
          .font(monospaced ? .anclaMono(14) : .ancla(15, weight: .medium))
          .foregroundStyle(accentColor)
          .multilineTextAlignment(.trailing)
      }

      Text(detail)
        .font(.ancla(13))
        .foregroundStyle(AnclaTheme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func informativeRow(
    title: String,
    detail: String,
    accentColor: Color,
    highlight: Bool,
    trailingText: String? = nil,
    trailingSymbol: String? = nil
  ) -> some View {
    HStack(alignment: .center, spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.ancla(15, weight: .medium))
          .foregroundStyle(accentColor)

        Text(detail)
          .font(.ancla(12))
          .foregroundStyle(AnclaTheme.secondaryText)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Spacer(minLength: 0)

      if let trailingText {
        Text(trailingText)
          .font(.ancla(12, weight: .medium))
          .foregroundStyle(highlight ? AnclaTheme.successText : AnclaTheme.secondaryText)
      }

      if let trailingSymbol {
        Image(systemName: trailingSymbol)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(AnclaTheme.secondaryText)
      }
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(highlight ? AnclaTheme.panelRaised : AnclaTheme.panelInteractive)
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
              highlight ? AnclaTheme.accentStroke.opacity(0.55) : AnclaTheme.panelStroke.opacity(0.75),
              lineWidth: 1
            )
        )
    )
  }

  private func interactiveRow(title: String, detail: String) -> some View {
    HStack(alignment: .center, spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.ancla(15, weight: .medium))
          .foregroundStyle(AnclaTheme.primaryText)

        Text(detail)
          .font(.ancla(12))
          .foregroundStyle(AnclaTheme.secondaryText)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Spacer(minLength: 0)

      Image(systemName: "chevron.right")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(AnclaTheme.tertiaryText)
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(AnclaTheme.panelInteractive)
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
        )
    )
  }

  private func modeRow(_ mode: BlockMode) -> some View {
    let isSelected = mode.id == currentMode?.id
    let isArmed = viewModel.isModeArmed(mode.id)

    return HStack(alignment: .center, spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Text(mode.name)
          .font(.ancla(15, weight: .medium))
          .foregroundStyle(AnclaTheme.primaryText)

        Text(viewModel.selectionSummary(for: mode))
          .font(.ancla(12))
          .foregroundStyle(AnclaTheme.secondaryText)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Spacer(minLength: 0)

      if isArmed {
        Text("Active")
          .font(.ancla(12, weight: .medium))
          .foregroundStyle(AnclaTheme.warningText)
      }

      Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(isSelected ? AnclaTheme.accentFill : AnclaTheme.tertiaryText)
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(isSelected ? AnclaTheme.panelRaised : AnclaTheme.panelInteractive)
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
              isSelected ? AnclaTheme.accentStroke.opacity(0.55) : AnclaTheme.panelStroke.opacity(0.75),
              lineWidth: 1
            )
        )
    )
  }

  private var surfaceDivider: some View {
    Rectangle()
      .fill(AnclaTheme.panelStroke.opacity(0.55))
      .frame(height: 1)
  }

  private func errorSection(_ message: String) -> some View {
    Text(message)
      .font(.ancla(13, weight: .medium))
      .foregroundStyle(AnclaTheme.errorText)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(AnclaTheme.panelInteractive)
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(AnclaTheme.errorText.opacity(0.28), lineWidth: 1)
          )
      )
  }

  private var bottomActionBar: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Action")
        .font(.ancla(11, weight: .medium))
        .foregroundStyle(AnclaTheme.tertiaryText)
        .tracking(1.2)

      Button(action: primaryAction) {
        Text(primaryActionTitle)
          .font(.ancla(15, weight: .semibold))
          .foregroundStyle(AnclaTheme.ctaText)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .fill(AnclaTheme.ctaFill)
          )
      }
      .buttonStyle(.plain)
      .disabled(primaryActionDisabled || viewModel.isBusy)
      .opacity(primaryActionDisabled || viewModel.isBusy ? 0.6 : 1)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 24)
    .padding(.top, 12)
    .padding(.bottom, 16)
    .background(AnclaTheme.background)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(AnclaTheme.panelStroke.opacity(0.4))
        .frame(height: 1)
    }
  }

  private var renameAnchorSheet: some View {
    ZStack {
      AnclaTheme.background
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 20) {
        Capsule(style: .continuous)
          .fill(AnclaTheme.tertiaryText.opacity(0.6))
          .frame(width: 40, height: 4)
          .frame(maxWidth: .infinity)
          .padding(.top, 8)

        HStack {
          Button("Cancel") {
            isRenamingAnchor = false
          }
          .font(.ancla(16))
          .foregroundStyle(AnclaTheme.secondaryText)

          Spacer()

          Text("Rename anchor")
            .font(.ancla(18, weight: .bold))
            .foregroundStyle(AnclaTheme.primaryText)

          Spacer()

          Button("Save") {
            Task {
              await viewModel.renamePairedSticker(anchorNameDraft)
              if viewModel.lastError == nil {
                isRenamingAnchor = false
              }
            }
          }
          .font(.ancla(16, weight: .semibold))
          .foregroundStyle(AnclaTheme.primaryText)
        }

        VStack(alignment: .leading, spacing: 12) {
          Text("Anchor name")
            .font(.ancla(11, weight: .medium))
            .foregroundStyle(AnclaTheme.tertiaryText)

          TextField("", text: $anchorNameDraft)
            .textInputAutocapitalization(.words)
            .font(.ancla(28))
            .foregroundStyle(AnclaTheme.primaryText)

          surfaceDivider
        }

        Spacer()
      }
      .padding(.horizontal, 28)
      .padding(.top, 16)
      .padding(.bottom, 28)
    }
    .preferredColorScheme(.dark)
    .presentationDetents([.medium])
    .presentationDragIndicator(.hidden)
  }

  private var currentMode: BlockMode? {
    viewModel.selectedMode() ?? viewModel.preferredMode()
  }

  private var currentModeDetail: String {
    guard let currentMode else {
      return "Create or choose a mode before starting a session."
    }

    return viewModel.selectionSummary(for: currentMode)
  }

  private var anchorDetail: String {
    guard viewModel.snapshot.pairedTag != nil else {
      return "No anchor is paired to this iPhone yet."
    }

    return "Only the paired anchor can release an active session."
  }

  private var fingerprintValue: String {
    guard let uidHash = viewModel.snapshot.pairedTag?.uidHash else {
      return "Awaiting pair"
    }

    return tagPreview(uidHash)
  }

  private var sessionValue: String {
    switch viewModel.snapshot.activeSession?.state {
    case .armed:
      return "Active"
    case .mismatchedTag:
      return "Wrong anchor"
    case .released:
      return "Released"
    case .idle, nil:
      return "Idle"
    }
  }

  private var sessionDetail: String {
    switch viewModel.snapshot.activeSession?.state {
    case .armed:
      return "The current session remains active until the paired anchor is scanned."
    case .mismatchedTag:
      return "A different anchor was scanned. The session remains active."
    case .released:
      return "The most recent session was released successfully."
    case .idle, nil:
      return "No active session is running right now."
    }
  }

  private var sessionAccent: Color {
    switch viewModel.snapshot.activeSession?.state {
    case .armed, .mismatchedTag:
      return AnclaTheme.warningText
    case .released:
      return AnclaTheme.successText
    default:
      return AnclaTheme.primaryText
    }
  }

  private var systemItems: [RuntimeDiagnosticItem] {
    let ids = ["build", "screen-time", "nfc", "storage"]
    return viewModel.diagnostics.items.filter { ids.contains($0.id) }
  }

  private var anchorTagURL: URL? {
    URL(string: "https://s.click.aliexpress.com/e/_c3De6uih")
  }

  private var primaryActionTitle: String {
    switch nextStep {
    case .authorize:
      return "Enable App Controls"
    case .pairAnchor:
      return "Pair Anchor"
    case .createMode:
      return "Create Mode"
    case .release:
      return "Release Session"
    case .arm:
      return "Start Session"
    case .rearm:
      return "Start New Session"
    }
  }

  private var primaryActionDisabled: Bool {
    switch nextStep {
    case .authorize:
      return false
    case .pairAnchor:
      return false
    case .createMode:
      return false
    case .release:
      return !viewModel.canReleaseActiveSession
    case .arm, .rearm:
      return !viewModel.canArmSelectedMode
    }
  }

  private func primaryAction() {
    switch nextStep {
    case .authorize:
      Task { await viewModel.requestAuthorization() }
    case .pairAnchor:
      Task { await viewModel.pairSticker() }
    case .createMode:
      viewModel.prepareDraftForNewMode()
      isModeEditorPresented = true
    case .release:
      Task { await viewModel.releaseActiveSession() }
    case .arm, .rearm:
      Task { await viewModel.armSelectedMode() }
    }
  }

  private var nextStep: NextStep {
    if !viewModel.snapshot.isAuthorized {
      return .authorize
    }

    if viewModel.snapshot.pairedTag == nil {
      return .pairAnchor
    }

    if !viewModel.hasAnyMode {
      return .createMode
    }

    if viewModel.canReleaseActiveSession {
      return .release
    }

    if viewModel.snapshot.activeSession?.state == .released {
      return .rearm
    }

    return .arm
  }

  private func tagPreview(_ hash: String) -> String {
    let prefix = hash.prefix(4)
    let suffix = hash.suffix(4)
    return "\(prefix)...\(suffix)"
  }

  private func toneColor(_ tone: RuntimeDiagnosticTone) -> Color {
    switch tone {
    case .ready:
      return AnclaTheme.primaryText
    case .attention:
      return AnclaTheme.warningText
    case .blocked:
      return AnclaTheme.errorText
    case .neutral:
      return AnclaTheme.secondaryText
    }
  }
}

private extension View {
  @ViewBuilder
  func anclaFamilyActivityPicker(
    isPresented: Binding<Bool>,
    selection: Binding<FamilyActivitySelection>
  ) -> some View {
#if SIDELOAD_LITE
    self
#else
    familyActivityPicker(
      isPresented: isPresented,
      selection: selection
    )
#endif
  }
}
