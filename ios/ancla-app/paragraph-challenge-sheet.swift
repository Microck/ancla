import SwiftUI

struct ParagraphChallengeSheet: View {
  @Bindable var viewModel: AppViewModel

  @Environment(\.dismiss) private var dismiss
  @State private var typedPassage = ""

  private var challenge: ParagraphChallengePassage? {
    viewModel.activeParagraphChallenge
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
            viewModel.clearParagraphChallenge()
            dismiss()
          }
          .font(.ancla(14, weight: .medium))
          .foregroundStyle(AnclaTheme.secondaryText)
          .padding(.horizontal, 14)
          .frame(height: 38)
          .background(buttonBackground)

          Spacer()

          Text("Failsafe Challenge")
            .font(.ancla(18, weight: .bold))
            .foregroundStyle(AnclaTheme.primaryText)

          Spacer()

          Button("Unlock") {
            Task {
              await viewModel.submitParagraphChallenge(typedPassage)
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
            if viewModel.isActionInProgress(.paragraphChallenge) {
              ProgressView()
                .tint(AnclaTheme.ctaText)
            }
          }
          .disabled(viewModel.isBusy || typedPassage.isEmpty)
          .opacity(viewModel.isBusy || typedPassage.isEmpty ? 0.55 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)

        if let challenge {
          ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
              Text(challenge.title)
                .font(.ancla(12, weight: .medium))
                .foregroundStyle(AnclaTheme.tertiaryText)
                .tracking(1.4)

              Text(challenge.passage)
                .font(.ancla(17))
                .foregroundStyle(AnclaTheme.primaryText)
                .textSelection(.enabled)

              HStack {
                Text("Exact punctuation required")
                  .font(.ancla(12, weight: .medium))
                  .foregroundStyle(AnclaTheme.secondaryText)

                Spacer()

                Text("\(challengeAccuracyPercent)%")
                  .font(.ancla(12, weight: .semibold))
                  .foregroundStyle(challengeAccuracyPercent == 100 ? AnclaTheme.successText : AnclaTheme.secondaryText)
              }

              TextEditor(text: $typedPassage)
                .scrollContentBackground(.hidden)
                .font(.ancla(16))
                .foregroundStyle(AnclaTheme.primaryText)
                .frame(minHeight: 220)
                .padding(14)
                .background(editorBackground)
                .textInputAutocapitalization(.never)
#if os(iOS)
                .autocorrectionDisabled(true)
#endif

              if let lastError = viewModel.lastError {
                Text(lastError)
                  .font(.ancla(12, weight: .medium))
                  .foregroundStyle(AnclaTheme.errorText)
              }
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 36)
          }
        }
      }
    }
    .preferredColorScheme(.dark)
    .presentationDetents([.large])
    .presentationDragIndicator(.hidden)
    .onDisappear {
      viewModel.clearParagraphChallenge()
    }
  }

  private var challengeAccuracyPercent: Int {
    guard let challenge, !challenge.passage.isEmpty else {
      return 0
    }

    let expected = Array(challenge.passage)
    let actual = Array(typedPassage)
    let comparedCount = min(expected.count, actual.count)
    let matching = zip(expected.prefix(comparedCount), actual.prefix(comparedCount))
      .filter { lhs, rhs in lhs == rhs }
      .count
    let penalty = abs(expected.count - actual.count)
    let score = max(0, matching - penalty)
    return Int((Double(score) / Double(expected.count) * 100).rounded())
  }

  private var buttonBackground: some View {
    RoundedRectangle(cornerRadius: 14, style: .continuous)
      .fill(AnclaTheme.panelInteractive)
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
      )
  }

  private var editorBackground: some View {
    RoundedRectangle(cornerRadius: 20, style: .continuous)
      .fill(AnclaTheme.panelInteractive)
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(AnclaTheme.panelStroke.opacity(0.75), lineWidth: 1)
      )
  }
}
