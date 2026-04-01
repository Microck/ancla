import FamilyControls
import SwiftUI

private enum NextStep {
  case authorize
  case pairSticker
  case createMode
  case release
  case arm
  case rearm
}

struct ContentView: View {
  @Bindable var viewModel: AppViewModel

  @State private var isModeEditorPresented = false
  @State private var isRenamingSticker = false
  @State private var stickerNameDraft = ""

  var body: some View {
    NavigationStack {
      ZStack {
        AnclaTheme.background
          .ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 28) {
            header
            headlineSection
            sessionSurface

            if viewModel.modesForDisplay.count > 1 {
              modeSelector
            }

            actionsRow
            systemSurface

            if let lastError = viewModel.lastError, !lastError.isEmpty {
              errorSection(lastError)
            }

            if viewModel.isSideloadLiteBuild {
              sideloadFootnote
            }
          }
          .padding(.horizontal, 24)
          .padding(.top, 24)
          .padding(.bottom, 132)
        }
      }
      .toolbar(.hidden, for: .navigationBar)
      .preferredColorScheme(.dark)
      .safeAreaInset(edge: .bottom) {
        bottomActionBar
      }
      .sheet(isPresented: $isModeEditorPresented) {
        ModeEditorView(
          viewModel: viewModel,
          isEditingMode: viewModel.draftModeID != nil,
          onChooseSelection: { viewModel.isPickerPresented = true }
        )
        .presentationBackground(.clear)
      }
      .sheet(isPresented: $isRenamingSticker) {
        renameStickerSheet
          .presentationBackground(.clear)
      }
      .familyActivityPicker(
        isPresented: $viewModel.isPickerPresented,
        selection: $viewModel.draftSelection
      )
      .task {
        viewModel.refreshDiagnostics()
      }
      .onChange(of: isRenamingSticker) { _, isOpen in
        if isOpen {
          stickerNameDraft = viewModel.snapshot.pairedTag?.displayName ?? ""
        }
      }
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 12) {
      HStack(spacing: 10) {
        AnclaMark(color: AnclaTheme.primaryText, size: 18)

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
    VStack(alignment: .leading, spacing: 12) {
      Text(viewModel.diagnostics.headline)
        .font(.ancla(42, weight: .medium))
        .foregroundStyle(AnclaTheme.primaryText)

      Text(viewModel.diagnostics.message)
        .font(.ancla(15))
        .foregroundStyle(AnclaTheme.secondaryText)
        .frame(maxWidth: 320, alignment: .leading)

      HStack(spacing: 8) {
        Capsule()
          .fill(primaryPillColor)
          .frame(width: 7, height: 7)

        Text(primaryPillText)
          .font(.ancla(12, weight: .medium))
          .foregroundStyle(AnclaTheme.secondaryText)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        Capsule(style: .continuous)
          .fill(AnclaTheme.panelRaised)
          .overlay(
            Capsule(style: .continuous)
              .stroke(AnclaTheme.panelStroke.opacity(0.8), lineWidth: 1)
          )
      )
    }
  }

  private var sessionSurface: some View {
    surface(title: "Current setup") {
      VStack(spacing: 16) {
        surfaceRow(
          label: "Selected mode",
          value: currentMode?.name ?? "None",
          detail: currentModeDetail
        )

        surfaceDivider

        surfaceRow(
          label: "Sticker",
          value: viewModel.snapshot.pairedTag?.displayName ?? "Unpaired",
          detail: stickerDetail
        )

        if viewModel.snapshot.pairedTag != nil {
          surfaceDivider

          surfaceRow(
            label: "Fingerprint",
            value: fingerprintValue,
            detail: "Short preview of the paired NFC tag fingerprint.",
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

  private var modeSelector: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(viewModel.modesForDisplay) { mode in
          Button {
            viewModel.selectMode(mode.id)
          } label: {
            Text(mode.name)
              .font(.ancla(13, weight: .medium))
              .foregroundStyle(mode.id == currentMode?.id ? AnclaTheme.ctaText : AnclaTheme.secondaryText)
              .padding(.horizontal, 14)
              .padding(.vertical, 10)
              .background(
                Capsule(style: .continuous)
                  .fill(mode.id == currentMode?.id ? AnclaTheme.ctaFill : AnclaTheme.panelRaised)
              )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var actionsRow: some View {
    HStack(spacing: 10) {
      Menu {
        if !viewModel.modesForDisplay.isEmpty {
          ForEach(viewModel.modesForDisplay) { mode in
            Button(mode.name) {
              viewModel.selectMode(mode.id)
            }
          }

          Button("Edit current mode") {
            if let mode = currentMode {
              viewModel.prepareDraftForEditingMode(mode.id)
              isModeEditorPresented = true
            }
          }
        }

        Button("New mode") {
          viewModel.prepareDraftForNewMode()
          isModeEditorPresented = true
        }
      } label: {
        utilityCapsule("Modes")
      }

      if viewModel.snapshot.pairedTag != nil {
        Menu {
          Button("Rename sticker") {
            isRenamingSticker = true
          }

          Button("Scan again") {
            Task { await viewModel.pairSticker() }
          }

          Button("Unpair", role: .destructive) {
            Task { await viewModel.unpairSticker() }
          }
        } label: {
          utilityCapsule("Sticker")
        }
      } else if let stickerURL {
        Link(destination: stickerURL) {
          utilityCapsule("Buy NFC sticker")
        }
      }

      Spacer(minLength: 0)
    }
  }

  private var systemSurface: some View {
    surface(title: "System checks") {
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

  private var surfaceDivider: some View {
    Rectangle()
      .fill(AnclaTheme.panelStroke.opacity(0.55))
      .frame(height: 1)
  }

  private func utilityCapsule(_ title: String) -> some View {
    Text(title)
      .font(.ancla(12, weight: .medium))
      .foregroundStyle(AnclaTheme.secondaryText)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(
        Capsule(style: .continuous)
          .fill(AnclaTheme.panelRaised)
          .overlay(
            Capsule(style: .continuous)
              .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
          )
      )
  }

  private func errorSection(_ message: String) -> some View {
    Text(message)
      .font(.ancla(13, weight: .medium))
      .foregroundStyle(AnclaTheme.errorText)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var sideloadFootnote: some View {
    Text("This build keeps NFC pairing and sticker release. System-level Screen Time shielding remains exclusive to the full Apple-authorized build.")
      .font(.ancla(12))
      .foregroundStyle(AnclaTheme.tertiaryText)
      .frame(maxWidth: 320, alignment: .leading)
  }

  private var bottomActionBar: some View {
    ZStack {
      AnclaTheme.background.opacity(0.98)
        .ignoresSafeArea(edges: .bottom)

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
      .padding(.horizontal, 24)
      .padding(.top, 10)
      .padding(.bottom, 18)
    }
  }

  private var renameStickerSheet: some View {
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
            isRenamingSticker = false
          }
          .font(.ancla(16))
          .foregroundStyle(AnclaTheme.secondaryText)

          Spacer()

          Text("Rename sticker")
            .font(.ancla(18, weight: .bold))
            .foregroundStyle(AnclaTheme.primaryText)

          Spacer()

          Button("Save") {
            Task {
              await viewModel.renamePairedSticker(stickerNameDraft)
              if viewModel.lastError == nil {
                isRenamingSticker = false
              }
            }
          }
          .font(.ancla(16, weight: .semibold))
          .foregroundStyle(AnclaTheme.primaryText)
        }

        VStack(alignment: .leading, spacing: 12) {
          Text("Sticker name")
            .font(.ancla(11, weight: .medium))
            .foregroundStyle(AnclaTheme.tertiaryText)

          TextField("", text: $stickerNameDraft)
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
      return "Create or select one mode before arming."
    }

    return viewModel.selectionSummary(for: currentMode)
  }

  private var stickerDetail: String {
    guard viewModel.snapshot.pairedTag != nil else {
      return "No release key is paired to this install yet."
    }

    return "Only this sticker can release an armed session."
  }

  private var fingerprintValue: String {
    guard let uidHash = viewModel.snapshot.pairedTag?.uidHash else {
      return "Awaiting scan"
    }

    return tagPreview(uidHash)
  }

  private var sessionValue: String {
    switch viewModel.snapshot.activeSession?.state {
    case .armed:
      return "Armed"
    case .mismatchedTag:
      return "Wrong sticker"
    case .released:
      return "Released"
    case .idle, nil:
      return "Idle"
    }
  }

  private var sessionDetail: String {
    switch viewModel.snapshot.activeSession?.state {
    case .armed:
      return "The current mode is blocking and waiting for the paired sticker."
    case .mismatchedTag:
      return "A different sticker was scanned. The block is still active."
    case .released:
      return "The last armed session was released."
    case .idle, nil:
      return "No block is active right now."
    }
  }

  private var sessionAccent: Color {
    switch viewModel.snapshot.activeSession?.state {
    case .armed, .mismatchedTag:
      return AnclaTheme.warningText
    default:
      return AnclaTheme.primaryText
    }
  }

  private var systemItems: [RuntimeDiagnosticItem] {
    let ids = ["build", "screen-time", "nfc", "storage"]
    return viewModel.diagnostics.items.filter { ids.contains($0.id) }
  }

  private var primaryPillText: String {
    if viewModel.canReleaseActiveSession {
      return "paired sticker required"
    }

    if primaryActionDisabled {
      return "setup required"
    }

    return "ready for next step"
  }

  private var primaryPillColor: Color {
    if viewModel.canReleaseActiveSession {
      return AnclaTheme.warningText
    }

    if primaryActionDisabled {
      return AnclaTheme.tertiaryText
    }

    return AnclaTheme.primaryText
  }

  private var stickerURL: URL? {
    URL(string: "https://s.click.aliexpress.com/e/_c3De6uih")
  }

  private var primaryActionTitle: String {
    switch nextStep {
    case .authorize:
      return "Grant Screen Time access"
    case .pairSticker:
      return "Pair NFC sticker"
    case .createMode:
      return "Create block mode"
    case .release:
      return "Scan sticker to release"
    case .arm:
      return "Arm selected mode"
    case .rearm:
      return "Arm again"
    }
  }

  private var primaryActionDisabled: Bool {
    switch nextStep {
    case .authorize:
      return false
    case .pairSticker:
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
    case .pairSticker:
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
      return .pairSticker
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
