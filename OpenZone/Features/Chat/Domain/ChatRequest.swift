import Foundation

struct ChatRequest: Equatable, Sendable {
    let conversationID: UUID
    let messages: [ChatMessage]
    /// The provider descriptor this request is addressed to. Filled by the
    /// reducer from the preference store, so the request carries its own routing
    /// and the streaming client no longer captures a provider at construction.
    let provider: ChatProvider
    /// The dynamic model identifier (a free-form string, no longer an enum).
    let modelID: String

    init(
        conversationID: UUID,
        messages: [ChatMessage],
        provider: ChatProvider,
        modelID: String
    ) {
        self.conversationID = conversationID
        self.messages = messages
        self.provider = provider
        self.modelID = modelID
    }
}

extension ChatRequest {
    var latestUserText: String {
        Self.latestUserText(in: messages)
    }

    static func latestUserText(in messages: [ChatMessage]) -> String {
        messages
            .reversed()
            .compactMap { message -> String? in
                if case let .text(textMessage) = message, textMessage.role == .user {
                    return textMessage.content
                }
                return nil
            }
            .first ?? ""
    }
}
