import CoreNFC
import FamilyControls
import Foundation

protocol RuntimeDiagnosticsProbing {
  func environment(for buildVariant: AppBuildVariant) -> RuntimeEnvironmentSnapshot
}

struct LiveRuntimeDiagnosticsProbe: RuntimeDiagnosticsProbing {
  func environment(for buildVariant: AppBuildVariant) -> RuntimeEnvironmentSnapshot {
    switch buildVariant {
    case .full:
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

    case .sideloadLite:
      return RuntimeEnvironmentSnapshot(
        buildLabel: "Sideload lite",
        buildDetail: "Keeps real NFC scanning but skips Apple-managed blocking.",
        storageLabel: "Local store",
        storageDetail: "State stays in the app sandbox instead of an App Group container.",
        storageTone: .neutral,
        nfcAvailable: NFCTagReaderSession.readingAvailable,
        screenTimeAuthorization: .notRequired
      )
    }
  }

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
    case .approvedWithDataAccess:
      return .approvedWithDataAccess
    @unknown default:
      return .unknown
    }
  }
}
