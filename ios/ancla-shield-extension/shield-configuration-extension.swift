import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
  private let store = AppGroupStore()

  override func configuration(shielding application: Application) -> ShieldConfiguration {
    makeConfiguration(title: application.localizedDisplayName ?? "Ancla is armed")
  }

  override func configuration(
    shielding application: Application,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    makeConfiguration(title: application.localizedDisplayName ?? "Ancla is armed")
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    makeConfiguration(title: webDomain.domain ?? "Ancla is armed")
  }

  override func configuration(
    shielding webDomain: WebDomain,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    makeConfiguration(title: webDomain.domain ?? "Ancla is armed")
  }

  private func makeConfiguration(title: String) -> ShieldConfiguration {
    let snapshot = (try? store.load()) ?? AppSnapshot()
    let activeModeName = activeModeName(in: snapshot) ?? "Focus mode"
    let stickerName = snapshot.pairedTag?.displayName ?? "paired sticker"

    ShieldConfiguration(
      backgroundBlurStyle: .systemMaterialLight,
      backgroundColor: UIColor(red: 0.988, green: 0.988, blue: 0.992, alpha: 1),
      icon: UIImage(systemName: "anchor"),
      title: ShieldConfiguration.Label(text: title, color: .label),
      subtitle: ShieldConfiguration.Label(
        text: "Mode \(activeModeName) is armed. Open Ancla and scan \(stickerName) to continue.",
        color: .secondaryLabel
      ),
      primaryButtonLabel: ShieldConfiguration.Label(text: "Open Ancla", color: .white),
      primaryButtonBackgroundColor: UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1),
      secondaryButtonLabel: ShieldConfiguration.Label(text: "Later", color: .label)
    )
  }

  private func activeModeName(in snapshot: AppSnapshot) -> String? {
    guard let session = snapshot.activeSession else {
      return nil
    }
    return snapshot.modes.first(where: { $0.id == session.modeId })?.name
  }
}
