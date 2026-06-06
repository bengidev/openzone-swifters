import Foundation

struct ChatRequest: Equatable, Sendable {
    let conversationID: UUID
    let messages: [ChatMessage]
    let modelID: String
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
