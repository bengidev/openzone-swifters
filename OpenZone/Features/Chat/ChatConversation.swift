import Foundation

struct ChatConversation: Equatable, Identifiable, Sendable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    /// Whether the user pinned this conversation to the top of history.
    var isPinned: Bool

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }
}
