import Foundation
import SwiftData

/// Persisted message kind discriminator. Mirrors the three `ChatMessage`
/// domain cases so the enum can be reconstructed losslessly at the client
/// boundary without leaking SwiftData types into the domain.
enum ChatMessageKind: String, Codable, Sendable {
    case text
    case thinking
    case system
}

/// SwiftData model for a persisted conversation. The pure domain type
/// (`ChatConversation`) is mapped to and from this entity only at the
/// `ChatHistoryClient` boundary — reducers never see SwiftData.
@Model
final class ChatConversationEntity {
    /// Domain conversation id. Unique so re-persisting an existing
    /// conversation upserts rather than duplicating.
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    /// Owned messages. Deleting a conversation cascades to its messages so the
    /// store never accumulates orphaned rows.
    @Relationship(deleteRule: .cascade, inverse: \ChatMessageEntity.conversation)
    var messages: [ChatMessageEntity]

    init(
        id: UUID,
        title: String,
        createdAt: Date,
        updatedAt: Date,
        messages: [ChatMessageEntity] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

/// SwiftData model for a persisted message. `kind` discriminates which domain
/// case to rebuild; `role`/`isComplete` carry the remaining payload. `order`
/// preserves turn ordering independent of timestamp collisions.
@Model
final class ChatMessageEntity {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var roleRaw: String
    var content: String
    var isComplete: Bool
    var timestamp: Date
    /// Monotonic insertion index within the conversation. Sorting by this
    /// (not timestamp) keeps user/assistant turns in the exact emitted order.
    var order: Int

    var conversation: ChatConversationEntity?

    init(
        id: UUID,
        kindRaw: String,
        roleRaw: String,
        content: String,
        isComplete: Bool,
        timestamp: Date,
        order: Int,
        conversation: ChatConversationEntity? = nil
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.roleRaw = roleRaw
        self.content = content
        self.isComplete = isComplete
        self.timestamp = timestamp
        self.order = order
        self.conversation = conversation
    }
}
