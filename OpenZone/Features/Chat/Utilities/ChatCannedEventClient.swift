import Foundation

/// A tiny canned-event chat client for tests and previews.
///
/// Replaces the deleted `ChatMockStreamingClient`/`ChatMockReplyProvider`: it
/// holds no reply-generation logic and touches no network. It simply replays a
/// fixed script of `ChatStreamingEvent`s — the realistic shape a streaming
/// reasoning model produces — so the reducer and previews can be exercised
/// deterministically.
///
/// The default script interleaves reasoning and answer deltas, including a late
/// reasoning delta after the answer began, which exercises the reducer's
/// merge-by-stable-id path.
nonisolated struct ChatCannedEventClient: ChatAPIClientProtocol, Sendable {
    let events: [ChatStreamingEvent]

    init(events: [ChatStreamingEvent] = ChatCannedEventClient.defaultScript) {
        self.events = events
    }

    nonisolated func stream(request: ChatRequest) -> AsyncStream<ChatStreamingEvent> {
        let events = self.events
        return AsyncStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}

extension ChatCannedEventClient {
    /// A representative interleaved reasoning + answer script ending in `.done`.
    static let defaultScript: [ChatStreamingEvent] = [
        .thinkingDelta("Weighing "),
        .thinkingDelta("options. "),
        .textDelta("Here is "),
        .thinkingDelta("(one more note) "),
        .textDelta("the answer."),
        .done
    ]
}
