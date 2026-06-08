import ComposableArchitecture
import Foundation
import Testing

@testable import OpenZone

/// Reasoning-stream regression tests.
///
/// Reference guardrails (remodex/AGENTS.md):
///   - "Merge late reasoning deltas into existing rows; do not spawn fake extra 'Thinking...' rows."
///   - "Keep assistant rows item-scoped to avoid timeline flattening/reordering."
///
/// These exercise the reducer with scripted dummy events that interleave reasoning
/// and answer deltas — the realistic shape a real reasoning model produces.
@MainActor
@Suite("Chat Reasoning Streaming")
struct ChatReasoningStreamingTests {

    /// Builds a store whose API client replays a fixed script of dummy events.
    private func makeStore(
        events: [ChatStreamingEvent]
    ) -> TestStoreOf<ChatFeature> {
        TestStore(initialState: ChatFeature.State()) {
            ChatFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            // A model must be selected for the send gate to open; seed the
            // preference store with a provider + model.
            $0[AIProviderPreferenceClient.self] = .wrap(
                InMemoryAIProviderPreferenceStore(
                    preference: AIProviderPreference(
                        providerID: AIProviderAPI.openRouter.id,
                        modelID: "meta-llama/llama-3.3-70b-instruct:free"
                    )
                )
            )
            $0[ChatAPIClient.self] = ChatAPIClient(stream: { _ in
                AsyncStream { continuation in
                    for event in events { continuation.yield(event) }
                    continuation.finish()
                }
            })
        }
    }

    private func thinkingMessages(_ state: ChatFeature.State) -> [ChatThinkingMessage] {
        state.messages.compactMap {
            if case let .thinking(message) = $0 { return message }
            return nil
        }
    }

    private func assistantText(_ state: ChatFeature.State) -> String {
        state.messages.reversed().compactMap {
            if case let .text(message) = $0, message.role == .assistant { return message.content }
            return nil
        }.first ?? ""
    }

    /// REGRESSION: a reasoning delta arriving AFTER the answer started must merge into
    /// the existing reasoning row, not append a second "Thinking" row after the answer.
    @Test("Late reasoning delta merges into existing reasoning row")
    func lateReasoningDeltaDoesNotSpawnExtraRow() async {
        let store = makeStore(events: [
            .thinkingDelta("Weighing "),
            .thinkingDelta("options. "),
            .textDelta("Answer "),
            .thinkingDelta("(extra note) "),  // late reasoning delta
            .textDelta("final."),
            .done
        ])
        store.exhaustivity = .off

        await store.send(.draftMessageChanged("Hello"))
        await store.send(.sendMessageTapped)
        await store.receive(\.streamCompleted)

        let thinking = thinkingMessages(store.state)
        #expect(thinking.count == 1)
        #expect(thinking.first?.content == "Weighing options. (extra note) ")
        #expect(thinking.first?.isComplete == true)
        #expect(assistantText(store.state) == "Answer final.")

        // Reasoning row must precede the assistant answer in the timeline.
        let reasoningIndex = store.state.messages.firstIndex { if case .thinking = $0 { return true }; return false }
        let answerIndex = store.state.messages.firstIndex {
            if case let .text(m) = $0, m.role == .assistant { return true }; return false
        }
        #expect(reasoningIndex != nil && answerIndex != nil)
        #expect((reasoningIndex ?? 0) < (answerIndex ?? 0))
    }

    /// On `.done`, any in-flight reasoning row must be finalized (isComplete == true).
    @Test("Done finalizes reasoning row")
    func doneFinalizesReasoning() async {
        let store = makeStore(events: [
            .thinkingDelta("thinking…"),
            .textDelta("ok"),
            .done
        ])
        store.exhaustivity = .off

        await store.send(.draftMessageChanged("Test"))
        await store.send(.sendMessageTapped)
        await store.receive(\.streamCompleted)

        let thinking = thinkingMessages(store.state)
        #expect(thinking.count == 1)
        #expect(thinking.allSatisfy { $0.isComplete })
        #expect(store.state.streamingStatus == .done)
    }

    /// Reasoning that completes before any text still produces exactly one reasoning row.
    @Test("Reasoning-then-answer keeps a single reasoning row")
    func singleReasoningRowForBlockOrder() async {
        let store = makeStore(events: [
            .thinkingDelta("a"),
            .thinkingDelta("b"),
            .thinkingDelta("c"),
            .textDelta("answer"),
            .done
        ])
        store.exhaustivity = .off

        await store.send(.draftMessageChanged("Q"))
        await store.send(.sendMessageTapped)
        await store.receive(\.streamCompleted)

        #expect(thinkingMessages(store.state).count == 1)
        #expect(thinkingMessages(store.state).first?.content == "abc")
    }
}
