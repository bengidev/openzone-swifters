import Foundation

struct ChatConversation: Equatable, Identifiable, Sendable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    /// Whether the user pinned this conversation to the top of history.
    var isPinned: Bool

    /// Optional group name that places the conversation into a named folder
    /// in the history sidebar. `nil` means the conversation is ungrouped
    /// (appears in its recency bucket).
    var groupName: String?
    nonisolated init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        groupName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.groupName = groupName
    }
}
