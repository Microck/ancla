#if !SIDELOAD_LITE
import FamilyControls
#endif
import SwiftUI

private enum NextStep {
  case authorize
  case unavailable
  case modeRequired
  case pairAnchor
  case release
  case arm
  case rearm
}

private enum HomeSection: String, Identifiable, CaseIterable {
  case modes
  case anchors
  case schedules
  case sessions

  var id: String { rawValue }

  var title: String {
    switch self {
    case .modes:
      return "Mode"
    case .anchors:
      return "Anchor"
    case .schedules:
      return "Schedule"
    case .sessions:
      return "Unlock"
    }
  }

  var symbol: String {
    switch self {
    case .modes:
      return "square.grid.2x2"
    case .anchors:
      return "dot.radiowaves.left.and.right"
    case .schedules:
      return "calendar"
    case .sessions:
      return "lock.open"
    }
  }
}

struct ContentView: View {
  @Bindable var viewModel: AppViewModel
  @Environment(\.scenePhase) private var scenePhase

  private let bottomActionBarClearance: CGFloat = 196

  @State private var selectedSection: HomeSection = .modes
  @State private var isModeEditorPresented = false
  @State private var isScheduleEditorPresented = false
  @State private var isPresetEditorPresented = false
  @State private var isParagraphChallengePresented = false
  @State private var isShortcutGuidesPresented = false
  @State private var isUnlockMenuPresented = false
  @State private var renamingAnchorID: UUID?
  @State private var anchorNameDraft = ""

  private var chromePanelRaised: Color {
    AnclaTheme.panelRaised
  }

  private var chromePanelInteractive: Color {
    AnclaTheme.panelInteractive
  }

  private var chromePanelStroke: Color {
    AnclaTheme.panelStroke
  }

  private var primaryActionFill: Color {
    Color.black
  }

  private var primaryActionShadow: Color {
    Color.black.opacity(0.35)
  }

  private var primaryActionBlocksTapThrough: Bool {
    primaryActionDisabled || viewModel.isBusy
  }

  private var shouldShowSetupFlow: Bool {
    viewModel.isSideloadLiteBuild
      && !viewModel.hasCompletedRequiredSetup
      && !viewModel.shouldShowLockedScreen
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AnclaBackgroundSurface(isWarningTinted: false)
          .ignoresSafeArea()

        if shouldShowSetupFlow {
          SetupFlowView(
            viewModel: viewModel,
            showsDismissButton: false,
            onDismiss: nil,
            onPairAnchor: {
              Task { await viewModel.pairSticker() }
            },
            onCreateMode: {
              viewModel.prepareDraftForNewMode()
              isModeEditorPresented = true
            }
          )
        } else if !viewModel.shouldShowLockedScreen {
          ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
              header
              headlineSection

              if let temporaryUnlock = viewModel.activeTemporaryUnlock {
                temporaryUnlockBanner(temporaryUnlock)
              }

              if let feedback = viewModel.feedback {
                feedbackRow(feedback)
              }

              selectedSectionPanel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, bottomActionBarClearance)
          }
        }

        if viewModel.shouldShowLockedScreen {
          LockScreenView(
            unlockMenuPresented: isUnlockMenuPresented,
            emergencyTitle: lockScreenEmergencyTitle,
            emergencyDetail: lockScreenEmergencyDetail,
            emergencyEnabled: lockScreenEmergencyEnabled,
            presets: viewModel.unlockPresetsForDisplay,
            feedback: viewModel.feedback,
            isBusy: viewModel.isBusy,
            onLockedSurfaceTap: {
              isUnlockMenuPresented = false
              guard !viewModel.isBusy else {
                return
              }
              Task { await viewModel.releaseActiveSession() }
            },
            onToggleUnlockMenu: {
              isUnlockMenuPresented.toggle()
            },
            onEmergencyAction: handleLockScreenEmergencyAction,
            onPreset: { preset in
              Task { await viewModel.activateUnlockPreset(preset.id) }
              isUnlockMenuPresented = false
            }
          )
        }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if !viewModel.shouldShowLockedScreen && !shouldShowSetupFlow {
          bottomDock
        }
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
      .sheet(isPresented: $isScheduleEditorPresented) {
        ScheduleEditorView(
          viewModel: viewModel,
          isEditingSchedule: viewModel.draftScheduleID != nil
        )
        .presentationBackground(.clear)
      }
      .sheet(isPresented: $isPresetEditorPresented) {
        UnlockPresetEditorView(
          viewModel: viewModel,
          isEditingPreset: viewModel.draftPresetID != nil
        )
        .presentationBackground(.clear)
      }
      .sheet(isPresented: $isParagraphChallengePresented) {
        ParagraphChallengeSheet(viewModel: viewModel)
          .presentationBackground(.clear)
      }
      .sheet(isPresented: renameAnchorPresented) {
        renameAnchorSheet
          .presentationBackground(.clear)
      }
      .sheet(isPresented: $isShortcutGuidesPresented) {
        ShortcutGuidesSheet()
          .presentationBackground(.clear)
      }
      .anclaFamilyActivityPicker(
        isPresented: $viewModel.isPickerPresented,
        selection: $viewModel.draftSelection
      )
      .task {
        viewModel.refreshDiagnostics()
      }
      .task {
        while !Task.isCancelled {
          try? await Task.sleep(nanoseconds: 30_000_000_000)
          _ = viewModel.syncScheduledSessions()
        }
      }
      .onChange(of: renamingAnchorID) { _, tagID in
        if let tagID, let pairedTag = viewModel.pairedTag(tagID) {
          anchorNameDraft = pairedTag.displayName
        }
      }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active {
          viewModel.handleSceneDidBecomeActive()
        }
      }
      .onChange(of: viewModel.shouldShowLockedScreen) { _, isShowingLockedScreen in
        if !isShowingLockedScreen {
          isUnlockMenuPresented = false
        }
      }
      .onChange(of: viewModel.isTemporaryUnlockActive) { _, isTemporaryUnlockActive in
        if isTemporaryUnlockActive {
          isUnlockMenuPresented = false
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
        viewModel.refreshFromHeader()
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
            .fill(chromePanelRaised)
            .overlay(
              Capsule(style: .continuous)
                .stroke(chromePanelStroke.opacity(0.75), lineWidth: 1)
            )
        )
      }
      .buttonStyle(.plain)

      if let repoURL {
        Link(destination: repoURL) {
          Image(systemName: "chevron.left.forwardslash.chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AnclaTheme.secondaryText)
            .frame(width: 36, height: 36)
            .background(
              Circle()
                .fill(chromePanelRaised)
                .overlay(
                  Circle()
                    .stroke(chromePanelStroke.opacity(0.75), lineWidth: 1)
                )
            )
        }
        .accessibilityLabel("Open GitHub repository")
      }
    }
  }

  private var headlineSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        statusBadge(nextStepLabel, color: sessionAccent)

        if let currentMode {
          statusBadge(currentMode.name, color: AnclaTheme.secondaryText)
        }
      }

      Text(viewModel.diagnostics.headline)
        .font(.ancla(34, weight: .medium))
        .foregroundStyle(AnclaTheme.primaryText)
        .lineLimit(2)
    }
  }

  private var selectedSectionPanel: some View {
    VStack(alignment: .leading, spacing: 0) {
      selectedSectionContent
    }
  }

  @ViewBuilder
  private var selectedSectionContent: some View {
    switch selectedSection {
    case .modes:
      modesSectionContent
    case .anchors:
      anchorsSectionContent
    case .schedules:
      schedulesSectionContent
    case .sessions:
      sessionsSectionContent
    }
  }

  private var modesSectionContent: some View {
    VStack(spacing: 0) {
      if viewModel.modesForDisplay.isEmpty {
        informativeRow(
          title: "No modes saved",
          detail: "Create one block setup first.",
          accentColor: AnclaTheme.primaryText,
          highlight: false,
          trailingSymbol: "plus"
        )
      } else {
        ForEach(viewModel.modesForDisplay) { mode in
          modeRow(mode)
        }
      }

      Button {
        viewModel.prepareDraftForNewMode()
        isModeEditorPresented = true
      } label: {
        actionRow(
          icon: "plus",
          title: "Create mode",
          detail: "Add another saved block setup.",
          isLoading: false
        )
      }
      .buttonStyle(.plain)
      .disabled(viewModel.isBusy)
    }
  }

  private var anchorsSectionContent: some View {
    VStack(spacing: 0) {
      if viewModel.pairedTagsForDisplay.isEmpty {
        informativeRow(
          title: "No anchor paired",
          detail: "Pair one NFC anchor for this iPhone.",
          accentColor: AnclaTheme.primaryText,
          highlight: false
        )
      } else {
        ForEach(viewModel.pairedTagsForDisplay) { pairedTag in
          pairedAnchorRow(pairedTag)
        }
      }

      Button {
        Task { await viewModel.pairSticker() }
      } label: {
        actionRow(
          icon: "plus",
          title: viewModel.pairedTagsForDisplay.isEmpty ? "Pair anchor" : "Pair another anchor",
          detail: "Scan an NFC anchor on this iPhone.",
          isLoading: viewModel.isActionInProgress(.pairAnchor)
        )
      }
      .buttonStyle(.plain)
      .disabled(viewModel.isBusy)
    }
  }

  private var schedulesSectionContent: some View {
    VStack(spacing: 0) {
      if viewModel.scheduledPlansForDisplay.isEmpty {
        informativeRow(
          title: "No schedules saved",
          detail: scheduledSessionsEmptyDetail,
          accentColor: AnclaTheme.primaryText,
          highlight: false,
          trailingSymbol: "calendar.badge.plus"
        )
      } else {
        ForEach(viewModel.scheduledPlansForDisplay) { plan in
          scheduledPlanRow(plan)
        }
      }

      Button {
        viewModel.prepareDraftForNewSchedule()
        isScheduleEditorPresented = true
      } label: {
        actionRow(
          icon: "calendar.badge.plus",
          title: "Create schedule",
          detail: "Auto-start a saved mode on selected days.",
          isLoading: false
        )
      }
      .buttonStyle(.plain)
      .disabled(viewModel.isBusy || !canCreateScheduledPlan)
      .opacity(viewModel.isBusy || !canCreateScheduledPlan ? 0.65 : 1)
    }
  }

  private var sessionsSectionContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      informativeRow(
        title: sessionSectionTitle,
        detail: sessionDetail,
        accentColor: sessionAccent,
        highlight: viewModel.activeSessionIsBlocking,
        trailingText: sessionSectionBadge
      )

      compactSectionTitle("Failsafe")

      informativeRow(
        title: emergencyUnbrickTitle,
        detail: emergencyUnbrickDetail,
        accentColor: emergencyUnbrickAccent,
        highlight: viewModel.snapshot.emergencyUnbricksRemaining > 0,
        trailingText: emergencyUnbrickBadge
      )

      informativeRow(
        title: "Typing challenge",
        detail: paragraphChallengeDetail,
        accentColor: viewModel.paragraphChallengeEnabled ? AnclaTheme.primaryText : AnclaTheme.secondaryText,
        highlight: viewModel.canUseParagraphChallenge,
        trailingText: viewModel.paragraphChallengeEnabled ? "On" : "Off"
      )

      Button {
        Task { await viewModel.setParagraphChallengeEnabled(!viewModel.paragraphChallengeEnabled) }
      } label: {
        actionRow(
          icon: viewModel.paragraphChallengeEnabled ? "checkmark.circle" : "circle",
          title: viewModel.paragraphChallengeEnabled ? "Disable typing challenge" : "Enable typing challenge",
          detail: "Keep the last-resort typing unlock ready.",
          isLoading: false
        )
      }
      .buttonStyle(.plain)
      .disabled(viewModel.isBusy)

      if viewModel.canUseEmergencyUnbrick {
        Button {
          Task { await viewModel.useEmergencyUnbrick() }
        } label: {
          actionRow(
            icon: "bolt.horizontal.circle",
            title: "Use failsafe",
            detail: "Release without the anchor.",
            isLoading: viewModel.isActionInProgress(.emergencyUnbrick),
            isDestructive: true
          )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isBusy)
      }

      if viewModel.canUseParagraphChallenge {
        Button {
          viewModel.prepareParagraphChallenge()
          isParagraphChallengePresented = true
        } label: {
          actionRow(
            icon: "text.alignleft",
            title: "Start typing challenge",
            detail: "Type the full passage exactly.",
            isLoading: false,
            isDestructive: true
          )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isBusy)
      }

      compactSectionTitle("Presets")

      if viewModel.unlockPresetsForDisplay.isEmpty {
        informativeRow(
          title: "No presets saved",
          detail: "Save a short unlock like checking 2FA.",
          accentColor: AnclaTheme.primaryText,
          highlight: false,
          trailingSymbol: "plus"
        )
      } else {
        ForEach(viewModel.unlockPresetsForDisplay) { preset in
          unlockPresetRow(preset)
        }
      }

      Button {
        viewModel.prepareDraftForNewPreset()
        isPresetEditorPresented = true
      } label: {
        actionRow(
          icon: "plus",
          title: "Create preset",
          detail: "Add a short timed unlock.",
          isLoading: false
        )
      }
      .buttonStyle(.plain)
      .disabled(viewModel.isBusy)

      if let activeTemporaryUnlock = viewModel.activeTemporaryUnlock {
        informativeRow(
          title: "\"\(activeTemporaryUnlock.reason)\" is active",
          detail: "The phone is temporarily open for \(viewModel.temporaryUnlockRemainingSeconds) more seconds.",
          accentColor: AnclaTheme.successText,
          highlight: true,
          trailingText: "\(viewModel.temporaryUnlockRemainingSeconds)s"
        )
      }

      if viewModel.isSideloadLiteBuild {
        compactSectionTitle("Shortcut")

        Button {
          isShortcutGuidesPresented = true
        } label: {
          actionRow(
            icon: "bolt.horizontal.circle",
            title: viewModel.hasCompletedShortcutSetup ? "Review Shortcut setup" : "Finish Shortcut setup",
            detail: "Include every app you want blocked.",
            isLoading: false
          )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isBusy)
      }

      compactSectionTitle("Recent")

      if viewModel.recentSessionHistory.isEmpty {
        informativeRow(
          title: "No sessions recorded",
          detail: "Completed sessions will appear here after they end.",
          accentColor: AnclaTheme.primaryText,
          highlight: false,
          trailingSymbol: "clock.arrow.circlepath"
        )
      } else {
        ForEach(Array(viewModel.recentSessionHistory.prefix(5))) { entry in
          historyRow(entry)
        }
      }
    }
  }

  private func statusBadge(_ title: String, color: Color) -> some View {
    Text(title)
      .font(.ancla(11, weight: .semibold))
      .foregroundStyle(color)
      .tracking(1.4)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
        Capsule(style: .continuous)
          .fill(color.opacity(0.12))
      )
  }

  private func compactSectionTitle(_ title: String) -> some View {
    Text(title)
      .font(.ancla(11, weight: .semibold))
      .tracking(1.2)
      .foregroundStyle(AnclaTheme.tertiaryText)
      .padding(.top, 18)
      .padding(.bottom, 6)
  }

  private func pairedAnchorRow(_ pairedTag: PairedTag) -> some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Text(pairedTag.displayName)
          .font(.ancla(15, weight: .medium))
          .foregroundStyle(isActiveAnchor(pairedTag.id) ? AnclaTheme.warningText : AnclaTheme.primaryText)

        Text(pairedAnchorDetail(for: pairedTag))
          .font(.ancla(12))
          .foregroundStyle(AnclaTheme.secondaryText)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Spacer(minLength: 0)

      Text(pairedAnchorBadge(for: pairedTag))
        .font(.ancla(12, weight: .medium))
        .foregroundStyle(isActiveAnchor(pairedTag.id) ? AnclaTheme.warningText : AnclaTheme.secondaryText)

      Menu {
        Button {
          renamingAnchorID = pairedTag.id
        } label: {
          Label("Rename anchor", systemImage: "pencil.line")
        }

        Button(role: .destructive) {
          Task { await viewModel.unpairSticker(pairedTag.id) }
        } label: {
          Label("Remove anchor", systemImage: "trash")
        }
      } label: {
        rowMenuLabel()
      }
      .disabled(viewModel.isBusy)
    }
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .overlay(alignment: .bottom) {
      surfaceDivider
    }
  }

  private func scheduledPlanRow(_ plan: ScheduledSessionPlan) -> some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Text(scheduledPlanTitle(for: plan))
          .font(.ancla(15, weight: .medium))
          .foregroundStyle(scheduledPlanAccent(for: plan))

        Text(scheduledPlanDetail(for: plan))
          .font(.ancla(12))
          .foregroundStyle(AnclaTheme.secondaryText)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Spacer(minLength: 0)

      Text(scheduledPlanBadge(for: plan))
        .font(.ancla(12, weight: .medium))
        .foregroundStyle(isScheduledPlanActive(plan) ? AnclaTheme.warningText : AnclaTheme.secondaryText)

      Menu {
        Button {
          viewModel.prepareDraftForEditingScheduledPlan(plan.id)
          isScheduleEditorPresented = true
        } label: {
          Label("Edit schedule", systemImage: "square.and.pencil")
        }

        Button(role: .destructive) {
          Task { await viewModel.deleteScheduledPlan(plan.id) }
        } label: {
          Label("Remove schedule", systemImage: "trash")
        }
      } label: {
        rowMenuLabel()
      }
      .disabled(viewModel.isBusy)
    }
    .padding(.vertical, 14)
    .overlay(alignment: .bottom) {
      surfaceDivider
    }
  }

  private func unlockPresetRow(_ preset: UnlockPreset) -> some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Text(preset.title)
          .font(.ancla(15, weight: .medium))
          .foregroundStyle(AnclaTheme.primaryText)

        Text(preset.detail)
          .font(.ancla(12))
          .foregroundStyle(AnclaTheme.secondaryText)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Spacer(minLength: 0)

      Text("\(preset.durationSeconds)s")
        .font(.ancla(12, weight: .medium))
        .foregroundStyle(viewModel.activeTemporaryUnlock?.presetID == preset.id ? AnclaTheme.successText : AnclaTheme.secondaryText)

      Menu {
        Button {
          viewModel.prepareDraftForEditingPreset(preset.id)
          isPresetEditorPresented = true
        } label: {
          Label("Edit preset", systemImage: "square.and.pencil")
        }

        Button(role: .destructive) {
          Task { await viewModel.deleteUnlockPreset(preset.id) }
        } label: {
          Label("Remove preset", systemImage: "trash")
        }
      } label: {
        rowMenuLabel()
      }
      .disabled(viewModel.isBusy)
    }
    .padding(.vertical, 14)
    .overlay(alignment: .bottom) {
      surfaceDivider
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
    .padding(.vertical, 14)
    .overlay(alignment: .bottom) {
      surfaceDivider
    }
  }

  private func actionRow(
    icon: String,
    title: String,
    detail: String,
    isLoading: Bool,
    isDestructive: Bool = false
  ) -> some View {
    HStack(alignment: .center, spacing: 12) {
      Group {
        if isLoading {
          ProgressView()
            .tint(isDestructive ? AnclaTheme.errorText : AnclaTheme.primaryText)
            .scaleEffect(0.8)
        } else {
          Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isDestructive ? AnclaTheme.errorText : AnclaTheme.primaryText)
        }
      }
      .frame(width: 18, height: 18)

      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.ancla(15, weight: .medium))
          .foregroundStyle(isDestructive ? AnclaTheme.errorText : AnclaTheme.primaryText)

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
    .padding(.vertical, 14)
    .overlay(alignment: .bottom) {
      surfaceDivider
    }
  }

  private func modeRow(_ mode: BlockMode) -> some View {
    let isSelected = mode.id == currentMode?.id
    let isArmed = viewModel.isModeArmed(mode.id)

    return HStack(alignment: .top, spacing: 12) {
      Button {
        viewModel.selectMode(mode.id)
      } label: {
        HStack(alignment: .top, spacing: 12) {
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
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(viewModel.isBusy)

      Menu {
        Button {
          viewModel.prepareDraftForEditingMode(mode.id)
          isModeEditorPresented = true
        } label: {
          Label("Edit mode", systemImage: "square.and.pencil")
        }
      } label: {
        rowMenuLabel()
      }
      .disabled(viewModel.isBusy)
    }
    .padding(.vertical, 14)
    .overlay(alignment: .bottom) {
      surfaceDivider
    }
  }

  private func historyRow(_ entry: SessionHistoryEntry) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(entry.modeName)
          .font(.ancla(15, weight: .medium))
          .foregroundStyle(AnclaTheme.primaryText)

        Spacer(minLength: 0)

        Text(historyDurationLabel(for: entry))
          .font(.ancla(12, weight: .medium))
          .foregroundStyle(AnclaTheme.successText)
      }

      Text(historySubtitle(for: entry))
        .font(.ancla(12))
        .foregroundStyle(AnclaTheme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 14)
    .overlay(alignment: .bottom) {
      surfaceDivider
    }
  }

  private var feedbackRowPadding: CGFloat { 14 }

  private func feedbackRow(_ feedback: ActionFeedback) -> some View {
    let color: Color
    switch feedback.tone {
    case .neutral:
      color = AnclaTheme.secondaryText
    case .success:
      color = AnclaTheme.successText
    case .error:
      color = AnclaTheme.errorText
    }

    return HStack(spacing: 10) {
      Circle()
        .fill(color.opacity(0.16))
        .frame(width: 24, height: 24)
        .overlay {
          Image(systemName: feedbackIcon(feedback.tone))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
        }

      Text(feedback.message)
        .font(.ancla(13, weight: .medium))
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(feedbackRowPadding)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(chromePanelInteractive)
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(color.opacity(0.22), lineWidth: 1)
        )
    )
  }

  private func temporaryUnlockBanner(_ temporaryUnlock: TemporaryUnlockState) -> some View {
    HStack(spacing: 10) {
      Circle()
        .fill(AnclaTheme.successText.opacity(0.16))
        .frame(width: 24, height: 24)
        .overlay {
          Image(systemName: "lock.open")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AnclaTheme.successText)
        }

      VStack(alignment: .leading, spacing: 3) {
        Text("Preset unlock active")
          .font(.ancla(13, weight: .medium))
          .foregroundStyle(AnclaTheme.successText)

        Text("\(temporaryUnlock.reason) • \(viewModel.temporaryUnlockRemainingSeconds)s left")
          .font(.ancla(12))
          .foregroundStyle(AnclaTheme.secondaryText)
      }

      Spacer(minLength: 0)
    }
    .padding(feedbackRowPadding)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(chromePanelInteractive)
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(AnclaTheme.successText.opacity(0.22), lineWidth: 1)
        )
    )
  }

  private var bottomDock: some View {
    ZStack(alignment: .top) {
      RoundedRectangle(cornerRadius: 34, style: .continuous)
        .fill(Color.black.opacity(0.96))
        .frame(height: 94)
        .overlay(
          RoundedRectangle(cornerRadius: 34, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )

      HStack(alignment: .bottom, spacing: 8) {
        sectionTabButton(.modes)
        sectionTabButton(.schedules)

        Spacer(minLength: 92)

        sectionTabButton(.anchors)
        sectionTabButton(.sessions)
      }
      .padding(.horizontal, 18)
      .padding(.top, 20)

      ZStack {
        Button(action: primaryAction) {
          Group {
            if viewModel.isActionInProgress(primaryActionID) {
              ProgressView()
                .tint(Color.white)
            } else {
              Image(systemName: "plus")
                .font(.system(size: 28, weight: .semibold))
            }
          }
          .foregroundStyle(Color.white)
          .frame(width: 84, height: 84)
          .background(
            Circle()
              .fill(primaryActionFill)
          )
          .overlay(
            Circle()
              .stroke(Color.white.opacity(0.08), lineWidth: 1)
          )
          .shadow(color: primaryActionShadow, radius: 24, y: 16)
        }
        .buttonStyle(.plain)
        .disabled(primaryActionDisabled || viewModel.isBusy)
        .opacity(primaryActionDisabled || viewModel.isBusy ? 0.55 : 1)
        .accessibilityLabel(primaryActionTitle)
        .accessibilityHint(primaryActionDetail)

        if primaryActionBlocksTapThrough {
          Circle()
            .fill(Color.black.opacity(0.001))
            .frame(width: 84, height: 84)
            .contentShape(Circle())
            .accessibilityHidden(true)
            .onTapGesture {}
        }
      }
      .offset(y: -18)
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 18)
    .background(AnclaTheme.background)
  }

  private func sectionTabButton(_ section: HomeSection) -> some View {
    let isSelected = selectedSection == section

    return Button {
      selectedSection = section
    } label: {
      VStack(spacing: 7) {
        Image(systemName: section.symbol)
          .font(.system(size: 18, weight: .semibold))
          .frame(height: 20)

        Text(section.title)
          .font(.ancla(11, weight: isSelected ? .semibold : .medium))
          .lineLimit(1)
      }
      .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.55))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
    }
    .buttonStyle(.plain)
  }

  private var renameAnchorSheet: some View {
    ZStack {
      AnclaBackgroundSurface(isWarningTinted: false)
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 20) {
        Capsule(style: .continuous)
          .fill(AnclaTheme.tertiaryText.opacity(0.6))
          .frame(width: 40, height: 4)
          .frame(maxWidth: .infinity)
          .padding(.top, 8)

        HStack {
          Button("Cancel") {
            renamingAnchorID = nil
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

          Text(currentRenamingAnchor?.displayName ?? "Rename anchor")
            .font(.ancla(18, weight: .bold))
            .foregroundStyle(AnclaTheme.primaryText)

          Spacer()

          Button("Save") {
            Task {
              guard let renamingAnchorID else {
                return
              }
              await viewModel.renamePairedSticker(renamingAnchorID, name: anchorNameDraft)
              if viewModel.lastError == nil {
                self.renamingAnchorID = nil
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
            if viewModel.isActionInProgress(.renameAnchor) {
              ProgressView()
                .tint(AnclaTheme.ctaText)
            }
          }
          .disabled(viewModel.isBusy)
          .opacity(viewModel.isBusy ? 0.7 : 1)
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

        if let lastError = viewModel.lastError {
          Text(lastError)
            .font(.ancla(12, weight: .medium))
            .foregroundStyle(AnclaTheme.errorText)
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

  private var nextStepLabel: String {
    switch nextStep {
    case .authorize:
      return "SETUP"
    case .unavailable:
      return "UNAVAILABLE"
    case .modeRequired:
      return "MODE"
    case .pairAnchor:
      return "PAIR"
    case .release:
      return "LIVE"
    case .arm:
      return "READY"
    case .rearm:
      return "READY AGAIN"
    }
  }

  private var activeScheduledPlan: ScheduledSessionPlan? {
    viewModel.snapshot.activeSession?.scheduledPlanID.flatMap(viewModel.scheduledPlan)
  }

  private var sessionSectionTitle: String {
    switch viewModel.snapshot.activeSession?.state {
    case .armed:
      return "Block is live"
    case .mismatchedTag:
      return "Wrong anchor"
    case .released:
      return "Block ended"
    case .idle, nil:
      return "No live block"
    }
  }

  private var sessionSectionBadge: String {
    if viewModel.activeTemporaryUnlock != nil {
      return "Open"
    }

    if viewModel.canReleaseActiveSession {
      return "Live"
    }

    return sessionValue
  }

  private var anchorValue: String {
    if let activePairedTag {
      return activePairedTag.displayName
    }

    switch viewModel.snapshot.pairedTags.count {
    case 0:
      return "Not paired"
    case 1:
      return viewModel.snapshot.pairedTags[0].displayName
    default:
      return "\(viewModel.snapshot.pairedTags.count) paired"
    }
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
      if let activeTemporaryUnlock = viewModel.activeTemporaryUnlock {
        return "\"\(activeTemporaryUnlock.reason)\" is open for \(viewModel.temporaryUnlockRemainingSeconds) more seconds. The block returns automatically when that timer ends."
      }

      return sessionWaitingDetail
    case .mismatchedTag:
      return "A different anchor was scanned. The session remains active. \(emergencyCountSentence)"
    case .released:
      return "The most recent session was released successfully."
    case .idle, nil:
      return "No active session is running right now."
    }
  }

  private var sessionAccent: Color {
    switch viewModel.snapshot.activeSession?.state {
    case .armed, .mismatchedTag:
      return viewModel.activeTemporaryUnlock == nil ? AnclaTheme.warningText : AnclaTheme.successText
    case .released:
      return AnclaTheme.successText
    default:
      return AnclaTheme.primaryText
    }
  }

  private var lockScreenEmergencyTitle: String {
    if viewModel.canUseEmergencyUnbrick {
      return "Failsafe"
    }

    if viewModel.canUseParagraphChallenge {
      return "Failsafe challenge"
    }

    return "Failsafe unavailable"
  }

  private var lockScreenEmergencyDetail: String {
    if viewModel.canUseEmergencyUnbrick {
      return emergencyUnbrickBadge
    }

    if viewModel.canUseParagraphChallenge {
      return "Type the passage exactly"
    }

    return "No release path ready"
  }

  private var lockScreenEmergencyEnabled: Bool {
    viewModel.canUseEmergencyUnbrick || viewModel.canUseParagraphChallenge
  }

  private var repoURL: URL? {
    URL(string: "https://github.com/Microck/ancla")
  }

  private var primaryActionTitle: String {
    switch nextStep {
    case .authorize:
      return "Enable App Controls"
    case .unavailable:
      return "NFC Unavailable"
    case .modeRequired:
      return "Mode Required"
    case .pairAnchor:
      return "Pair Anchor"
    case .release:
      return "End Block"
    case .arm:
      return "Start Block"
    case .rearm:
      return "Start New Block"
    }
  }

  private var primaryActionDetail: String {
    switch nextStep {
    case .authorize:
      return "Give Ancla the permission it needs before the first block."
    case .unavailable:
      return "This device cannot scan NFC anchors."
    case .modeRequired:
      return "Save a mode in the Mode section before starting a block."
    case .pairAnchor:
      return "Scan the first release anchor."
    case .release:
      if let activePairedTag {
        return "\(activePairedTag.displayName) must be scanned to end the live block."
      }
      return "Scan the paired release anchor to end the live block."
    case .arm:
      if let currentMode {
        return "Start \(currentMode.name) with a paired anchor."
      }
      return "Start the selected block with a paired anchor."
    case .rearm:
      return "Start another block with the selected mode."
    }
  }

  private var primaryActionSymbol: String {
    switch nextStep {
    case .authorize:
      return "checkmark.shield"
    case .unavailable:
      return "exclamationmark.triangle"
    case .modeRequired:
      return "plus"
    case .pairAnchor:
      return "dot.radiowaves.left.and.right"
    case .release:
      return "lock.open"
    case .arm:
      return "bolt.fill"
    case .rearm:
      return "arrow.clockwise"
    }
  }

  private var primaryActionID: AppActionID {
    switch nextStep {
    case .authorize:
      return .authorize
    case .unavailable:
      return .refresh
    case .modeRequired:
      return .saveMode
    case .pairAnchor:
      return .pairAnchor
    case .release:
      return .releaseSession
    case .arm, .rearm:
      return .armSession
    }
  }

  private var primaryActionDisabled: Bool {
    switch nextStep {
    case .authorize:
      return false
    case .unavailable:
      return true
    case .modeRequired:
      return true
    case .pairAnchor:
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
    case .unavailable:
      break
    case .modeRequired:
      selectedSection = .modes
    case .pairAnchor:
      Task { await viewModel.pairSticker() }
    case .release:
      Task { await viewModel.releaseActiveSession() }
    case .arm, .rearm:
      Task { await viewModel.armSelectedMode() }
    }
  }

  private func handleLockScreenEmergencyAction() {
    if viewModel.canUseEmergencyUnbrick {
      Task { await viewModel.useEmergencyUnbrick() }
      isUnlockMenuPresented = false
      return
    }

    if viewModel.canUseParagraphChallenge {
      viewModel.prepareParagraphChallenge()
      isParagraphChallengePresented = true
      isUnlockMenuPresented = false
    }
  }

  private var nextStep: NextStep {
    if !viewModel.snapshot.isAuthorized {
      return .authorize
    }

    if !viewModel.isNFCAvailable {
      return .unavailable
    }

    if viewModel.snapshot.pairedTags.isEmpty {
      return .pairAnchor
    }

    if !viewModel.hasAnyMode {
      return .modeRequired
    }

    if viewModel.canReleaseActiveSession {
      return .release
    }

    if viewModel.snapshot.activeSession?.state == .released {
      return .rearm
    }

    return .arm
  }

  private var surfaceDivider: some View {
    Rectangle()
      .fill(chromePanelStroke.opacity(0.55))
      .frame(height: 1)
  }

  private func rowMenuLabel() -> some View {
    Image(systemName: "ellipsis")
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(AnclaTheme.tertiaryText)
      .frame(width: 28, height: 28)
      .contentShape(Rectangle())
  }

  private func feedbackIcon(_ tone: ActionFeedbackTone) -> String {
    switch tone {
    case .neutral:
      return "info"
    case .success:
      return "checkmark"
    case .error:
      return "exclamationmark"
    }
  }

  private func historyDurationLabel(for entry: SessionHistoryEntry) -> String {
    let seconds = Int(entry.duration.rounded())
    if seconds < 60 {
      return "\(seconds)s"
    }

    let minutes = seconds / 60
    if minutes < 60 {
      return "\(minutes)m"
    }

    let hours = minutes / 60
    let remainingMinutes = minutes % 60
    if remainingMinutes == 0 {
      return "\(hours)h"
    }

    return "\(hours)h \(remainingMinutes)m"
  }

  private func historySubtitle(for entry: SessionHistoryEntry) -> String {
    "\(historyContextLabel(for: entry)) • \(entry.releasedAt.formatted(date: .abbreviated, time: .shortened))"
  }

  private func historyContextLabel(for entry: SessionHistoryEntry) -> String {
    switch entry.releaseMethod {
    case .anchor:
      return "Released via \(entry.pairedTagName)"
    case .emergencyUnbrick:
      return "Emergency unbrick for \(entry.pairedTagName)"
    case .paragraphChallenge:
      return "Failsafe challenge for \(entry.pairedTagName)"
    case .schedule:
      return "Ended on schedule for \(entry.pairedTagName)"
    }
  }

  private var emergencyUnbrickTitle: String {
    let count = viewModel.snapshot.emergencyUnbricksRemaining
    return count == 1 ? "1 failsafe left" : "\(count) failsafes left"
  }

  private var emergencyUnbrickBadge: String {
    let count = viewModel.snapshot.emergencyUnbricksRemaining
    return count == 0 ? "Empty" : "\(count) left"
  }

  private var emergencyUnbrickDetail: String {
    if viewModel.snapshot.emergencyUnbricksRemaining == 0 {
      if viewModel.canUseParagraphChallenge {
        return "Normal failsafes are empty. The typing challenge is the only non-anchor release path."
      }

      return "Normal failsafes are empty. The paired anchor is now required."
    }

    if viewModel.canUseEmergencyUnbrick {
      return "Use one to end the current session without the paired anchor."
    }

    return "Keep these for moments when you cannot reach the paired anchor."
  }

  private var emergencyUnbrickAccent: Color {
    viewModel.snapshot.emergencyUnbricksRemaining == 0 ? AnclaTheme.errorText : AnclaTheme.primaryText
  }

  private var emergencyCountSentence: String {
    let count = viewModel.snapshot.emergencyUnbricksRemaining
    if count == 1 {
      return "1 failsafe remains."
    }

    return "\(count) failsafes remain."
  }

  private var sessionWaitingDetail: String {
    if let activePairedTag {
      if viewModel.snapshot.activeSession?.scheduledPlanID != nil {
        return "This scheduled session is active now. \(activePairedTag.displayName) is still the early release path. \(emergencyCountSentence)"
      }

      return "The current session remains active until \(activePairedTag.displayName) is scanned. \(emergencyCountSentence)"
    }

    return "The current session remains active until the release anchor is scanned. \(emergencyCountSentence)"
  }

  private var paragraphChallengeDetail: String {
    if !viewModel.paragraphChallengeEnabled {
      return "Turn this on to keep the typing unlock ready."
    }

    if viewModel.canUseParagraphChallenge {
      return "Failsafes are empty. Type the stored passage exactly."
    }

    return "This appears only after failsafes hit zero."
  }

  private var renameAnchorPresented: Binding<Bool> {
    Binding(
      get: { renamingAnchorID != nil },
      set: { isPresented in
        if !isPresented {
          renamingAnchorID = nil
        }
      }
    )
  }

  private var currentRenamingAnchor: PairedTag? {
    guard let renamingAnchorID else {
      return nil
    }

    return viewModel.pairedTag(renamingAnchorID)
  }

  private var activePairedTag: PairedTag? {
    viewModel.activePairedTag
  }

  private func isActiveAnchor(_ tagID: UUID) -> Bool {
    viewModel.activePairedTag?.id == tagID
  }

  private func pairedAnchorDetail(for pairedTag: PairedTag) -> String {
    if isActiveAnchor(pairedTag.id) {
      return "This anchor releases the current block."
    }

    return "Ready to start or release blocks on this iPhone."
  }

  private func pairedAnchorBadge(for pairedTag: PairedTag) -> String {
    isActiveAnchor(pairedTag.id) ? "Active" : "Paired"
  }

  private func removeAnchorDetail(for pairedTag: PairedTag) -> String {
    if isActiveAnchor(pairedTag.id) {
      return "Remove this anchor and clear the active session from this iPhone."
    }

    return "Remove this paired anchor from this iPhone."
  }

  private var canCreateScheduledPlan: Bool {
    !viewModel.modesForDisplay.isEmpty && !viewModel.pairedTagsForDisplay.isEmpty
  }

  private var scheduledSessionsEmptyDetail: String {
    if !canCreateScheduledPlan {
      return "Pair an anchor and save a mode first."
    }

    return "Auto-start a saved mode on chosen days."
  }

  private func scheduledPlanTitle(for plan: ScheduledSessionPlan) -> String {
    let modeName = viewModel.snapshot.modes.first(where: { $0.id == plan.modeId })?.name ?? "Missing mode"
    return "\(modeName) • \(scheduledPlanDaysLabel(for: plan))"
  }

  private func scheduledPlanDetail(for plan: ScheduledSessionPlan) -> String {
    let anchorName = viewModel.pairedTag(plan.pairedTagId)?.displayName ?? "Missing anchor"
    var details = [scheduledPlanTimeLabel(for: plan)]

    if isScheduledPlanActive(plan) {
      details.append("Running now")
    } else if let nextStart = nextScheduledStartLabel(for: plan) {
      details.append(nextStart)
    }

    details.append("Release early with \(anchorName)")
    return details.joined(separator: " • ")
  }

  private func scheduledPlanBadge(for plan: ScheduledSessionPlan) -> String {
    if isScheduledPlanActive(plan) {
      return "Active"
    }

    if !plan.isEnabled {
      return "Off"
    }

    return nextScheduledStartLabel(for: plan) == nil ? "On" : "Upcoming"
  }

  private func scheduledPlanAccent(for plan: ScheduledSessionPlan) -> Color {
    if isScheduledPlanActive(plan) {
      return AnclaTheme.warningText
    }

    return plan.isEnabled ? AnclaTheme.primaryText : AnclaTheme.secondaryText
  }

  private func removeScheduleDetail(for plan: ScheduledSessionPlan) -> String {
    if isScheduledPlanActive(plan) {
      return "Remove this schedule and release the active scheduled session from this iPhone."
    }

    return "Remove this saved recurring schedule from this iPhone."
  }

  private func isScheduledPlanActive(_ plan: ScheduledSessionPlan) -> Bool {
    viewModel.snapshot.activeSession?.scheduledPlanID == plan.id && viewModel.canReleaseActiveSession
  }

  private func scheduledPlanDaysLabel(for plan: ScheduledSessionPlan) -> String {
    let names = plan.weekdayNumbers.compactMap(weekdayShortName)
    guard !names.isEmpty else {
      return "No days"
    }

    if names.count == 7 {
      return "Every day"
    }

    return names.joined(separator: ", ")
  }

  private func weekdayShortName(_ weekdayNumber: Int) -> String? {
    switch weekdayNumber {
    case 1:
      return "Sun"
    case 2:
      return "Mon"
    case 3:
      return "Tue"
    case 4:
      return "Wed"
    case 5:
      return "Thu"
    case 6:
      return "Fri"
    case 7:
      return "Sat"
    default:
      return nil
    }
  }

  private func scheduledPlanTimeLabel(for plan: ScheduledSessionPlan) -> String {
    "\(formattedScheduleTime(plan.startMinuteOfDay)) - \(formattedScheduleTime(plan.endMinuteOfDay))"
  }

  private func formattedScheduleTime(_ minutes: Int) -> String {
    let hours = minutes / 60
    let remainder = minutes % 60
    let isPM = hours >= 12
    let displayHour = ((hours + 11) % 12) + 1
    return "\(displayHour):" + String(format: "%02d", remainder) + (isPM ? " PM" : " AM")
  }

  private func nextScheduledStartLabel(for plan: ScheduledSessionPlan) -> String? {
    guard plan.isEnabled, !plan.weekdayNumbers.isEmpty else {
      return nil
    }

    let calendar = Calendar.current
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)

    for dayOffset in 0..<7 {
      guard let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else {
        continue
      }

      let weekday = calendar.component(.weekday, from: candidateDay)
      guard plan.weekdayNumbers.contains(weekday) else {
        continue
      }

      let todayMinutes = calendar.dateComponents([.hour, .minute], from: now)
      let currentMinuteOfDay = (todayMinutes.hour ?? 0) * 60 + (todayMinutes.minute ?? 0)
      if dayOffset == 0 && currentMinuteOfDay >= plan.startMinuteOfDay {
        continue
      }

      guard let start = calendar.date(byAdding: .minute, value: plan.startMinuteOfDay, to: candidateDay) else {
        continue
      }

      let weekdayLabel = dayOffset == 0 ? "Today" : weekdayShortName(weekday) ?? start.formatted(.dateTime.weekday(.abbreviated))
      return "\(weekdayLabel) at \(start.formatted(date: .omitted, time: .shortened))"
    }

    return nil
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
