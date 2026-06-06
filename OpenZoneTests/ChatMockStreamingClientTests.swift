import Foundation
import Testing

@testable import OpenZone

struct ChatMockStreamingClientTests {
    @Test
    func defaultClientEmitsThinkingDeltasTextDeltasAndDone() async {
        let client = ChatMockStreamingClient.fastClient()
        let request = ChatRequest(
            conversationID: UUID(),
            messages: [.text(role: .user, content: "Hello")],
            modelID: "mock"
        )
        let stream = client.stream(request: request)

        var events: [ChatStreamingEvent] = []
        for await event in stream {
            events.append(event)
        }

        #expect(events.contains { event in
            if case .thinkingDelta = event { return true }
            return false
        })
        #expect(events.contains { event in
            if case .textDelta = event { return true }
            return false
        })
        #expect(events.last == .done)
    }

    @Test
    func replyProviderUsesLatestUserMessage() {
        let reply = ChatMockReplyProvider.reply(for: "OpenZone")
        #expect(reply.contains("OpenZone"))
    }
}
