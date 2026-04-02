import CoreNFC
import CryptoKit
import Foundation

#if !SIDELOAD_LITE
import FamilyControls
import ManagedSettings
#endif

enum StickerPairingError: LocalizedError {
  case readerUnavailable
  case scanFailed
  case unsupportedTag
  case userCanceled

  var errorDescription: String? {
    switch self {
    case .readerUnavailable:
      return "NFC is unavailable on this device."
    case .scanFailed:
      return "No readable sticker was detected."
    case .unsupportedTag:
      return "This sticker type is not supported."
    case .userCanceled:
      return "Sticker scan canceled."
    }
  }
}

struct TagFingerprint {
  static func hash(_ identifier: Data) -> String {
    let digest = SHA256.hash(data: identifier)
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}

#if !SIDELOAD_LITE
@MainActor
final class AuthorizationClient: AuthorizationClienting {
  func request() async throws {
    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
  }
}

@MainActor
final class ShieldingService: Shielding {
  private let store = ManagedSettingsStore()

  func apply(mode: BlockMode) throws {
    let selection = try mode.decodedSelection()

    store.shield.applications = selection.applicationTokens.isEmpty
      ? nil
      : selection.applicationTokens

    store.shield.applicationCategories = selection.categoryTokens.isEmpty
      ? nil
      : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)

    store.shield.webDomains = selection.webDomainTokens.isEmpty
      ? nil
      : selection.webDomainTokens
  }

  func clear() {
    store.clearAllSettings()
  }
}
#endif

@MainActor
final class StickerPairingService: NSObject, StickerPairing, @preconcurrency NFCTagReaderSessionDelegate {
  private var session: NFCTagReaderSession?
  private var continuation: CheckedContinuation<String, Error>?

  func scanSticker() async throws -> String {
    guard NFCTagReaderSession.readingAvailable else {
      throw StickerPairingError.readerUnavailable
    }

    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation

      guard let readerSession = NFCTagReaderSession(
        pollingOption: [.iso14443, .iso15693],
        delegate: self,
        queue: nil
      ) else {
        self.continuation = nil
        continuation.resume(throwing: StickerPairingError.scanFailed)
        return
      }

      readerSession.alertMessage = "Hold your iPhone near the paired sticker."
      readerSession.begin()
      self.session = readerSession
    }
  }

  func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

  func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
    guard let continuation else {
      return
    }

    self.continuation = nil

    let nsError = error as NSError
    let userCanceledCode = NFCReaderError.Code.readerSessionInvalidationErrorUserCanceled.rawValue
    if nsError.domain == NFCErrorDomain, nsError.code == userCanceledCode {
      continuation.resume(throwing: StickerPairingError.userCanceled)
      return
    }

    continuation.resume(throwing: error)
  }

  func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
    guard let tag = tags.first else {
      finish(with: StickerPairingError.scanFailed)
      return
    }

    session.connect(to: tag) { [weak self] error in
      if let error {
        self?.finish(with: error)
        return
      }

      let identifier: Data?

      switch tag {
      case let .miFare(mifare):
        identifier = mifare.identifier
      case let .iso15693(iso15693):
        identifier = iso15693.identifier
      case let .iso7816(iso7816):
        identifier = iso7816.identifier
      case .feliCa:
        identifier = nil
      @unknown default:
        identifier = nil
      }

      guard let identifier else {
        self?.finish(with: StickerPairingError.unsupportedTag)
        return
      }

      self?.finish(withHash: TagFingerprint.hash(identifier))
    }
  }

  private func finish(withHash hash: String) {
    session?.invalidate()
    session = nil

    guard let continuation else {
      return
    }

    self.continuation = nil
    continuation.resume(returning: hash)
  }

  private func finish(with error: Error) {
    session?.invalidate(errorMessage: "Unable to read this sticker.")
    session = nil

    guard let continuation else {
      return
    }

    self.continuation = nil
    continuation.resume(throwing: error)
  }
}
