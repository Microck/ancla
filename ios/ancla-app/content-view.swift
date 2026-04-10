#if !SIDELOAD_LITE
import FamilyControls
#endif
import SwiftUI

private enum NextStep {
  case authorize
  case unavailable
  case pairAnchor
  case createMode
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
      return "Sessions"
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
      return "clock.arrow.circlepath"
    }
  }
}

struct ContentView: View {
  @Bindable var viewModel: AppViewModel
  @Environment(\.scenePhase) private var scenePhase

  private let bottomActionBarClearance: CGFloat = 144
  private let sectionColumns = [
    GridItem(.flexible(), spacing: 14),
    GridItem(.flexible(), spacing: 14),
  ]

  @State private var activeSection: HomeSection?
  @State private var isModeEditorPresented = false
  @State private var isScheduleEditorPresented = false
  @State private var isShortcutGuidesPresented = false
  @State private var renamingAnchorID: UUID?
  @State private var anchorNameDraft = ""

  var body: some View {
    NavigationStack {
      ZStack {
        AnclaTheme.background
          .ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 20) {
            header
            headlineSection
            overviewStrip

            if let feedback = viewModel.feedback {
              feedbackRow(feedback)
            }

            sectionGrid
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 24)
          .padding(.top, 24)
          .padding(.bottom, bottomActionBarClearance)
        }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        bottomActionBar
      }
      .toolbar(.hidden, for: .navigationBar)
      .preferredColorScheme(.dark)
      .sheet(item: $activeSection) { section in
        sectionSheet(section)
          .presentationBackground(.clear)
      }
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
            .fill(AnclaTheme.panelRaised)
            .overlay(
              Capsule(style: .continuous)
                .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
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
                .fill(AnclaTheme.panelRaised)
                .overlay(
                  Circle()
                    .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
                )
            )
        }
        .accessibilityLabel("Open GitHub repository")
      }
    }
  }

  private var headlineSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        if viewModel.currentModeIsStrict {
          statusBadge("STRICT", color: AnclaTheme.warningText)
        }

        statusBadge(nextStepLabel, color: sessionAccent)
      }

      Text(viewModel.diagnostics.headline)
        .font(.ancla(38, weight: .medium))
        .foregroundStyle(AnclaTheme.primaryText)
        .lineLimit(2)

      Text(compactMessage)
        .font(.ancla(15))
        .foregroundStyle(AnclaTheme.secondaryText)
        .frame(maxWidth: 360, alignment: .leading)
    }
  }

  private var overviewStrip: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) {
        overviewTile(
          label: "Mode",
          value: currentMode?.name ?? "None",
          detail: modeOverviewDetail,
          accentColor: viewModel.currentModeIsStrict ? AnclaTheme.warningText : AnclaTheme.primaryText,
          highlight: currentMode != nil
        )

        overviewTile(
          label: "Anchor",
          value: anchorValue,
          detail: anchorOverviewDetail,
          accentColor: activePairedTag == nil ? AnclaTheme.primaryText : AnclaTheme.warningText,
          highlight: !viewModel.snapshot.pairedTags.isEmpty
        )

        overviewTile(
          label: "Session",
          value: sessionValue,
          detail: sessionOverviewDetail,
          accentColor: sessionAccent,
          highlight: viewModel.activeSessionIsBlocking
        )
      }

      VStack(spacing: 12) {
        overviewTile(
          label: "Mode",
          value: currentMode?.name ?? "None",
          detail: modeOverviewDetail,
          accentColor: viewModel.currentModeIsStrict ? AnclaTheme.warningText : AnclaTheme.primaryText,
          highlight: currentMode != nil
        )

        overviewTile(
          label: "Anchor",
          value: anchorValue,
          detail: anchorOverviewDetail,
          accentColor: activePairedTag == nil ? AnclaTheme.primaryText : AnclaTheme.warningText,
          highlight: !viewModel.snapshot.pairedTags.isEmpty
        )

        overviewTile(
          label: "Session",
          value: sessionValue,
          detail: sessionOverviewDetail,
          accentColor: sessionAccent,
          highlight: viewModel.activeSessionIsBlocking
        )
      }
    }
  }

  private var sectionGrid: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Sections")
        .font(.ancla(11, weight: .medium))
        .foregroundStyle(AnclaTheme.tertiaryText)
        .tracking(1.2)

      LazyVGrid(columns: sectionColumns, spacing: 14) {
        ForEach(HomeSection.allCases) { section in
          Button {
            activeSection = section
          } label: {
            VStack(alignment: .leading, spacing: 14) {
              HStack(alignment: .top) {
                ZStack {
                  Circle()
                    .fill(sectionAccent(for: section).opacity(0.16))
                    .frame(width: 40, height: 40)

                  Image(systemName: section.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(sectionAccent(for: section))
                }

                Spacer(minLength: 10)

                Text(sectionBadge(for: section))
                  .font(.ancla(11, weight: .medium))
                  .foregroundStyle(sectionBadgeColor(for: section))
                  .multilineTextAlignment(.trailing)
                  .lineLimit(2)
              }

              Spacer(minLength: 0)

              VStack(alignment: .leading, spacing: 6) {
                Text(section.title)
                  .font(.ancla(18, weight: .medium))
                  .foregroundStyle(AnclaTheme.primaryText)

                Text(sectionSummary(for: section))
                  .font(.ancla(13))
                  .foregroundStyle(AnclaTheme.secondaryText)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .lineLimit(3)
              }
            }
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .padding(18)
          }
          .buttonStyle(
            AnclaPressableButtonStyle(
              background: sectionBackground(for: section),
              pressedBackground: sectionPressedBackground(for: section),
              stroke: sectionStroke(for: section),
              cornerRadius: 24,
              scale: 0.992
            )
          )
        }
      }
    }
  }

  @ViewBuilder
  private func sectionSheet(_ section: HomeSection) -> some View {
    switch section {
    case .modes:
      HomeSectionSheet(
        title: "Modes",
        subtitle: "Choose what the next block should do."
      ) {
        sectionFeedback
        modesSectionContent
      }
    case .anchors:
      HomeSectionSheet(
        title: "Anchors",
        subtitle: "Manage the NFC anchors tied to this iPhone."
      ) {
        sectionFeedback
        anchorsSectionContent
      }
    case .schedules:
      HomeSectionSheet(
        title: "Schedules",
        subtitle: "Start saved modes on a recurring window."
      ) {
        sectionFeedback
        schedulesSectionContent
      }
    case .sessions:
      HomeSectionSheet(
        title: "Sessions",
        subtitle: "Check live state, history, and the emergency failsafe."
      ) {
        sectionFeedback
        sessionsSectionContent
      }
    }
  }

  @ViewBuilder
  private var sectionFeedback: some View {
    if let feedback = viewModel.feedback {
      feedbackRow(feedback)
    }
  }

  private var modesSectionContent: some View {
    VStack(spacing: 12) {
      if viewModel.modesForDisplay.isEmpty {
        informativeRow(
          title: "No modes saved",
          detail: "Create the first mode you want ready before starting a block.",
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
          .disabled(viewModel.isBusy)
        }
      }

      if let currentMode {
        Button {
          viewModel.prepareDraftForEditingMode(currentMode.id)
          isModeEditorPresented = true
        } label: {
          actionRow(
            icon: "square.and.pencil",
            title: "Edit selected mode",
            detail: "Adjust the mode that will start next.",
            isLoading: false
          )
        }
        .buttonStyle(AnclaPressableButtonStyle())
        .disabled(viewModel.isBusy)
      }

      Button {
        viewModel.prepareDraftForNewMode()
        isModeEditorPresented = true
      } label: {
        actionRow(
          icon: "plus",
          title: "Create mode",
          detail: "Add another saved mode for a different blocking setup.",
          isLoading: false
        )
      }
      .buttonStyle(AnclaPressableButtonStyle())
      .disabled(viewModel.isBusy)
    }
  }

  private var anchorsSectionContent: some View {
    VStack(spacing: 12) {
      if viewModel.pairedTagsForDisplay.isEmpty {
        informativeRow(
          title: "No anchor paired",
          detail: "Pair one NFC anchor to set the physical release key for this iPhone.",
          accentColor: AnclaTheme.primaryText,
          highlight: false
        )
      } else {
        ForEach(viewModel.pairedTagsForDisplay) { pairedTag in
          pairedAnchorCard(pairedTag)
        }
      }

      Button {
        Task { await viewModel.pairSticker() }
      } label: {
        actionRow(
          icon: "plus",
          title: viewModel.pairedTagsForDisplay.isEmpty ? "Pair anchor" : "Pair another anchor",
          detail: "Scan an NFC anchor that can start or release blocks on this iPhone.",
          isLoading: viewModel.isActionInProgress(.pairAnchor)
        )
      }
      .buttonStyle(AnclaPressableButtonStyle())
      .disabled(viewModel.isBusy)
    }
  }

  private var schedulesSectionContent: some View {
    VStack(spacing: 12) {
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
          scheduledPlanCard(plan)
        }
      }

      Button {
        viewModel.prepareDraftForNewSchedule()
        isScheduleEditorPresented = true
      } label: {
        actionRow(
          icon: "calendar.badge.plus",
          title: "Create schedule",
          detail: "Auto-start a saved mode on selected weekdays.",
          isLoading: false
        )
      }
      .buttonStyle(AnclaPressableButtonStyle())
      .disabled(viewModel.isBusy || !canCreateScheduledPlan)
      .opacity(viewModel.isBusy || !canCreateScheduledPlan ? 0.65 : 1)
    }
  }

  private var sessionsSectionContent: some View {
    VStack(spacing: 12) {
      informativeRow(
        title: sessionSectionTitle,
        detail: sessionDetail,
        accentColor: sessionAccent,
        highlight: viewModel.activeSessionIsBlocking,
        trailingText: sessionSectionBadge
      )

      informativeRow(
        title: emergencyUnbrickTitle,
        detail: emergencyUnbrickDetail,
        accentColor: emergencyUnbrickAccent,
        highlight: viewModel.snapshot.emergencyUnbricksRemaining > 0,
        trailingText: emergencyUnbrickBadge
      )

      if viewModel.canUseEmergencyUnbrick || viewModel.snapshot.emergencyUnbricksRemaining == 0 {
        Button {
          Task { await viewModel.useEmergencyUnbrick() }
        } label: {
          actionRow(
            icon: "bolt.horizontal.circle",
            title: "Use emergency unbrick",
            detail: "Release the current session without scanning the paired anchor.",
            isLoading: viewModel.isActionInProgress(.emergencyUnbrick),
            isDestructive: true
          )
        }
        .buttonStyle(
          AnclaPressableButtonStyle(
            background: AnclaTheme.panelInteractive,
            pressedBackground: AnclaTheme.panelRaised,
            stroke: AnclaTheme.errorText.opacity(0.32)
          )
        )
        .disabled(viewModel.isBusy || !viewModel.canUseEmergencyUnbrick)
        .opacity(viewModel.canUseEmergencyUnbrick ? 1 : 0.65)
      }

      if viewModel.currentModeIsStrict {
        informativeRow(
          title: strictModeTitle,
          detail: strictModeDetail,
          accentColor: AnclaTheme.warningText,
          highlight: viewModel.canReleaseActiveSession,
          trailingText: "Strict"
        )

        Button {
          isShortcutGuidesPresented = true
        } label: {
          actionRow(
            icon: "bolt.horizontal.circle",
            title: "Review Apple app guides",
            detail: "Finish the Shortcuts automations that close the obvious loopholes.",
            isLoading: false
          )
        }
        .buttonStyle(AnclaPressableButtonStyle())
        .disabled(viewModel.isBusy)
      }

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

  private func overviewTile(
    label: String,
    value: String,
    detail: String,
    accentColor: Color,
    highlight: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(label)
        .font(.ancla(11, weight: .medium))
        .foregroundStyle(AnclaTheme.tertiaryText)
        .tracking(1.1)

      Text(value)
        .font(.ancla(18, weight: .medium))
        .foregroundStyle(accentColor)
        .lineLimit(1)

      Text(detail)
        .font(.ancla(12))
        .foregroundStyle(AnclaTheme.secondaryText)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(highlight ? AnclaTheme.panelRaised : AnclaTheme.panel)
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(
              highlight ? accentColor.opacity(0.28) : AnclaTheme.panelStroke.opacity(0.75),
              lineWidth: 1
            )
        )
    )
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

  private func pairedAnchorCard(_ pairedTag: PairedTag) -> some View {
    VStack(spacing: 12) {
      informativeRow(
        title: pairedTag.displayName,
        detail: pairedAnchorDetail(for: pairedTag),
        accentColor: isActiveAnchor(pairedTag.id) ? AnclaTheme.warningText : AnclaTheme.primaryText,
        highlight: isActiveAnchor(pairedTag.id),
        trailingText: pairedAnchorBadge(for: pairedTag)
      )

      Button {
        renamingAnchorID = pairedTag.id
      } label: {
        actionRow(
          icon: "pencil.line",
          title: "Rename \(pairedTag.displayName)",
          detail: "Update the visible label for this paired anchor.",
          isLoading: false
        )
      }
      .buttonStyle(AnclaPressableButtonStyle())
      .disabled(viewModel.isBusy)

      Button {
        Task { await viewModel.unpairSticker(pairedTag.id) }
      } label: {
        actionRow(
          icon: "trash",
          title: "Remove \(pairedTag.displayName)",
          detail: removeAnchorDetail(for: pairedTag),
          isLoading: viewModel.isActionInProgress(.removeAnchor),
          isDestructive: true
        )
      }
      .buttonStyle(
        AnclaPressableButtonStyle(
          background: AnclaTheme.panelInteractive,
          pressedBackground: AnclaTheme.panelRaised,
          stroke: AnclaTheme.errorText.opacity(0.32)
        )
      )
      .disabled(viewModel.isBusy)
    }
  }

  private func scheduledPlanCard(_ plan: ScheduledSessionPlan) -> some View {
    VStack(spacing: 12) {
      informativeRow(
        title: scheduledPlanTitle(for: plan),
        detail: scheduledPlanDetail(for: plan),
        accentColor: scheduledPlanAccent(for: plan),
        highlight: isScheduledPlanActive(plan),
        trailingText: scheduledPlanBadge(for: plan)
      )

      Button {
        viewModel.prepareDraftForEditingScheduledPlan(plan.id)
        isScheduleEditorPresented = true
      } label: {
        actionRow(
          icon: "square.and.pencil",
          title: "Edit schedule",
          detail: "Adjust the weekdays, window, mode, or release anchor.",
          isLoading: false
        )
      }
      .buttonStyle(AnclaPressableButtonStyle())
      .disabled(viewModel.isBusy)

      Button {
        Task { await viewModel.deleteScheduledPlan(plan.id) }
      } label: {
        actionRow(
          icon: "trash",
          title: "Remove schedule",
          detail: removeScheduleDetail(for: plan),
          isLoading: viewModel.isActionInProgress(.removeSchedule),
          isDestructive: true
        )
      }
      .buttonStyle(
        AnclaPressableButtonStyle(
          background: AnclaTheme.panelInteractive,
          pressedBackground: AnclaTheme.panelRaised,
          stroke: AnclaTheme.errorText.opacity(0.32)
        )
      )
      .disabled(viewModel.isBusy)
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

  private func actionRow(
    icon: String,
    title: String,
    detail: String,
    isLoading: Bool,
    isDestructive: Bool = false
  ) -> some View {
    HStack(alignment: .center, spacing: 14) {
      ZStack {
        Circle()
          .fill((isDestructive ? AnclaTheme.errorText : AnclaTheme.accentFill).opacity(0.14))
          .frame(width: 34, height: 34)

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
    .padding(16)
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

      if mode.isStrict {
        Text("Strict")
          .font(.ancla(12, weight: .medium))
          .foregroundStyle(AnclaTheme.warningText)
      }

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
        .fill(AnclaTheme.panelInteractive)
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(color.opacity(0.22), lineWidth: 1)
        )
    )
  }

  private var bottomActionBar: some View {
    VStack(spacing: 0) {
      Button(action: primaryAction) {
        VStack(alignment: .leading, spacing: 10) {
          HStack(alignment: .firstTextBaseline) {
            Text("Ancla")
              .font(.ancla(28, weight: .semibold))

            Spacer(minLength: 12)

            if viewModel.isActionInProgress(primaryActionID) {
              ProgressView()
                .tint(AnclaTheme.ctaText)
            } else {
              Image(systemName: primaryActionSymbol)
                .font(.system(size: 18, weight: .semibold))
            }
          }

          VStack(alignment: .leading, spacing: 4) {
            Text(primaryActionTitle)
              .font(.ancla(15, weight: .semibold))

            Text(primaryActionDetail)
              .font(.ancla(12, weight: .medium))
              .foregroundStyle(AnclaTheme.ctaText.opacity(0.72))
              .lineLimit(2)
          }
        }
        .foregroundStyle(AnclaTheme.ctaText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 94)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(AnclaTheme.ctaFill)
        )
      }
      .buttonStyle(.plain)
      .disabled(primaryActionDisabled || viewModel.isBusy)
      .opacity(primaryActionDisabled || viewModel.isBusy ? 0.6 : 1)
      .accessibilityLabel(primaryActionTitle)
      .accessibilityHint(primaryActionDetail)
    }
    .padding(.horizontal, 24)
    .padding(.top, 12)
    .padding(.bottom, 18)
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
            renamingAnchorID = nil
          }
          .font(.ancla(14, weight: .medium))
          .foregroundStyle(AnclaTheme.secondaryText)
          .padding(.horizontal, 14)
          .frame(height: 38)
          .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(AnclaTheme.panelInteractive)
              .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
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

  private var modeOverviewDetail: String {
    guard let currentMode else {
      return "Save one mode"
    }

    return viewModel.selectionSummary(for: currentMode)
  }

  private var anchorOverviewDetail: String {
    if let activePairedTag {
      return "\(activePairedTag.displayName) releases"
    }

    switch viewModel.snapshot.pairedTags.count {
    case 0:
      return "Pair one anchor"
    case 1:
      return "1 paired"
    default:
      return "\(viewModel.snapshot.pairedTags.count) paired"
    }
  }

  private var sessionOverviewDetail: String {
    switch viewModel.snapshot.activeSession?.state {
    case .armed:
      return "Anchor required"
    case .mismatchedTag:
      return "Wrong anchor scanned"
    case .released:
      return "Recently ended"
    case .idle, nil:
      return "Nothing live"
    }
  }

  private var compactMessage: String {
    switch nextStep {
    case .authorize:
      return "Grant App Controls once, then save a mode and pair an anchor."
    case .unavailable:
      return "This device cannot scan NFC anchors, so pairing and release stay unavailable here."
    case .pairAnchor:
      return "Pair one anchor to move the release path off the screen and into the room."
    case .createMode:
      return "Save one mode so Ancla has a block ready to arm."
    case .release:
      if let activePairedTag {
        return "\(activePairedTag.displayName) is the only anchor that can end this live block."
      }
      return "Use the same paired anchor to end the live block."
    case .arm:
      if let currentMode {
        return "\"\(currentMode.name)\" is ready. Start it when you want the block to go live."
      }
      return "Choose a mode, then start the block."
    case .rearm:
      return "The last block ended cleanly. Start the next one when you are ready."
    }
  }

  private var nextStepLabel: String {
    switch nextStep {
    case .authorize:
      return "SETUP"
    case .unavailable:
      return "UNAVAILABLE"
    case .pairAnchor:
      return "PAIR"
    case .createMode:
      return "MODE"
    case .release:
      return "LIVE"
    case .arm:
      return "READY"
    case .rearm:
      return "READY AGAIN"
    }
  }

  private func sectionSummary(for section: HomeSection) -> String {
    switch section {
    case .modes:
      if let currentMode {
        return viewModel.selectionSummary(for: currentMode)
      }
      return "Choose and edit the block you want ready next."
    case .anchors:
      if let activePairedTag {
        return "\(activePairedTag.displayName) is the active release anchor."
      }
      if viewModel.snapshot.pairedTags.isEmpty {
        return "Pair the first NFC anchor for this iPhone."
      }
      return "Rename, remove, or add paired anchors."
    case .schedules:
      if let activePlan = activeScheduledPlan {
        return scheduledPlanDetail(for: activePlan)
      }
      if let nextPlan = viewModel.scheduledPlansForDisplay.first {
        return scheduledPlanDetail(for: nextPlan)
      }
      return "Auto-start saved modes on chosen weekdays."
    case .sessions:
      if viewModel.activeSessionIsBlocking {
        return sessionDetail
      }
      if let recentEntry = viewModel.recentSessionHistory.first {
        return historySubtitle(for: recentEntry)
      }
      return "See live state, past blocks, and the emergency failsafe."
    }
  }

  private func sectionBadge(for section: HomeSection) -> String {
    switch section {
    case .modes:
      if viewModel.currentModeIsStrict {
        return "Strict"
      }
      return currentMode == nil ? "Setup" : "Ready"
    case .anchors:
      if activePairedTag != nil {
        return "Active"
      }
      let count = viewModel.snapshot.pairedTags.count
      return count == 0 ? "None" : "\(count)"
    case .schedules:
      if activeScheduledPlan != nil {
        return "Active"
      }
      let count = viewModel.scheduledPlansForDisplay.count
      return count == 0 ? "Off" : "\(count)"
    case .sessions:
      if viewModel.canReleaseActiveSession {
        return "Blocking"
      }
      return viewModel.recentSessionHistory.isEmpty ? "Idle" : "Recent"
    }
  }

  private func sectionBadgeColor(for section: HomeSection) -> Color {
    switch section {
    case .modes:
      return viewModel.currentModeIsStrict ? AnclaTheme.warningText : AnclaTheme.secondaryText
    case .anchors:
      return activePairedTag == nil ? AnclaTheme.secondaryText : AnclaTheme.warningText
    case .schedules:
      return activeScheduledPlan == nil ? AnclaTheme.secondaryText : AnclaTheme.warningText
    case .sessions:
      return viewModel.canReleaseActiveSession ? AnclaTheme.warningText : AnclaTheme.secondaryText
    }
  }

  private func sectionAccent(for section: HomeSection) -> Color {
    switch section {
    case .modes:
      return viewModel.currentModeIsStrict ? AnclaTheme.warningText : AnclaTheme.accentFill
    case .anchors:
      return activePairedTag == nil ? AnclaTheme.accentFill : AnclaTheme.warningText
    case .schedules:
      return activeScheduledPlan == nil ? AnclaTheme.accentFill : AnclaTheme.warningText
    case .sessions:
      return viewModel.activeSessionIsBlocking ? sessionAccent : AnclaTheme.accentFill
    }
  }

  private func sectionBackground(for section: HomeSection) -> Color {
    switch section {
    case .modes:
      return currentMode == nil ? AnclaTheme.panel : AnclaTheme.panelRaised
    case .anchors:
      return activePairedTag == nil ? AnclaTheme.panel : AnclaTheme.panelRaised
    case .schedules:
      return activeScheduledPlan == nil ? AnclaTheme.panel : AnclaTheme.panelRaised
    case .sessions:
      return viewModel.activeSessionIsBlocking ? AnclaTheme.panelRaised : AnclaTheme.panel
    }
  }

  private func sectionPressedBackground(for section: HomeSection) -> Color {
    switch section {
    case .sessions where viewModel.activeSessionIsBlocking:
      return AnclaTheme.panelInteractive
    default:
      return AnclaTheme.panelRaised
    }
  }

  private func sectionStroke(for section: HomeSection) -> Color {
    let accent = sectionAccent(for: section)
    switch section {
    case .modes where currentMode != nil:
      return accent.opacity(0.28)
    case .anchors where activePairedTag != nil:
      return accent.opacity(0.28)
    case .schedules where activeScheduledPlan != nil:
      return accent.opacity(0.28)
    case .sessions where viewModel.activeSessionIsBlocking:
      return accent.opacity(0.28)
    default:
      return AnclaTheme.panelStroke.opacity(0.75)
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
      return sessionWaitingDetail
    case .mismatchedTag:
      if viewModel.currentModeIsStrict {
        return "A different anchor was scanned. Strict mode stays active until the right anchor is used. \(emergencyCountSentence)"
      }

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
      return AnclaTheme.warningText
    case .released:
      return AnclaTheme.successText
    default:
      return AnclaTheme.primaryText
    }
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
    case .pairAnchor:
      return "Pair Anchor"
    case .createMode:
      return "Create Mode"
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
    case .pairAnchor:
      return "Scan the first release anchor."
    case .createMode:
      return "Save one mode so the first block has a target."
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
    case .pairAnchor:
      return "dot.radiowaves.left.and.right"
    case .createMode:
      return "plus"
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
    case .pairAnchor:
      return .pairAnchor
    case .createMode:
      return .saveMode
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
    case .unavailable:
      break
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

    if !viewModel.isNFCAvailable {
      if !viewModel.hasAnyMode {
        return .createMode
      }

      return .unavailable
    }

    if viewModel.snapshot.pairedTags.isEmpty {
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

  private var surfaceDivider: some View {
    Rectangle()
      .fill(AnclaTheme.panelStroke.opacity(0.55))
      .frame(height: 1)
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
      return "All emergency unbricks have been spent. Active sessions now require the paired anchor."
    }

    if viewModel.canUseEmergencyUnbrick {
      return "Use one if you need to end the current session without your paired anchor."
    }

    return "Keep these in reserve for moments when you cannot reach the paired anchor."
  }

  private var emergencyUnbrickAccent: Color {
    viewModel.snapshot.emergencyUnbricksRemaining == 0 ? AnclaTheme.errorText : AnclaTheme.primaryText
  }

  private var emergencyCountSentence: String {
    let count = viewModel.snapshot.emergencyUnbricksRemaining
    if count == 1 {
      return "1 emergency unbrick remains."
    }

    return "\(count) emergency unbricks remain."
  }

  private var sessionWaitingDetail: String {
    if let activePairedTag {
      if viewModel.snapshot.activeSession?.scheduledPlanID != nil {
        return "This scheduled session is active now. \(activePairedTag.displayName) is still the early release path. \(emergencyCountSentence)"
      }

      if viewModel.currentModeIsStrict {
        return "Strict mode is active. \(activePairedTag.displayName) is the only release path. \(emergencyCountSentence)"
      }

      return "The current session remains active until \(activePairedTag.displayName) is scanned. \(emergencyCountSentence)"
    }

    return "The current session remains active until the release anchor is scanned. \(emergencyCountSentence)"
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
      return "This anchor started the current session and is the only one that can release it."
    }

    return "This anchor can start a new session on this iPhone."
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

  private var strictModeTitle: String {
    viewModel.canReleaseActiveSession ? "Strict mode is active" : "Strict mode is ready"
  }

  private var strictModeDetail: String {
    if viewModel.canReleaseActiveSession {
      return "This session is meant to feel harder to bypass. Close obvious loopholes with the Apple app shortcut guides before you rely on it."
    }

    return "This mode uses stronger, more committed copy and a native-Apple-app checklist so the easy bypasses are harder to ignore."
  }

  private var canCreateScheduledPlan: Bool {
    !viewModel.modesForDisplay.isEmpty && !viewModel.pairedTagsForDisplay.isEmpty
  }

  private var scheduledSessionsEmptyDetail: String {
    if !canCreateScheduledPlan {
      return "Pair at least one anchor and save at least one mode before adding a schedule."
    }

    return "Schedules can auto-start saved modes on chosen weekdays and still keep a paired anchor as the manual release key."
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

private struct HomeSectionSheet<Content: View>: View {
  let title: String
  let subtitle: String
  let content: Content

  @Environment(\.dismiss) private var dismiss

  init(
    title: String,
    subtitle: String,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.subtitle = subtitle
    self.content = content()
  }

  var body: some View {
    ZStack(alignment: .top) {
      AnclaTheme.background
        .ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 20) {
          Capsule(style: .continuous)
            .fill(AnclaTheme.tertiaryText.opacity(0.6))
            .frame(width: 40, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
              Text(title)
                .font(.ancla(30, weight: .medium))
                .foregroundStyle(AnclaTheme.primaryText)

              Text(subtitle)
                .font(.ancla(14))
                .foregroundStyle(AnclaTheme.secondaryText)
            }

            Spacer(minLength: 16)

            Button {
              dismiss()
            } label: {
              Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnclaTheme.secondaryText)
                .frame(width: 36, height: 36)
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

          content
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 32)
      }
    }
    .preferredColorScheme(.dark)
    .presentationDetents([.large])
    .presentationDragIndicator(.hidden)
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
