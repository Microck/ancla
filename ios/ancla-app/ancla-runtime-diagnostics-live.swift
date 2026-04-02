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
        buildLabel: "Extended controls unavailable",
        buildDetail: "This release does not include the Apple-managed frameworks required for system-level blocking.",
        storageLabel: "Unavailable",
        storageDetail: "Install a distribution build with App Controls support to enable shared blocking state.",
        storageTone: .blocked,
        nfcAvailable: NFCTagReaderSession.readingAvailable,
        screenTimeAuthorization: .notRequired
      )
#else
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: AppGroupConfiguration.identifier
      )

      return RuntimeEnvironmentSnapshot(
        buildLabel: "Extended controls active",
        buildDetail: "Uses App Controls, NFC, shared App Group storage, and the shield extension.",
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
        buildLabel: "On-device release",
        buildDetail: "Configured for NFC pairing and local session state on this iPhone.",
        storageLabel: "On-device",
        storageDetail: "Session state is stored in the app instead of a shared extension container.",
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
