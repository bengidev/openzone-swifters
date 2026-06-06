import Foundation

struct ChatTextMessage: ChatMessagePayload, Equatable, Identifiable, Sendable, Codable {
    let id: UUID
    let role: ChatMessageRole
    var content: String
    var isComplete: Bool
    let timestamp: Date

    nonisolated init(
        id: UUID = UUID(),
        role: ChatMessageRole,
        content: String,
        isComplete: Bool = true,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.isComplete = isComplete
        self.timestamp = timestamp
    }
}

struct ChatThinkingMessage: ChatMessagePayload, Equatable, Identifiable, Sendable, Codable {
    let id: UUID
    let role: ChatMessageRole
    var content: String
    var isComplete: Bool
    let timestamp: Date

    nonisolated init(
        id: UUID = UUID(),
        role: ChatMessageRole,
        content: String,
        isComplete: Bool = true,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.isComplete = isComplete
        self.timestamp = timestamp
    }
}

struct ChatSystemMessage: ChatMessagePayload, Equatable, Identifiable, Sendable, Codable {
    let id: UUID
    let role: ChatMessageRole
    var content: String
    let timestamp: Date

    nonisolated init(
        id: UUID = UUID(),
        role: ChatMessageRole = .system,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
