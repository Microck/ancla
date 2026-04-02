import CoreNFC
import Foundation

#if !SIDELOAD_LITE
import FamilyControls
#endif

protocol RuntimeDiagnosticsProbing {
  func environment(for buildVariant: AppBuildVariant) -> RuntimeEnvironmentSnapshot
}

struct LiveRuntimeDiagnosticsProbe: RuntimeDiagnosticsProbing {
  func environment(for buildVariant: AppBuildVariant) -> RuntimeEnvironmentSnapshot {
    switch buildVariant {
    case .full:
#if SIDELOAD_LITE
      return RuntimeEnvironmentSnapshot(
        buildLabel: "Full blocker unavailable",
        buildDetail: "This sideload build strips Apple-managed Screen Time frameworks from the app binary.",
        storageLabel: "Unavailable",
        storageDetail: "Install the App Store or TestFlight build for full Screen Time shielding.",
        storageTone: .blocked,
        nfcAvailable: NFCTagReaderSession.readingAvailable,
        screenTimeAuthorization: .notRequired
      )
#else
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: AppGroupConfiguration.identifier
      )

      return RuntimeEnvironmentSnapshot(
        buildLabel: "Full blocker experiment",
        buildDetail: "Uses Family Controls, NFC, shared App Group storage, and the shield extension.",
        storageLabel: containerURL == nil ? "App Group missing" : "App Group live",
        storageDetail: containerURL == nil
          ? "The shared container \(AppGroupConfiguration.identifier) is unavailable. Signing is not honoring the app-group entitlement."
          : "The shared App Group container is available for app and extension state.",
        storageTone: containerURL == nil ? .blocked : .ready,
        nfcAvailable: NFCTagReaderSession.readingAvailable,
        screenTimeAuthorization: authorizationState(for: AuthorizationCenter.shared.authorizationStatus)
      )
#endif

    case .sideloadLite:
      return RuntimeEnvironmentSnapshot(
        buildLabel: "Sideload-safe build",
        buildDetail: "Optimized to install cleanly under sideload signing while keeping real NFC sticker scans.",
        storageLabel: "Local store",
        storageDetail: "State stays in the app sandbox instead of an App Group container.",
        storageTone: .neutral,
        nfcAvailable: NFCTagReaderSession.readingAvailable,
        screenTimeAuthorization: .notRequired
      )
    }
  }

#if !SIDELOAD_LITE
  private func authorizationState(
    for status: AuthorizationStatus
  ) -> ScreenTimeAuthorizationState {
    switch status {
    case .notDetermined:
      return .notDetermined
    case .denied:
      return .denied
    case .approved:
      return .approved
    @unknown default:
      return .unknown
    }
  }
#endif
}
