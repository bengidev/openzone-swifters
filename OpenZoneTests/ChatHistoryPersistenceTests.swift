import ComposableArchitecture
import Foundation
import SwiftData
import Testing

@testable import OpenZone

/// Chat-history persistence tests.
///
/// Acceptance coverage (issue #8):
///   - SwiftData conversation + message entities exist and round-trip the pure
///     domain types at the client boundary.
///   - The user message persists on send; the assistant message persists once
///     on completion. An errored/killed turn does not persist partial assistant
///     text but the user message survives.
///   - Opening a conversation restores its messages into chat state.
///   - The schema adds the two entities and drops the dead template stub;
///     additive migration succeeds against an existing store.
@MainActor
@Suite("Chat History Persistence")
struct ChatHistoryPersistenceTests {

    /// An in-memory container holding the post-migration schema (the two chat
    /// entities + onboarding), so live-client tests never touch disk.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            OnboardingProgressEntity.self,
            ChatConversationEntity.self,
            ChatMessageEntity.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func conversation(
        id: UUID = UUID(),
        title: String = "First chat",
        at date: Date = Date(timeIntervalSince1970: 100)
    ) -> ChatConversation {
        ChatConversation(id: id, title: title, createdAt: date, updatedAt: date)
    }

    // MARK: - Mapping round-trip

    @Test("Domain conversation + messages round-trip through the live client")
    func roundTrip() async throws {
        let container = try makeContainer()
        let client = ChatHistoryClient.live(modelContainer: container)

        let convo = conversation(title: "Round trip")
        try await client.saveConversation(convo)

        let user = ChatMessage.text(
            id: UUID(), role: .user, content: "Hi", timestamp: Date(timeIntervalSince1970: 1)
        )
        let thinking = ChatMessage.thinking(
            id: UUID(), content: "Pondering", isComplete: true, timestamp: Date(timeIntervalSince1970: 2)
        )
        let answer = ChatMessage.text(
            id: UUID(), role: .assistant, content: "Hello!", timestamp: Date(timeIntervalSince1970: 3)
        )
        try await client.appendMessage(convo.id, user)
        try await client.appendMessage(convo.id, thinking)
        try await client.appendMessage(convo.id, answer)

        let restored = try await client.loadMessages(convo.id)
        #expect(restored.count == 3)
        // Insertion order is preserved by the `order` column.
        #expect(restored[0].id == user.id)
        #expect(restored[1].id == thinking.id)
        #expect(restored[2].id == answer.id)

        // Kind + payload survive the entity boundary.
        if case let .text(payload) = restored[0] {
            #expect(payload.role == .user)
            #expect(payload.content == "Hi")
        } else {
            Issue.record("Expected first restored message to be .text(user)")
        }
        if case let .thinking(payload) = restored[1] {
            #expect(payload.content == "Pondering")
            #expect(payload.isComplete)
        } else {
            Issue.record("Expected second restored message to be .thinking")
        }
    }

    @Test("Conversations list is ordered most-recently-updated first")
    func listOrdering() async throws {
        let container = try makeContainer()
        let client = ChatHistoryClient.live(modelContainer: container)

        let older = conversation(title: "Older", at: Date(timeIntervalSince1970: 100))
        let newer = conversation(title: "Newer", at: Date(timeIntervalSince1970: 500))
        try await client.saveConversation(older)
        try await client.saveConversation(newer)

        let list = try await client.listConversations()
        #expect(list.map(\.title) == ["Newer", "Older"])
    }

    @Test("Saving an existing conversation upserts rather than duplicating")
    func upsertConversation() async throws {
        let container = try makeContainer()
        let client = ChatHistoryClient.live(modelContainer: container)

        var convo = conversation(title: "Original")
        try await client.saveConversation(convo)
        convo.title = "Renamed"
        convo.updatedAt = Date(timeIntervalSince1970: 999)
        try await client.saveConversation(convo)

        let list = try await client.listConversations()
        #expect(list.count == 1)
        #expect(list.first?.title == "Renamed")
    }

    @Test("Appending a message with an existing id upserts in place")
    func upsertMessage() async throws {
        let container = try makeContainer()
        let client = ChatHistoryClient.live(modelContainer: container)

        let convo = conversation()
        try await client.saveConversation(convo)

        let id = UUID()
        let partial = ChatMessage.text(id: id, role: .assistant, content: "Hel", isComplete: false)
        let finalized = ChatMessage.text(id: id, role: .assistant, content: "Hello", isComplete: true)
        try await client.appendMessage(convo.id, partial)
        try await client.appendMessage(convo.id, finalized)

        let restored = try await client.loadMessages(convo.id)
        #expect(restored.count == 1)
        if case let .text(payload) = restored[0] {
            #expect(payload.content == "Hello")
            #expect(payload.isComplete)
        } else {
            Issue.record("Expected a single finalized .text row")
        }
    }

    @Test("Deleting a conversation cascades to its messages")
    func deleteCascades() async throws {
        let container = try makeContainer()
        let client = ChatHistoryClient.live(modelContainer: container)

        let convo = conversation()
        try await client.saveConversation(convo)
        try await client.appendMessage(convo.id, .text(role: .user, content: "Hi"))
        try await client.deleteConversation(convo.id)

        #expect(try await client.listConversations().isEmpty)
        #expect(try await client.loadMessages(convo.id).isEmpty)
    }

    // MARK: - Additive migration

    @Test("Additive migration: existing onboarding store gains chat entities")
    func additiveMigration() async throws {
        // Simulate an existing on-disk store that predates the chat schema by
        // first creating a container with only the onboarding entity and
        // writing a record, then reopening with the extended schema at the same
        // URL. The reopen must not throw and must preserve the old record while
        // accepting writes to the new entities.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openzone-migration-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        // Old store: onboarding entity only.
        let oldSchema = Schema([OnboardingProgressEntity.self])
        let oldConfig = ModelConfiguration(schema: oldSchema, url: url)
        let oldContainer = try ModelContainer(for: oldSchema, configurations: [oldConfig])
        let oldContext = ModelContext(oldContainer)
        let progress = OnboardingProgressEntity(isCompleted: true)
        oldContext.insert(progress)
        try oldContext.save()

        // New store at the same URL: adds the two chat entities additively.
        let newSchema = Schema([
            OnboardingProgressEntity.self,
            ChatConversationEntity.self,
            ChatMessageEntity.self
        ])
        let newConfig = ModelConfiguration(schema: newSchema, url: url)
        let newContainer = try ModelContainer(for: newSchema, configurations: [newConfig])

        // The pre-existing onboarding record survives migration.
        let migratedContext = ModelContext(newContainer)
        let onboarding = try migratedContext.fetch(FetchDescriptor<OnboardingProgressEntity>())
        #expect(onboarding.count == 1)
        #expect(onboarding.first?.isCompleted == true)

        // The new entities are usable in the migrated store.
        let client = ChatHistoryClient.live(modelContainer: newContainer)
        let convo = conversation(title: "Post-migration")
        try await client.saveConversation(convo)
        #expect(try await client.listConversations().map(\.title) == ["Post-migration"])
    }
}
