import Foundation

enum RuntimeDiagnosticTone: String, Codable {
  case ready
  case attention
  case blocked
  case neutral
}

enum ScreenTimeAuthorizationState: String, Codable {
  case notRequired
  case notDetermined
  case denied
  case approved
  case unknown

  var isApproved: Bool {
    switch self {
    case .approved:
      return true
    default:
      return false
    }
  }

  var title: String {
    switch self {
    case .notRequired:
      return "Inactive"
    case .notDetermined:
      return "Not granted"
    case .denied:
      return "Denied"
    case .approved:
      return "Approved"
    case .unknown:
      return "Unknown"
    }
  }

  var detail: String {
    switch self {
    case .notRequired:
      return "System-level App Controls are not active in this release."
    case .notDetermined:
      return "Enable App Controls from the primary action to continue."
    case .denied:
      return "Authorization is unavailable, revoked, or blocked by entitlements."
    case .approved:
      return "App Controls authorization is active for this iPhone."
    case .unknown:
      return "The device returned an unrecognized authorization state."
    }
  }

  var tone: RuntimeDiagnosticTone {
    switch self {
    case .approved:
      return .ready
    case .notRequired:
      return .neutral
    case .notDetermined, .unknown:
      return .attention
    case .denied:
      return .blocked
    }
  }
}

struct RuntimeEnvironmentSnapshot: Equatable {
  let buildLabel: String
  let buildDetail: String
  let storageLabel: String
  let storageDetail: String
  let storageTone: RuntimeDiagnosticTone
  let nfcAvailable: Bool
  let screenTimeAuthorization: ScreenTimeAuthorizationState
}

struct RuntimeDiagnosticItem: Equatable, Identifiable {
  let id: String
  let title: String
  let value: String
  let detail: String
  let tone: RuntimeDiagnosticTone
}

struct RuntimeDiagnostics: Equatable {
  let headline: String
  let message: String
  let items: [RuntimeDiagnosticItem]

  static let empty = RuntimeDiagnostics(
    headline: "Checking device",
    message: "Refreshing device capabilities.",
    items: []
  )
}

extension AnclaCore {
  static func runtimeDiagnostics(
    snapshot: AppSnapshot,
    environment: RuntimeEnvironmentSnapshot
  ) -> RuntimeDiagnostics {
    let items = [
      RuntimeDiagnosticItem(
        id: "build",
        title: "Build",
        value: environment.buildLabel,
        detail: environment.buildDetail,
        tone: .neutral
      ),
      RuntimeDiagnosticItem(
        id: "screen-time",
        title: "App Controls",
        value: environment.screenTimeAuthorization.title,
        detail: environment.screenTimeAuthorization.detail,
        tone: environment.screenTimeAuthorization.tone
      ),
      RuntimeDiagnosticItem(
        id: "nfc",
        title: "NFC",
        value: environment.nfcAvailable ? "Ready" : "Unavailable",
        detail: environment.nfcAvailable
          ? "This iPhone can read the paired anchor."
          : "This iPhone cannot start NFC anchor scans.",
        tone: environment.nfcAvailable ? .ready : .blocked
      ),
      RuntimeDiagnosticItem(
        id: "storage",
        title: "Storage",
        value: environment.storageLabel,
        detail: environment.storageDetail,
        tone: environment.storageTone
      ),
      RuntimeDiagnosticItem(
        id: "sticker",
        title: "Anchor",
        value: snapshot.pairedTag?.displayName ?? "Not paired",
        detail: snapshot.pairedTag == nil
          ? "Pair the NFC anchor that should release sessions on this iPhone."
          : "The paired anchor is the only release key for this iPhone.",
        tone: snapshot.pairedTag == nil ? .attention : .ready
      ),
      RuntimeDiagnosticItem(
        id: "mode",
        title: "Mode",
        value: preferredMode(in: snapshot)?.name ?? "None",
        detail: snapshot.modes.isEmpty
          ? "Create a mode before starting a session."
          : "\(snapshot.modes.count) saved mode" + (snapshot.modes.count == 1 ? "" : "s") + ".",
        tone: snapshot.modes.isEmpty ? .attention : .ready
      ),
      RuntimeDiagnosticItem(
        id: "session",
        title: "Session",
        value: sessionTitle(snapshot.activeSession?.state),
        detail: sessionDetail(snapshot.activeSession?.state),
        tone: sessionTone(snapshot.activeSession?.state)
      ),
    ]

    return RuntimeDiagnostics(
      headline: primaryHeadline(snapshot: snapshot, environment: environment),
      message: primaryMessage(snapshot: snapshot, environment: environment),
      items: items
    )
  }

  private static func primaryHeadline(
    snapshot: AppSnapshot,
    environment: RuntimeEnvironmentSnapshot
  ) -> String {
    if environment.storageTone == .blocked {
      return "Storage unavailable"
    }

    if !environment.nfcAvailable {
      return "NFC unavailable"
    }

    if environment.screenTimeAuthorization != .notRequired,
       !environment.screenTimeAuthorization.isApproved
    {
      return "Controls unavailable"
    }

    if snapshot.pairedTag == nil {
      return "Pair an anchor"
    }

    if snapshot.modes.isEmpty {
      return "Create your first mode"
    }

    if canReleaseActiveSession(snapshot) {
      return "Session active"
    }

    return "Ready to start"
  }

  private static func primaryMessage(
    snapshot: AppSnapshot,
    environment: RuntimeEnvironmentSnapshot
  ) -> String {
    if environment.storageTone == .blocked {
      return environment.storageDetail
    }

    if !environment.nfcAvailable {
      return "This iPhone cannot scan NFC anchors, so pairing and release are unavailable on this device."
    }

    if environment.screenTimeAuthorization != .notRequired,
       !environment.screenTimeAuthorization.isApproved
    {
      return environment.screenTimeAuthorization.detail
    }

    if snapshot.pairedTag == nil {
      return "Pair one NFC anchor to set the physical release key for this iPhone."
    }

    if snapshot.modes.isEmpty {
      return "Create the mode you want ready before starting a session."
    }

    if canReleaseActiveSession(snapshot) {
      return "Only the paired anchor can release the current session."
    }

    return "The selected mode is ready to start."
  }

  private static func sessionTitle(_ state: AnchorSessionState?) -> String {
    switch state {
    case .armed:
      return "Armed"
    case .mismatchedTag:
      return "Wrong anchor"
    case .released:
      return "Released"
    case .idle, nil:
      return "Idle"
    }
  }

  private static func sessionDetail(_ state: AnchorSessionState?) -> String {
    switch state {
    case .armed:
      return "A session is active and waiting for the paired anchor."
    case .mismatchedTag:
      return "A different anchor was scanned. The session remains active."
    case .released:
      return "The most recent session was released."
    case .idle, nil:
      return "No session is active right now."
    }
  }

  private static func sessionTone(_ state: AnchorSessionState?) -> RuntimeDiagnosticTone {
    switch state {
    case .armed, .mismatchedTag:
      return .attention
    case .released, .idle, nil:
      return .neutral
    }
  }
}
