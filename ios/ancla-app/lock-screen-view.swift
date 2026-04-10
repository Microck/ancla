import SwiftUI

struct LockScreenView: View {
  let unlockMenuPresented: Bool
  let emergencyTitle: String
  let emergencyDetail: String
  let emergencyEnabled: Bool
  let presets: [UnlockPreset]
  let feedback: ActionFeedback?
  let isBusy: Bool
  let onToggleUnlockMenu: () -> Void
  let onEmergencyAction: () -> Void
  let onPreset: (UnlockPreset) -> Void

  var body: some View {
    ZStack(alignment: .topLeading) {
      AnclaTheme.background
        .ignoresSafeArea()

      VStack {
        Spacer(minLength: 0)

        VStack(spacing: 18) {
          AnclaMark(color: Color.white.opacity(0.94), size: 128)

          VStack(spacing: 8) {
            Text("You're anchored")
              .font(.ancla(34, weight: .semibold))
              .foregroundStyle(Color.white)

            Text("Hold your iPhone near your anchor to unlock")
              .font(.ancla(20, weight: .medium))
              .foregroundStyle(Color.white.opacity(0.82))
              .multilineTextAlignment(.center)
              .frame(maxWidth: 280)
          }
        }

        Spacer(minLength: 0)

        if let feedback {
          lockFeedback(feedback)
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Button(action: onToggleUnlockMenu) {
          Image(systemName: "lock.open")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: 34, height: 34)
            .background(
              Circle()
                .fill(Color.white.opacity(0.08))
                .overlay(
                  Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Unlock options")

        if unlockMenuPresented {
          unlockMenu
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
        }
      }
      .padding(.top, 18)
      .padding(.leading, 18)
    }
    .preferredColorScheme(.dark)
  }

  private var unlockMenu: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button(action: onEmergencyAction) {
        lockMenuRow(
          title: emergencyTitle,
          detail: emergencyDetail,
          isEnabled: emergencyEnabled
        )
      }
      .buttonStyle(.plain)
      .disabled(!emergencyEnabled || isBusy)
      .opacity(!emergencyEnabled || isBusy ? 0.55 : 1)

      if presets.isEmpty {
        Text("No presets saved yet.")
          .font(.ancla(14))
          .foregroundStyle(Color.white.opacity(0.44))
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
      } else {
        ForEach(presets) { preset in
          Button {
            onPreset(preset)
          } label: {
            lockMenuRow(
              title: preset.title,
              detail: "\(preset.durationSeconds)s",
              isEnabled: !isBusy
            )
          }
          .buttonStyle(.plain)
          .disabled(isBusy)
          .opacity(isBusy ? 0.55 : 1)
        }
      }
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
        .overlay(
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    )
  }

  private func lockMenuRow(title: String, detail: String, isEnabled: Bool) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.ancla(16, weight: .medium))
          .foregroundStyle(isEnabled ? Color.white : Color.white.opacity(0.42))

        Text(detail)
          .font(.ancla(12))
          .foregroundStyle(Color.white.opacity(0.42))
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .contentShape(Rectangle())
  }

  private func lockFeedback(_ feedback: ActionFeedback) -> some View {
    let color: Color
    switch feedback.tone {
    case .neutral:
      color = Color.white.opacity(0.72)
    case .success:
      color = AnclaTheme.successText
    case .error:
      color = AnclaTheme.errorText
    }

    return Text(feedback.message)
      .font(.ancla(13, weight: .medium))
      .foregroundStyle(color)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(Color.white.opacity(0.04))
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(Color.white.opacity(0.06), lineWidth: 1)
          )
      )
  }
}
