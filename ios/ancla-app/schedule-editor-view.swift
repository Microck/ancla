import SwiftUI

struct ScheduleEditorView: View {
  @Bindable var viewModel: AppViewModel
  let isEditingSchedule: Bool

  @Environment(\.dismiss) private var dismiss

  private let weekdays: [(number: Int, short: String, long: String)] = [
    (1, "S", "Sunday"),
    (2, "M", "Monday"),
    (3, "T", "Tuesday"),
    (4, "W", "Wednesday"),
    (5, "T", "Thursday"),
    (6, "F", "Friday"),
    (7, "S", "Saturday"),
  ]

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

          Text(isEditingSchedule ? "Edit Schedule" : "New Schedule")
            .font(.ancla(18, weight: .bold))
            .foregroundStyle(AnclaTheme.primaryText)

          Spacer()

          Button("Save") {
            Task {
              await viewModel.saveScheduledPlan()
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
            if viewModel.isActionInProgress(.saveSchedule) {
              ProgressView()
                .tint(AnclaTheme.ctaText)
            }
          }
          .disabled(viewModel.isBusy || !viewModel.canSaveDraftSchedule)
          .opacity(viewModel.isBusy || !viewModel.canSaveDraftSchedule ? 0.55 : 1)
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 0) {
            sectionLabel("MODE")
              .padding(.top, 48)

            Text("Pick the mode this schedule should start automatically on iPhone.")
              .font(.ancla(14))
              .foregroundStyle(AnclaTheme.secondaryText)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 20)

            VStack(spacing: 12) {
              ForEach(viewModel.modesForDisplay) { mode in
                selectionCard(
                  title: mode.name,
                  detail: viewModel.selectionSummary(for: mode),
                  isSelected: viewModel.draftScheduleModeID == mode.id
                ) {
                  viewModel.draftScheduleModeID = mode.id
                }
              }
            }
            .padding(.top, 22)

            divider
              .padding(.top, 28)

            sectionLabel("ANCHOR")
              .padding(.top, 40)

            Text("Pick the paired anchor that can release this scheduled session early.")
              .font(.ancla(14))
              .foregroundStyle(AnclaTheme.secondaryText)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 20)

            VStack(spacing: 12) {
              ForEach(viewModel.pairedTagsForDisplay) { pairedTag in
                selectionCard(
                  title: pairedTag.displayName,
                  detail: "Scheduled sessions will still bind to this anchor for manual release.",
                  isSelected: viewModel.draftSchedulePairedTagID == pairedTag.id
                ) {
                  viewModel.draftSchedulePairedTagID = pairedTag.id
                }
              }
            }
            .padding(.top, 22)

            divider
              .padding(.top, 28)

            sectionLabel("DAYS")
              .padding(.top, 40)

            Text("Choose the weekdays when this schedule should run.")
              .font(.ancla(14))
              .foregroundStyle(AnclaTheme.secondaryText)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 20)

            HStack(spacing: 10) {
              ForEach(weekdays, id: \.number) { weekday in
                Button(weekday.short) {
                  viewModel.toggleDraftScheduleWeekday(weekday.number)
                }
                .font(.ancla(15, weight: .medium))
                .foregroundStyle(
                  viewModel.draftScheduleWeekdayNumbers.contains(weekday.number)
                    ? AnclaTheme.primaryText
                    : AnclaTheme.secondaryText
                )
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                      viewModel.draftScheduleWeekdayNumbers.contains(weekday.number)
                        ? AnclaTheme.panelRaised
                        : AnclaTheme.panelInteractive
                    )
                    .overlay(
                      RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                          viewModel.draftScheduleWeekdayNumbers.contains(weekday.number)
                            ? AnclaTheme.accentStroke.opacity(0.55)
                            : AnclaTheme.panelStroke.opacity(0.75),
                          lineWidth: 1
                        )
                    )
                )
                .accessibilityLabel(weekday.long)
              }
            }
            .padding(.top, 22)

            divider
              .padding(.top, 28)

            sectionLabel("TIME")
              .padding(.top, 40)

            Text("Set when the schedule should start and end. Use the current window shortcut if you want it active right away.")
              .font(.ancla(14))
              .foregroundStyle(AnclaTheme.secondaryText)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 20)

            Button {
              viewModel.useCurrentDraftScheduleWindow()
            } label: {
              HStack {
                Image(systemName: "clock.badge")
                  .font(.system(size: 13, weight: .semibold))
                  .foregroundStyle(AnclaTheme.primaryText)

                Text("Use current time window")
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
            .padding(.top, 22)

            timeControl(
              title: "Start",
              value: formattedTime(viewModel.draftScheduleStartMinuteOfDay),
              earlierLabel: "Start earlier",
              laterLabel: "Start later",
              onEarlier: { viewModel.shiftDraftScheduleStart(by: -15) },
              onLater: { viewModel.shiftDraftScheduleStart(by: 15) }
            )
            .padding(.top, 16)

            timeControl(
              title: "End",
              value: formattedTime(viewModel.draftScheduleEndMinuteOfDay),
              earlierLabel: "End earlier",
              laterLabel: "End later",
              onEarlier: { viewModel.shiftDraftScheduleEnd(by: -15) },
              onLater: { viewModel.shiftDraftScheduleEnd(by: 15) }
            )
            .padding(.top, 12)

            divider
              .padding(.top, 28)

            sectionLabel("STATUS")
              .padding(.top, 40)

            HStack(alignment: .center) {
              VStack(alignment: .leading, spacing: 6) {
                Text("Enabled")
                  .font(.ancla(16))
                  .foregroundStyle(AnclaTheme.primaryText)

                Text("Disabled schedules stay saved but do not auto-start.")
                  .font(.ancla(12))
                  .foregroundStyle(AnclaTheme.tertiaryText)
              }

              Spacer()

              Toggle("", isOn: $viewModel.draftScheduleIsEnabled)
                .labelsHidden()
                .tint(AnclaTheme.ctaFill)
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
            .padding(.top, 22)

            if let lastError = viewModel.lastError {
              Text(lastError)
                .font(.ancla(12, weight: .medium))
                .foregroundStyle(AnclaTheme.errorText)
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

  private func selectionCard(
    title: String,
    detail: String,
    isSelected: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
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
    .buttonStyle(.plain)
  }

  private func timeControl(
    title: String,
    value: String,
    earlierLabel: String,
    laterLabel: String,
    onEarlier: @escaping () -> Void,
    onLater: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.ancla(12, weight: .medium))
        .foregroundStyle(AnclaTheme.tertiaryText)

      HStack(spacing: 12) {
        Button(earlierLabel, action: onEarlier)
          .font(.ancla(13, weight: .medium))
          .foregroundStyle(AnclaTheme.secondaryText)
          .frame(width: 92, height: 42)
          .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(AnclaTheme.panelInteractive)
              .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
              )
          )

        Text(value)
          .font(.anclaMono(18))
          .foregroundStyle(AnclaTheme.primaryText)
          .frame(maxWidth: .infinity)
          .frame(height: 42)
          .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(AnclaTheme.panelRaised)
              .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
              )
          )

        Button(laterLabel, action: onLater)
          .font(.ancla(13, weight: .medium))
          .foregroundStyle(AnclaTheme.secondaryText)
          .frame(width: 92, height: 42)
          .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(AnclaTheme.panelInteractive)
              .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
              )
          )
      }
    }
  }

  private func formattedTime(_ minutes: Int) -> String {
    let hours = minutes / 60
    let remainder = minutes % 60
    let isPM = hours >= 12
    let displayHour = ((hours + 11) % 12) + 1
    return "\(displayHour):" + String(format: "%02d", remainder) + (isPM ? " PM" : " AM")
  }
}
