import Foundation

enum ChatMessage: Equatable, Identifiable, Sendable {
    case text(ChatTextMessage)
    case thinking(ChatThinkingMessage)
    case system(ChatSystemMessage)

    private var payload: any ChatMessagePayload {
        switch self {
        case let .text(message):
            return message
        case let .thinking(message):
            return message
        case let .system(message):
            return message
        }
    }

    var id: UUID { payload.id }
    var role: ChatMessageRole { payload.role }
    var timestamp: Date { payload.timestamp }
}

extension ChatMessage {
    static func text(
        id: UUID = UUID(),
        role: ChatMessageRole,
        content: String,
        isComplete: Bool = true,
        timestamp: Date = Date()
    ) -> ChatMessage {
        .text(
            ChatTextMessage(
                id: id,
                role: role,
                content: content,
                isComplete: isComplete,
                timestamp: timestamp
            )
        )
    }

    static func thinking(
        id: UUID = UUID(),
        role: ChatMessageRole = .assistant,
        content: String,
        isComplete: Bool = true,
        timestamp: Date = Date()
    ) -> ChatMessage {
        .thinking(
            ChatThinkingMessage(
                id: id,
                role: role,
                content: content,
                isComplete: isComplete,
                timestamp: timestamp
            )
        )
    }

    static func system(
        id: UUID = UUID(),
        content: String,
        timestamp: Date = Date()
    ) -> ChatMessage {
        .system(
            ChatSystemMessage(
                id: id,
                role: .system,
                content: content,
                timestamp: timestamp
            )
        )
    }
}
