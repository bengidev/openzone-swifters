import ComposableArchitecture
import Foundation
import Testing

@testable import OpenZone

/// Reducer-level tests for the persistence + reopen behavior wired into
/// `ChatFeature`. These use a recording stub `ChatHistoryClient` so we assert
/// exactly which writes happen at which turn boundary without SwiftData.
@MainActor
@Suite("Chat History Reducer")
struct ChatHistoryReducerTests {

    /// A recording history client backed by an actor so the `@Sendable`
    /// closures can capture mutations safely under strict concurrency.
    private actor Recorder {
        var savedConversations: [ChatConversation] = []
        var appended: [(conversationID: UUID, message: ChatMessage)] = []
        var stored: [UUID: [ChatMessage]] = [:]

        func save(_ conversation: ChatConversation) { savedConversations.append(conversation) }
        func append(_ id: UUID, _ message: ChatMessage) { appended.append((id, message)) }
        func seed(_ id: UUID, _ messages: [ChatMessage]) { stored[id] = messages }
        func messages(_ id: UUID) -> [ChatMessage] { stored[id] ?? [] }
    }

    /// Classify appended messages into role/kind tags. Lives on the suite
    /// (main-actor) because `ChatMessage.role` is main-actor-isolated and can
    /// not be read from inside the `Recorder` actor.
    private func appendedKinds(_ recorder: Recorder) async -> [String] {
        await recorder.appended.map {
            switch $0.message {
            case .text(let payload): return payload.role == .user ? "user" : "assistant"
            case .thinking: return "thinking"
            case .system: return "system"
            }
        }
    }

    private func makeClient(_ recorder: Recorder) -> ChatHistoryClient {
        ChatHistoryClient(
            listConversations: { await recorder.savedConversations },
            loadMessages: { await recorder.messages($0) },
            saveConversation: { await recorder.save($0) },
            appendMessage: { await recorder.append($0, $1) },
            deleteConversation: { _ in },
            setPinned: { _, _ in },
            renameConversation: { _, _ in }
        )
    }

    private func makeStore(
        recorder: Recorder,
        events: [ChatStreamingEvent]
    ) -> TestStoreOf<ChatFeature> {
        TestStore(initialState: ChatFeature.State()) {
            ChatFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0[AIProviderPreferenceClient.self] = .wrap(
                InMemoryAIProviderPreferenceStore(
                    preference: AIProviderPreference(
                        providerID: AIProviderAPI.openRouter.id,
                        modelID: "meta-llama/llama-3.3-70b-instruct:free"
                    )
                )
            )
            $0[ChatHistoryClient.self] = makeClient(recorder)
            $0[ChatAPIClient.self] = ChatAPIClient(stream: { _ in
                AsyncStream { continuation in
                    for event in events { continuation.yield(event) }
                    continuation.finish()
                }
            })
        }
    }

    @Test("User message persists on send; assistant persists once on completion")
    func persistsAtTurnBoundaries() async throws {
        let recorder = Recorder()
        let store = makeStore(recorder: recorder, events: [
            .thinkingDelta("hmm"),
            .textDelta("Hello"),
            .done
        ])
        store.exhaustivity = .off

        await store.send(.draftMessageChanged("Hi"))
        await store.send(.sendMessageTapped)
        await store.receive(\.streamCompleted)

        // The user message persists on send; the finalized thinking + assistant
        // rows persist on completion. No per-delta writes occurred.
        let kinds = await appendedKinds(recorder)
        #expect(kinds == ["user", "thinking", "assistant"])

        let saved = await recorder.savedConversations
        #expect(!saved.isEmpty)
    }

    @Test("Errored turn does not persist assistant text but user message survives")
    func erroredTurnKeepsUserMessageOnly() async throws {
        let recorder = Recorder()
        let store = makeStore(recorder: recorder, events: [
            .textDelta("partial"),
            .error(ChatStreamError(message: "boom"))
        ])
        store.exhaustivity = .off

        await store.send(.draftMessageChanged("Hi"))
        await store.send(.sendMessageTapped)
        await store.receive(\.streamFailed)

        // Only the user message was persisted; the partial assistant text was
        // never written because the turn routed through `.error`, not `.done`.
        let kinds = await appendedKinds(recorder)
        #expect(kinds == ["user"])
    }

    @Test("Reopening a conversation restores its messages into chat state")
    func reopenRestoresMessages() async throws {
        let recorder = Recorder()
        let conversationID = UUID()
        let restored: [ChatMessage] = [
            .text(id: UUID(), role: .user, content: "Earlier question"),
            .text(id: UUID(), role: .assistant, content: "Earlier answer")
        ]
        await recorder.seed(conversationID, restored)

        let store = makeStore(recorder: recorder, events: [])
        store.exhaustivity = .off

        let conversation = ChatConversation(
            id: conversationID,
            title: "Earlier chat",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        await store.send(.reopenConversation(conversation)) {
            $0.conversation = conversation
            $0.messages = []
        }
        await store.receive(\.messagesRestored) {
            $0.messages = restored
        }

        #expect(store.state.messages.count == 2)
        #expect(store.state.conversation?.id == conversationID)
    }
}
