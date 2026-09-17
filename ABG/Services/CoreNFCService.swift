#if canImport(CoreNFC)
import CoreNFC
import Foundation

// I callback del delegate CoreNFC arrivano su una coda privata mentre readTag/cancelReading
// girano sul main actor: continuation e sessione vanno presi in modo atomico, altrimenti
// un "Annulla" simultaneo alla lettura del tag produce un double-resume (crash).
private final class NFCSessionState: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<NFCTagRead, Error>?
  private var session: NFCTagReaderSession?

  func begin(_ continuation: CheckedContinuation<NFCTagRead, Error>) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard self.continuation == nil else { return false }
    self.continuation = continuation
    return true
  }

  func attach(_ session: NFCTagReaderSession) {
    lock.lock()
    defer { lock.unlock() }
    self.session = session
  }

  func take() -> (CheckedContinuation<NFCTagRead, Error>?, NFCTagReaderSession?) {
    lock.lock()
    defer { lock.unlock() }
    let taken = (continuation, session)
    continuation = nil
    session = nil
    return taken
  }
}

final class CoreNFCService: NSObject, NFCService {
  private let state = NFCSessionState()

  var isSupported: Bool {
    NFCTagReaderSession.readingAvailable
  }

  func readTag(prompt: String) async throws -> NFCTagRead {
    guard isSupported else {
      throw NSError(domain: "nfc", code: 1, userInfo: [NSLocalizedDescriptionKey: "NFC non disponibile su questo iPhone"])
    }

    return try await withCheckedThrowingContinuation { continuation in
      guard state.begin(continuation) else {
        continuation.resume(
          throwing: NSError(
            domain: "nfc",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Un'altra lettura NFC è già in corso"]
          )
        )
        return
      }
      guard let session = NFCTagReaderSession(
        pollingOption: [.iso14443, .iso15693],
        delegate: self,
        queue: nil
      ) else {
        let (pending, _) = state.take()
        pending?.resume(
          throwing: NSError(
            domain: "nfc",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Impossibile avviare la sessione NFC"]
          )
        )
        return
      }
      session.alertMessage = prompt
      state.attach(session)
      session.begin()
    }
  }

  func cancelReading() {
    finishError(
      NSError(
        domain: "nfc",
        code: NFCReaderError.readerSessionInvalidationErrorUserCanceled.rawValue,
        userInfo: [NSLocalizedDescriptionKey: "Sessione NFC annullata"]
      )
    )
  }

  private func resolveUID(tag: NFCTag) -> String? {
    switch tag {
    case .miFare(let miFare):
      return miFare.identifier.hexStringUppercased
    case .iso15693(let iso):
      return Data(iso.identifier).hexStringUppercased
    case .feliCa(let feliCa):
      return Data(feliCa.currentIDm).hexStringUppercased
    case .iso7816(let iso7816):
      return iso7816.identifier.hexStringUppercased
    @unknown default:
      return nil
    }
  }

  private func ndefTag(from tag: NFCTag) -> NFCNDEFTag? {
    switch tag {
    case .miFare(let tag):
      return tag
    case .iso15693(let tag):
      return tag
    case .feliCa(let tag):
      return tag
    case .iso7816:
      return nil
    @unknown default:
      return nil
    }
  }

  private func extractPayloadToken(from message: NFCNDEFMessage?) -> String? {
    guard let message else {
      return nil
    }

    for record in message.records {
      if let textPayload = record.wellKnownTypeTextPayload().0 {
        let normalized = normalizeTagToken(textPayload)
        if !normalized.isEmpty {
          return normalized
        }
      }
      if let urlPayload = record.wellKnownTypeURIPayload()?.absoluteString {
        let normalized = normalizeTagToken(urlPayload)
        if !normalized.isEmpty {
          return normalized
        }
      }
      if let rawPayload = String(data: record.payload, encoding: .utf8) {
        let normalized = normalizeTagToken(rawPayload)
        if !normalized.isEmpty {
          return normalized
        }
      }
    }

    return nil
  }

  private func resolve(tag: NFCTag, completion: @escaping (Result<NFCTagRead, Error>) -> Void) {
    let uidToken = normalizeTagToken(resolveUID(tag: tag))
    guard let ndefTag = ndefTag(from: tag) else {
      let read = buildNFCTagRead(payloadToken: nil, uidToken: uidToken)
      if !read.primaryToken.isEmpty {
        completion(.success(read))
        return
      }
      completion(
        .failure(
          NSError(
            domain: "nfc",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Tag letto ma token non disponibile"]
          )
        )
      )
      return
    }

    ndefTag.queryNDEFStatus { [weak self] status, _, error in
      guard let self else { return }
      if error != nil || status == .notSupported {
        let read = buildNFCTagRead(payloadToken: nil, uidToken: uidToken)
        if !read.primaryToken.isEmpty {
          completion(.success(read))
          return
        }
        completion(
          .failure(
            NSError(
              domain: "nfc",
              code: 2,
              userInfo: [NSLocalizedDescriptionKey: "Tag letto ma token non disponibile"]
            )
          )
        )
        return
      }

      ndefTag.readNDEF { message, readError in
        let payloadToken = readError == nil ? self.extractPayloadToken(from: message) : nil
        let read = buildNFCTagRead(payloadToken: payloadToken, uidToken: uidToken)
        if !read.primaryToken.isEmpty {
          completion(.success(read))
          return
        }
        completion(
          .failure(
            NSError(
              domain: "nfc",
              code: 2,
              userInfo: [NSLocalizedDescriptionKey: "Tag letto ma token non disponibile"]
            )
          )
        )
      }
    }
  }

  private func finishSuccess(_ tagRead: NFCTagRead) {
    let (continuation, session) = state.take()
    guard let continuation else {
      session?.invalidate()
      return
    }
    continuation.resume(returning: tagRead)
    session?.alertMessage = "Tag letto. Attendi un istante..."
    session?.invalidate()
  }

  private func finishError(_ error: Error) {
    let (continuation, session) = state.take()
    guard let continuation else {
      session?.invalidate()
      return
    }
    continuation.resume(throwing: error)
    session?.invalidate()
  }
}

extension CoreNFCService: NFCTagReaderSessionDelegate {
  func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
    AppLogger.info("NFC session active")
  }

  func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
    let nsError = error as NSError
    if nsError.domain == NFCReaderError.errorDomain,
      nsError.code == NFCReaderError.readerSessionInvalidationErrorUserCanceled.rawValue {
      finishError(
        NSError(
          domain: "nfc",
          code: nsError.code,
          userInfo: [NSLocalizedDescriptionKey: "Sessione NFC annullata"]
        )
      )
      return
    }

    finishError(error)
  }

  func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
    guard let first = tags.first else {
      session.restartPolling()
      return
    }

    session.connect(to: first) { [weak self] error in
      guard let self else { return }

      if let error {
        self.finishError(error)
        return
      }

      self.resolve(tag: first) { result in
        switch result {
        case .success(let tagRead):
          self.finishSuccess(tagRead)
        case .failure(let error):
          self.finishError(error)
        }
      }
    }
  }
}
#endif
