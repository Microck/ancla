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
  case approvedWithDataAccess
  case unknown

  var isApproved: Bool {
    switch self {
    case .approved, .approvedWithDataAccess:
      return true
    default:
      return false
    }
  }

  var title: String {
    switch self {
    case .notRequired:
      return "Not required"
    case .notDetermined:
      return "Not granted"
    case .denied:
      return "Denied"
    case .approved:
      return "Approved"
    case .approvedWithDataAccess:
      return "Approved + data"
    case .unknown:
      return "Unknown"
    }
  }

  var detail: String {
    switch self {
    case .notRequired:
      return "This build skips Apple-managed Screen Time blocking."
    case .notDetermined:
      return "Ask for Screen Time access from the main action button."
    case .denied:
      return "Authorization is missing, revoked, or blocked by signing entitlements."
    case .approved:
      return "Screen Time authorization is live for this install."
    case .approvedWithDataAccess:
      return "Screen Time authorization is live with non-tokenized data access."
    case .unknown:
      return "The device returned an unrecognized authorization state."
    }
  }

  var tone: RuntimeDiagnosticTone {
    switch self {
    case .approved, .approvedWithDataAccess:
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
    message: "Refreshing runtime capabilities.",
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
        title: "Screen Time",
        value: environment.screenTimeAuthorization.title,
        detail: environment.screenTimeAuthorization.detail,
        tone: environment.screenTimeAuthorization.tone
      ),
      RuntimeDiagnosticItem(
        id: "nfc",
        title: "NFC",
        value: environment.nfcAvailable ? "Ready" : "Unavailable",
        detail: environment.nfcAvailable
          ? "This iPhone can scan the paired sticker."
          : "This device cannot start NFC sticker scans.",
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
        title: "Sticker",
        value: snapshot.pairedTag?.displayName ?? "Unpaired",
        detail: snapshot.pairedTag == nil
          ? "Scan the exact NFC sticker that should unlock the session."
          : "The paired sticker is the only release key for this install.",
        tone: snapshot.pairedTag == nil ? .attention : .ready
      ),
      RuntimeDiagnosticItem(
        id: "mode",
        title: "Mode",
        value: preferredMode(in: snapshot)?.name ?? "None",
        detail: snapshot.modes.isEmpty
          ? "Create one mode with apps, categories, or domains before arming."
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
      return "Blocking unavailable"
    }

    if snapshot.pairedTag == nil {
      return "Pair a sticker"
    }

    if snapshot.modes.isEmpty {
      return "Create a mode"
    }

    if canReleaseActiveSession(snapshot) {
      return "Session armed"
    }

    return "Ready to arm"
  }

  private static func primaryMessage(
    snapshot: AppSnapshot,
    environment: RuntimeEnvironmentSnapshot
  ) -> String {
    if environment.storageTone == .blocked {
      return environment.storageDetail
    }

    if !environment.nfcAvailable {
      return "This device cannot scan the NFC sticker, so pair and release will not work here."
    }

    if environment.screenTimeAuthorization != .notRequired,
       !environment.screenTimeAuthorization.isApproved
    {
      return environment.screenTimeAuthorization.detail
    }

    if snapshot.pairedTag == nil {
      return "Scan one NFC sticker to bind the physical release key to this phone."
    }

    if snapshot.modes.isEmpty {
      return "Choose which apps, categories, or domains should be blocked before arming."
    }

    if canReleaseActiveSession(snapshot) {
      return "Only the paired sticker can release the current block."
    }

    return "The current setup can arm the selected mode right now."
  }

  private static func sessionTitle(_ state: AnchorSessionState?) -> String {
    switch state {
    case .armed:
      return "Armed"
    case .mismatchedTag:
      return "Wrong sticker"
    case .released:
      return "Released"
    case .idle, nil:
      return "Idle"
    }
  }

  private static func sessionDetail(_ state: AnchorSessionState?) -> String {
    switch state {
    case .armed:
      return "The device is blocking and waiting for the paired sticker."
    case .mismatchedTag:
      return "A different sticker was scanned. The block stays active."
    case .released:
      return "The most recent armed session was released."
    case .idle, nil:
      return "No session is blocking right now."
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
