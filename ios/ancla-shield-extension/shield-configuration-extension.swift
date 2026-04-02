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
    let anchorName = snapshot.pairedTag?.displayName ?? "paired anchor"

    return ShieldConfiguration(
      backgroundBlurStyle: .systemThinMaterialDark,
      backgroundColor: UIColor(red: 0.047, green: 0.055, blue: 0.066, alpha: 1),
      icon: UIImage(named: "brand-mark"),
      title: ShieldConfiguration.Label(
        text: title,
        color: UIColor(red: 0.878, green: 0.902, blue: 0.945, alpha: 1)
      ),
      subtitle: ShieldConfiguration.Label(
        text: "Mode \(activeModeName) is active. Open Ancla and scan \(anchorName) to continue.",
        color: UIColor(red: 0.592, green: 0.620, blue: 0.659, alpha: 1)
      ),
      primaryButtonLabel: ShieldConfiguration.Label(
        text: "Open Ancla",
        color: UIColor(red: 0.20, green: 0.22, blue: 0.24, alpha: 1)
      ),
      primaryButtonBackgroundColor: UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1),
      secondaryButtonLabel: ShieldConfiguration.Label(
        text: "Later",
        color: UIColor(red: 0.878, green: 0.902, blue: 0.945, alpha: 1)
      )
    )
  }

  private func activeModeName(in snapshot: AppSnapshot) -> String? {
    guard let session = snapshot.activeSession else {
      return nil
    }
    return snapshot.modes.first(where: { $0.id == session.modeId })?.name
  }
}
