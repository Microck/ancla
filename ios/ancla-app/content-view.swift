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
  @State private var modePendingDeletion: BlockMode?

  var body: some View {
    NavigationStack {
      ZStack {
        backgroundLayer

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 20) {
            header
            nextStepSection
            setupSection
            sessionSection
            modesSection
            stickerSection
            buySection
            primaryActions

            if let lastError = viewModel.lastError {
              Text(lastError)
                .font(.ancla(13, weight: .medium))
                .foregroundStyle(Color(red: 0.71, green: 0.14, blue: 0.17))
            }
          }
          .padding(.horizontal, 20)
          .padding(.top, 18)
          .padding(.bottom, 32)
        }
      }
      .navigationBarHidden(true)
      .sheet(isPresented: $isModeEditorPresented) {
        ModeEditorView(
          viewModel: viewModel,
          isEditingMode: viewModel.draftModeID != nil,
          onChooseSelection: { viewModel.isPickerPresented = true }
        )
      }
      .sheet(isPresented: $isRenamingSticker) {
        renameStickerSheet
      }
      .familyActivityPicker(
        isPresented: $viewModel.isPickerPresented,
        selection: $viewModel.draftSelection
      )
      .alert("Delete this mode?", isPresented: deleteAlertBinding) {
        Button("Delete", role: .destructive) {
          guard let mode = modePendingDeletion else {
            return
          }
          Task {
            await viewModel.deleteMode(mode.id)
          }
          modePendingDeletion = nil
        }

        Button("Cancel", role: .cancel) {
          modePendingDeletion = nil
        }
      } message: {
        Text("This will remove the mode and clear an armed session that uses it.")
      }
      .onChange(of: isRenamingSticker) { _, isOpen in
        if isOpen {
          stickerNameDraft = viewModel.snapshot.pairedTag?.displayName ?? ""
        }
      }
    }
  }

  private var backgroundLayer: some View {
    LinearGradient(
      colors: [
        Color(red: 0.98, green: 0.98, blue: 0.99),
        Color(red: 0.95, green: 0.97, blue: 0.99),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text("ANCLA")
          .font(.ancla(11, weight: .medium))
          .tracking(3)
          .foregroundStyle(Color(red: 0.43, green: 0.5, blue: 0.58))

        Text(sessionStateLabel)
          .font(.ancla(34, weight: .semibold))
          .tracking(-0.8)
          .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))

        Text(sessionMessage)
          .font(.ancla(14))
          .foregroundStyle(Color(red: 0.34, green: 0.4, blue: 0.48))
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)

      Image(systemName: "anchor")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))
        .frame(width: 44, height: 44)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color(red: 0.86, green: 0.89, blue: 0.93), lineWidth: 1)
        )
    }
  }

  private var setupSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionLabel("SETUP")

      Text("Order: buy one NTAG213 sticker, pair it, create a mode, then arm it.")
        .font(.ancla(13))
        .foregroundStyle(Color(red: 0.43, green: 0.5, blue: 0.58))
        .fixedSize(horizontal: false, vertical: true)

      setupRow(
        "Screen Time access",
        value: viewModel.snapshot.isAuthorized ? "Ready" : "Needed"
      ) {
        Task { await viewModel.requestAuthorization() }
      }

      setupRow(
        "Paired sticker",
        value: viewModel.snapshot.pairedTag?.displayName ?? "Pair one"
      ) {
        Task { await viewModel.pairSticker() }
      }

      setupRow(
        "Default mode",
        value: viewModel.preferredMode()?.name ?? "Create one"
      ) {
        if viewModel.snapshot.modes.isEmpty {
          viewModel.prepareDraftForNewMode()
          isModeEditorPresented = true
        } else if let preferredMode = viewModel.preferredMode() {
          viewModel.prepareDraftForEditingMode(preferredMode.id)
          if viewModel.draftModeID == preferredMode.id {
            isModeEditorPresented = true
          }
        }
      }
    }
  }

  private var nextStepSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        sectionLabel("NEXT")
        Spacer()
        Text(setupProgressLabel)
          .font(.ancla(11, weight: .medium))
          .tracking(2)
          .foregroundStyle(Color(red: 0.43, green: 0.5, blue: 0.58))
      }

      Text(nextStepTitle)
        .font(.ancla(22, weight: .semibold))
        .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))

      Text(nextStepMessage)
        .font(.ancla(14))
        .foregroundStyle(Color(red: 0.34, green: 0.4, blue: 0.48))
        .fixedSize(horizontal: false, vertical: true)

      nextStepButton
    }
    .padding(16)
    .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(Color(red: 0.86, green: 0.89, blue: 0.93), lineWidth: 1)
    )
  }

  private var sessionSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionLabel("SESSION")

      summaryRow("State", value: sessionStateLabel)
      summaryRow("Mode", value: selectedModeName)
      summaryRow("Sticker", value: viewModel.snapshot.pairedTag?.displayName ?? "Not paired")
    }
  }

  private var modesSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        sectionLabel("MODES")
        Spacer()
        Button("New") {
          viewModel.prepareDraftForNewMode()
          isModeEditorPresented = true
        }
        .font(.ancla(13, weight: .semibold))
        .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))
      }

      if viewModel.modesForDisplay.isEmpty {
        Text("No modes yet.")
          .font(.ancla(14))
          .foregroundStyle(Color(red: 0.43, green: 0.5, blue: 0.58))
      } else {
        VStack(spacing: 0) {
          ForEach(Array(viewModel.modesForDisplay.enumerated()), id: \.element.id) { index, mode in
            modeRow(mode)

            if index < viewModel.modesForDisplay.count - 1 {
              divider
            }
          }
        }
      }
    }
  }

  private var stickerSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionLabel("STICKER")

      if let tag = viewModel.snapshot.pairedTag {
        summaryRow("Name", value: tag.displayName)
        summaryRow("Fingerprint", value: tagPreview(tag.uidHash))

        HStack(spacing: 8) {
          actionPill("Rename") {
            isRenamingSticker = true
          }
          actionPill("Replace") {
            Task { await viewModel.pairSticker() }
          }
          actionPill("Unpair", destructive: true) {
            Task { await viewModel.unpairSticker() }
          }
        }
      } else {
        Text("No sticker paired.")
          .font(.ancla(14))
          .foregroundStyle(Color(red: 0.43, green: 0.5, blue: 0.58))
      }
    }
  }

  private var primaryActions: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionLabel("ACTIONS")

      actionRow("Arm selected mode", emphasized: true) {
        Task { await viewModel.armSelectedMode() }
      }
      .disabled(!viewModel.canArmSelectedMode)

      actionRow("Scan to release") {
        Task { await viewModel.releaseActiveSession() }
      }
      .disabled(!viewModel.canReleaseActiveSession)
    }
  }

  private var buySection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionLabel("BUY")

      Text("Buy a standard NTAG213 sticker. Use 25 mm or larger, and avoid metal surfaces unless the tag is specifically on-metal.")
        .font(.ancla(14))
        .foregroundStyle(Color(red: 0.34, green: 0.4, blue: 0.48))
        .fixedSize(horizontal: false, vertical: true)

      buyLinkRow(
        "Recommended sticker",
        detail: "AliExpress NTAG213 standard sticker - choose 38 mm if available"
      ) {
        URL(string: "https://s.click.aliexpress.com/e/_c3De6uih")
      }

      buyLinkRow(
        "Amazon starter pack",
        detail: "Standard NTAG213 adhesive sticker"
      ) {
        URL(string: "https://www.amazon.com/Stickers-Adhesive-Compatible-NFC-Enabled-Smartphones/dp/B07GFHLZD1")
      }

      buyLinkRow(
        "AliExpress value pack",
        detail: "Smaller-pack backup recommendation"
      ) {
        URL(string: "https://s.click.aliexpress.com/e/_c3SMBZ1j")
      }
    }
  }

  private func modeRow(_ mode: BlockMode) -> some View {
    let isSelected = viewModel.selectedModeID == mode.id
    let isArmed = viewModel.isModeArmed(mode.id)

    return HStack(alignment: .center, spacing: 10) {
      Button {
        viewModel.selectMode(mode.id)
      } label: {
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 7) {
            Text(mode.name)
              .font(.ancla(16, weight: .semibold))
              .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))

            if mode.isDefault {
              statusPill("Default")
            }

            if isArmed {
              statusPill("Armed")
            }
          }

          Text(viewModel.selectionSummary(for: mode))
            .font(.ancla(13))
            .foregroundStyle(Color(red: 0.43, green: 0.5, blue: 0.58))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)

      Menu {
        Button("Arm mode") {
          Task { await viewModel.armMode(mode.id) }
        }
        Button("Edit mode") {
          viewModel.prepareDraftForEditingMode(mode.id)
          if viewModel.draftModeID == mode.id {
            isModeEditorPresented = true
          }
        }
        if !mode.isDefault {
          Button("Set as default") {
            Task { await viewModel.setDefaultMode(mode.id) }
          }
        }
        Button("Delete mode", role: .destructive) {
          modePendingDeletion = mode
        }
      } label: {
        Image(systemName: "ellipsis")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Color(red: 0.45, green: 0.52, blue: 0.61))
          .frame(width: 30, height: 30)
      }
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 2)
    .background(
      isSelected ? Color.white.opacity(0.78) : .clear,
      in: RoundedRectangle(cornerRadius: 10, style: .continuous)
    )
  }

  private var renameStickerSheet: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 12) {
        Text("Sticker name")
          .font(.ancla(14, weight: .semibold))
          .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))

        TextField("Desk sticker", text: $stickerNameDraft)
          .textInputAutocapitalization(.words)
          .padding(.horizontal, 14)
          .frame(height: 48)
          .background(
            Color(red: 0.95, green: 0.97, blue: 0.99),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
          )

        Spacer()
      }
      .padding(20)
      .navigationTitle("Rename sticker")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") {
            isRenamingSticker = false
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Save") {
            Task {
              await viewModel.renamePairedSticker(stickerNameDraft)
              if viewModel.lastError == nil {
                isRenamingSticker = false
              }
            }
          }
          .fontWeight(.semibold)
        }
      }
    }
    .presentationDetents([.fraction(0.32)])
  }

  private var sessionStateLabel: String {
    switch viewModel.snapshot.activeSession?.state ?? .idle {
    case .idle:
      return "Idle"
    case .armed:
      return "Armed"
    case .released:
      return "Released"
    case .mismatchedTag:
      return "Wrong sticker"
    }
  }

  private var sessionMessage: String {
    switch viewModel.snapshot.activeSession?.state ?? .idle {
    case .idle:
      return "Grant access, pair one sticker, make one mode."
    case .armed:
      return "Apps stay blocked until the paired sticker is scanned."
    case .released:
      return "The current session is released."
    case .mismatchedTag:
      return "Wrong sticker. The block is still armed until the paired sticker is scanned."
    }
  }

  private var selectedModeName: String {
    viewModel.selectedMode()?.name ?? viewModel.preferredMode()?.name ?? "None"
  }

  private var setupProgressLabel: String {
    let completed = [
      viewModel.snapshot.isAuthorized,
      viewModel.snapshot.pairedTag != nil,
      viewModel.hasAnyMode,
    ]
    .filter { $0 }
    .count

    return "\(completed)/3 READY"
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

  private var nextStepTitle: String {
    switch nextStep {
    case .authorize:
      return "Grant access first"
    case .pairSticker:
      return "Pair the sticker"
    case .createMode:
      return "Make the block"
    case .release:
      return "Use the physical release"
    case .arm:
      return "Start the block"
    case .rearm:
      return "Arm it again"
    }
  }

  private var nextStepMessage: String {
    switch nextStep {
    case .authorize:
      return "Ancla needs Screen Time authorization before it can shield apps or websites."
    case .pairSticker:
      return "Use the recommended NTAG213 sticker. Once it is paired, only that sticker can release the block."
    case .createMode:
      return "Choose the apps and sites you want to make physically annoying to reopen."
    case .release:
      return "The current block stays active until the paired sticker is scanned. Wrong stickers do nothing."
    case .arm:
      return "Your setup is ready. Arm the selected mode to start the physical-friction loop."
    case .rearm:
      return "The last session is released. Arm the selected mode whenever you want the block back."
    }
  }

  private func sectionLabel(_ title: String) -> some View {
    Text(title)
      .font(.ancla(11, weight: .medium))
      .tracking(3)
      .foregroundStyle(Color(red: 0.43, green: 0.5, blue: 0.58))
  }

  private func summaryRow(_ title: String, value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .font(.ancla(14))
        .foregroundStyle(Color(red: 0.43, green: 0.5, blue: 0.58))

      Spacer()

      Text(value)
        .font(.ancla(14, weight: .medium))
        .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))
        .multilineTextAlignment(.trailing)
    }
  }

  private func setupRow(_ title: String, value: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(alignment: .center, spacing: 10) {
        Text(title)
          .font(.ancla(14))
          .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))

        Spacer()

        Text(value)
          .font(.ancla(13, weight: .medium))
          .foregroundStyle(Color(red: 0.43, green: 0.5, blue: 0.58))

        Image(systemName: "chevron.right")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(Color(red: 0.65, green: 0.7, blue: 0.76))
      }
      .padding(.vertical, 6)
    }
    .buttonStyle(.plain)
  }

  private func statusPill(_ title: String) -> some View {
    Text(title)
      .font(.ancla(11, weight: .semibold))
      .foregroundStyle(Color(red: 0.25, green: 0.31, blue: 0.39))
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color(red: 0.94, green: 0.96, blue: 0.99), in: Capsule())
  }

  private func actionPill(
    _ title: String,
    destructive: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .font(.ancla(12, weight: .semibold))
        .foregroundStyle(
          destructive
            ? Color(red: 0.66, green: 0.11, blue: 0.15)
            : Color(red: 0.06, green: 0.09, blue: 0.16)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
          destructive
            ? Color(red: 1, green: 0.94, blue: 0.95)
            : Color.white,
          in: Capsule()
        )
    }
    .buttonStyle(.plain)
  }

  private func actionRow(
    _ title: String,
    emphasized: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        Text(title)
        Spacer()

        if viewModel.isBusy {
          ProgressView()
            .tint(emphasized ? .white : Color(red: 0.06, green: 0.09, blue: 0.16))
        }
      }
      .font(.ancla(14, weight: .medium))
      .foregroundStyle(emphasized ? Color.white : Color(red: 0.06, green: 0.09, blue: 0.16))
      .padding(.horizontal, 14)
      .frame(height: 48)
      .background(
        emphasized ? Color(red: 0.06, green: 0.09, blue: 0.16) : Color.white,
        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(
            emphasized ? Color.clear : Color(red: 0.86, green: 0.89, blue: 0.93),
            lineWidth: 1
          )
      )
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var nextStepButton: some View {
    switch nextStep {
    case .authorize:
      actionRow("Grant Screen Time access", emphasized: true) {
        Task { await viewModel.requestAuthorization() }
      }
    case .pairSticker:
      actionRow("Pair your sticker", emphasized: true) {
        Task { await viewModel.pairSticker() }
      }
    case .createMode:
      actionRow("Create your first mode", emphasized: true) {
        viewModel.prepareDraftForNewMode()
        isModeEditorPresented = true
      }
    case .release:
      actionRow("Scan the paired sticker", emphasized: true) {
        Task { await viewModel.releaseActiveSession() }
      }
    case .arm, .rearm:
      actionRow("Arm selected mode", emphasized: true) {
        Task { await viewModel.armSelectedMode() }
      }
      .disabled(!viewModel.canArmSelectedMode)
    }
  }

  private func buyLinkRow(
    _ title: String,
    detail: String,
    destination: @escaping () -> URL?
  ) -> some View {
    Group {
      if let url = destination() {
        Link(destination: url) {
          HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
              Text(title)
                .font(.ancla(14, weight: .medium))
                .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))

              Text(detail)
                .font(.ancla(12))
                .foregroundStyle(Color(red: 0.43, green: 0.5, blue: 0.58))
            }

            Spacer()

            Image(systemName: "arrow.up.right")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(Color(red: 0.45, green: 0.52, blue: 0.61))
          }
          .padding(.vertical, 6)
        }
      }
    }
  }

  private var divider: some View {
    Rectangle()
      .fill(Color(red: 0.86, green: 0.89, blue: 0.93))
      .frame(height: 1)
  }

  private var deleteAlertBinding: Binding<Bool> {
    Binding(
      get: { modePendingDeletion != nil },
      set: { newValue in
        if !newValue {
          modePendingDeletion = nil
        }
      }
    )
  }

  private func tagPreview(_ hash: String) -> String {
    let prefix = hash.prefix(8)
    let suffix = hash.suffix(6)
    return "\(prefix)...\(suffix)"
  }
}
