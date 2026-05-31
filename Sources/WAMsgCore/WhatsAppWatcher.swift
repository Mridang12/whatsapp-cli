import Foundation

public struct WhatsAppWatcherConfiguration: Sendable, Equatable {
  public let pollInterval: TimeInterval
  public let batchLimit: Int

  public init(pollInterval: TimeInterval = 0.5, batchLimit: Int = 100) {
    self.pollInterval = pollInterval
    self.batchLimit = batchLimit
  }
}

public final class WhatsAppWatcher: @unchecked Sendable {
  private let store: WhatsAppStore

  public init(store: WhatsAppStore) {
    self.store = store
  }

  public func stream(
    chatID: Int64? = nil,
    sinceRowID: Int64? = nil,
    configuration: WhatsAppWatcherConfiguration = WhatsAppWatcherConfiguration()
  ) -> AsyncThrowingStream<WhatsAppMessage, Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          var lastRowID = try sinceRowID ?? store.maxRowID()
          while !Task.isCancelled {
            let messages = try store.messagesAfter(
              afterRowID: lastRowID,
              chatID: chatID,
              limit: configuration.batchLimit
            )
            for message in messages {
              lastRowID = max(lastRowID, message.rowID)
              continuation.yield(message)
            }
            let sleepNanoseconds = UInt64(max(configuration.pollInterval, 0.1) * 1_000_000_000)
            try await Task.sleep(nanoseconds: sleepNanoseconds)
          }
        } catch is CancellationError {
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }
}

