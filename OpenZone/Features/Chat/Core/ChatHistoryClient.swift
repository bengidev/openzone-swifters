import ComposableArchitecture
import Foundation
import SwiftData

/// Persistence boundary for chat history. Pure domain types cross this API;
/// SwiftData entities never leak past it. Writes happen at turn boundaries
/// only — the reducer persists the user message on send and the assistant
/// message once on completion. There are no per-delta writes and no
/// partial-on-error persistence.
struct ChatHistoryClient: Sendable {
    /// All conversations, most-recently-updated first, for the sidebar list.
    var listConversations: @Sendable () async throws -> [ChatConversation]
    /// Restore the ordered messages for a conversation when it is reopened.
    var loadMessages: @Sendable (_ conversationID: UUID) async throws -> [ChatMessage]
    /// Upsert a conversation's metadata (id/title/timestamps).
    var saveConversation: @Sendable (_ conversation: ChatConversation) async throws -> Void
    /// Append (or upsert by id) a single message into a conversation. Used for
    /// the user message on send and the finalized assistant message on
    /// completion.
    var appendMessage: @Sendable (_ conversationID: UUID, _ message: ChatMessage) async throws -> Void
    /// Delete a conversation and its messages.
    var deleteConversation: @Sendable (_ conversationID: UUID) async throws -> Void
    /// Pin or unpin a conversation, floating it to the top of history.
    var setPinned: @Sendable (_ conversationID: UUID, _ isPinned: Bool) async throws -> Void
    /// Rename a conversation's title.
    var renameConversation: @Sendable (_ conversationID: UUID, _ title: String) async throws -> Void
}

extension ChatHistoryClient: DependencyKey {
    /// Inert no-op store used by tests/previews and as the unwired default:
    /// list returns empty, loads return nothing, writes are dropped. Keeps
    /// reducer tests free of SwiftData and the network. The app overrides this
    /// with `.live(modelContainer:)` in `AppFeature`, so the no-op only stands
    /// in when no container is wired (tests, previews).
    private static func noop() -> ChatHistoryClient {
        ChatHistoryClient(
            listConversations: { [] },
            loadMessages: { _ in [] },
            saveConversation: { _ in },
            appendMessage: { _, _ in },
            deleteConversation: { _ in },
            setPinned: { _, _ in },
            renameConversation: { _, _ in }
        )
    }

    static let liveValue = noop()
    static let testValue = noop()
    static let previewValue = noop()
}

extension DependencyValues {
    var chatHistoryClient: ChatHistoryClient {
        get { self[ChatHistoryClient.self] }
        set { self[ChatHistoryClient.self] = newValue }
    }
}

// MARK: - Live (SwiftData)

extension ChatHistoryClient {
    /// Live client backed by SwiftData. Each call opens a fresh `ModelContext`
    /// on the container; mapping to/from the pure domain types happens here at
    /// the boundary so neither the reducer nor the domain ever sees an entity.
    @MainActor
    static func live(modelContainer: ModelContainer) -> Self {
        Self(
            listConversations: { @MainActor in
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<ChatHistoryConversationEntity>(
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
                // Pinned conversations float to the top; within each group the
                // most-recently-updated comes first. Sectioning by recency is a
                // presentation concern handled in the view, not here.
                return try context.fetch(descriptor)
                    .map(Self.conversation(from:))
                    .sorted { lhs, rhs in
                        if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                        return lhs.updatedAt > rhs.updatedAt
                    }
            },
            loadMessages: { @MainActor conversationID in
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchConversation(conversationID, in: context) else {
                    return []
                }
                return entity.messages
                    .sorted { $0.order < $1.order }
                    .compactMap(Self.message(from:))
            },
            saveConversation: { @MainActor conversation in
                let context = ModelContext(modelContainer)
                let entity: ChatHistoryConversationEntity
                if let existing = try Self.fetchConversation(conversation.id, in: context) {
                    entity = existing
                    entity.title = conversation.title
                    entity.updatedAt = conversation.updatedAt
                } else {
                    entity = ChatHistoryConversationEntity(
                        id: conversation.id,
                        title: conversation.title,
                        createdAt: conversation.createdAt,
                        updatedAt: conversation.updatedAt
                    )
                    context.insert(entity)
                }
                try context.save()
            },
            appendMessage: { @MainActor conversationID, message in
                let context = ModelContext(modelContainer)
                guard let conversation = try Self.fetchConversation(conversationID, in: context) else {
                    return
                }

                // Upsert by message id so a re-finalized assistant row (same id)
                // updates in place rather than duplicating.
                if let existing = conversation.messages.first(where: { $0.id == message.id }) {
                    Self.apply(message, to: existing)
                } else {
                    let nextOrder = (conversation.messages.map(\.order).max() ?? -1) + 1
                    let entity = Self.entity(from: message, order: nextOrder)
                    entity.conversation = conversation
                    conversation.messages.append(entity)
                    context.insert(entity)
                }
                conversation.updatedAt = message.timestamp
                try context.save()
            },
            deleteConversation: { @MainActor conversationID in
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchConversation(conversationID, in: context) else {
                    return
                }
                context.delete(entity)
                try context.save()
            },
            setPinned: { @MainActor conversationID, isPinned in
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchConversation(conversationID, in: context) else {
                    return
                }
                entity.isPinned = isPinned
                try context.save()
            },
            renameConversation: { @MainActor conversationID, title in
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchConversation(conversationID, in: context) else {
                    return
                }
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                entity.title = trimmed
                try context.save()
            }
        )
    }

    @MainActor
    private static func fetchConversation(
        _ id: UUID,
        in context: ModelContext
    ) throws -> ChatHistoryConversationEntity? {
        var descriptor = FetchDescriptor<ChatHistoryConversationEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: Entity -> Domain

    private static func conversation(from entity: ChatHistoryConversationEntity) -> ChatConversation {
        ChatConversation(
            id: entity.id,
            title: entity.title,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            isPinned: entity.isPinned
        )
    }

    private static func message(from entity: ChatHistoryMessageEntity) -> ChatMessage? {
        guard let kind = ChatHistoryMessageKind(rawValue: entity.kindRaw),
              let role = ChatMessageRole(rawValue: entity.roleRaw) else {
            return nil
        }
        switch kind {
        case .text:
            return .text(
                id: entity.id,
                role: role,
                content: entity.content,
                isComplete: entity.isComplete,
                timestamp: entity.timestamp
            )
        case .thinking:
            return .thinking(
                id: entity.id,
                role: role,
                content: entity.content,
                isComplete: entity.isComplete,
                timestamp: entity.timestamp
            )
        case .system:
            return .system(
                id: entity.id,
                content: entity.content,
                timestamp: entity.timestamp
            )
        }
    }

    // MARK: Domain -> Entity

    private static func entity(from message: ChatMessage, order: Int) -> ChatHistoryMessageEntity {
        ChatHistoryMessageEntity(
            id: message.id,
            kindRaw: kind(of: message).rawValue,
            roleRaw: message.role.rawValue,
            content: content(of: message),
            isComplete: isComplete(of: message),
            timestamp: message.timestamp,
            order: order
        )
    }

    private static func apply(_ message: ChatMessage, to entity: ChatHistoryMessageEntity) {
        entity.kindRaw = kind(of: message).rawValue
        entity.roleRaw = message.role.rawValue
        entity.content = content(of: message)
        entity.isComplete = isComplete(of: message)
        entity.timestamp = message.timestamp
    }

    private static func kind(of message: ChatMessage) -> ChatHistoryMessageKind {
        switch message {
        case .text: return .text
        case .thinking: return .thinking
        case .system: return .system
        }
    }

    private static func content(of message: ChatMessage) -> String {
        switch message {
        case let .text(payload): return payload.content
        case let .thinking(payload): return payload.content
        case let .system(payload): return payload.content
        }
    }

    private static func isComplete(of message: ChatMessage) -> Bool {
        switch message {
        case let .text(payload): return payload.isComplete
        case let .thinking(payload): return payload.isComplete
        case .system: return true
        }
    }
}
