import Foundation

struct ChatMockStreamingClient: ChatAPIClientProtocol, Sendable {
    let delayNanoseconds: UInt64
    let thinkingDelayNanoseconds: UInt64

    nonisolated init(
        delayNanoseconds: UInt64 = 35_000_000,
        thinkingDelayNanoseconds: UInt64 = 45_000_000
    ) {
        self.delayNanoseconds = delayNanoseconds
        self.thinkingDelayNanoseconds = thinkingDelayNanoseconds
    }

    nonisolated func stream(request: ChatRequest) -> AsyncStream<ChatStreamingEvent> {
        let messages = request.messages
        return AsyncStream { continuation in
            Task {
                let userText = await MainActor.run {
                    ChatRequest.latestUserText(in: messages)
                }
                let thinking = ChatMockReplyProvider.thinkingSnippet(for: userText)
                let reply = ChatMockReplyProvider.reply(for: userText)

                // Stream reasoning token-by-token (realistic: each chunk arrives
                // with its own delay, not as one frozen block).
                for thinkingDelta in chunked(thinking) {
                    if thinkingDelayNanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: thinkingDelayNanoseconds)
                    }
                    continuation.yield(.thinkingDelta(thinkingDelta))
                }

                // Stream the answer token-by-token.
                for delta in chunked(reply) {
                    if delayNanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: delayNanoseconds)
                    }
                    continuation.yield(.textDelta(delta))
                }

                // A late reasoning "summary" chunk after the answer — exercises the
                // merge path (must land in the same reasoning row, not a new one).
                if let tail = ChatMockReplyProvider.thinkingTail(for: userText) {
                    if thinkingDelayNanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: thinkingDelayNanoseconds)
                    }
                    continuation.yield(.thinkingDelta(tail))
                }

                continuation.yield(.done)
                continuation.finish()
            }
        }
    }

    /// Splits text into word-sized streaming chunks (keeps trailing spaces).
    private nonisolated func chunked(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var chunks: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == " " {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}

extension ChatMockStreamingClient {
    nonisolated static func defaultClient() -> ChatMockStreamingClient {
        ChatMockStreamingClient()
    }

    nonisolated static func fastClient() -> ChatMockStreamingClient {
        ChatMockStreamingClient(
            delayNanoseconds: 0,
            thinkingDelayNanoseconds: 0
        )
    }
}
