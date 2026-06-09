import Foundation
import Testing

@testable import OpenZone

@Suite("Chat Turn Engine")
struct ChatTurnEngineTests {
    private let fixedNow = Date(timeIntervalSince1970: 0)

    private final class IDCollector: @unchecked Sendable {
        private(set) var ids: [UUID] = []
        private var counter = 0

        func makeID() -> UUID {
            counter += 1
            let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", counter))!
            ids.append(id)
            return id
        }
    }

    private func thinkingMessages(_ state: ChatTurnState) -> [ChatThinkingMessage] {
        state.messages.compactMap {
            if case let .thinking(message) = $0 { return message }
            return nil
        }
    }

    private func assistantText(_ state: ChatTurnState) -> String {
        state.messages.reversed().compactMap {
            if case let .text(message) = $0, message.role == .assistant { return message.content }
            return nil
        }.first ?? ""
    }

    @Test("Interleaved reasoning and text deltas merge into stable rows")
    func interleavedReasoningAndTextDeltas() {
        var state = ChatTurnState(streamingStatus: .running, isSending: true)
        let collector = IDCollector()
        let makeID = collector.makeID

        #expect(ChatTurnEngine.apply(event: .thinkingDelta("Weighing "), to: &state, now: fixedNow, makeID: makeID) == .none)
        #expect(ChatTurnEngine.apply(event: .thinkingDelta("options. "), to: &state, now: fixedNow, makeID: makeID) == .none)
        #expect(ChatTurnEngine.apply(event: .textDelta("Answer "), to: &state, now: fixedNow, makeID: makeID) == .none)
        #expect(ChatTurnEngine.apply(event: .thinkingDelta("(extra note) "), to: &state, now: fixedNow, makeID: makeID) == .none)
        #expect(ChatTurnEngine.apply(event: .textDelta("final."), to: &state, now: fixedNow, makeID: makeID) == .none)

        let thinking = thinkingMessages(state)
        #expect(thinking.count == 1)
        #expect(thinking.first?.content == "Weighing options. (extra note) ")
        #expect(thinking.first?.isComplete == false)
        #expect(assistantText(state) == "Answer final.")

        let reasoningIndex = state.messages.firstIndex { if case .thinking = $0 { return true }; return false }
        let answerIndex = state.messages.firstIndex {
            if case let .text(message) = $0, message.role == .assistant { return true }
            return false
        }
        #expect(reasoningIndex != nil && answerIndex != nil)
        #expect((reasoningIndex ?? 0) < (answerIndex ?? 0))
    }

    @Test("Late reasoning delta merges into existing reasoning row")
    func lateReasoningDeltaDoesNotSpawnExtraRow() {
        var state = ChatTurnState(streamingStatus: .running, isSending: true)
        let collector = IDCollector()
        let makeID = collector.makeID

        _ = ChatTurnEngine.apply(event: .thinkingDelta("a"), to: &state, now: fixedNow, makeID: makeID)
        _ = ChatTurnEngine.apply(event: .textDelta("answer"), to: &state, now: fixedNow, makeID: makeID)
        _ = ChatTurnEngine.apply(event: .thinkingDelta("b"), to: &state, now: fixedNow, makeID: makeID)

        #expect(thinkingMessages(state).count == 1)
        #expect(thinkingMessages(state).first?.content == "ab")
        #expect(assistantText(state) == "answer")
    }

    @Test("Done finalizes streaming rows and resets accumulators")
    func doneFinalizesStreamingRows() {
        var state = ChatTurnState(streamingStatus: .running, isSending: true)
        let collector = IDCollector()
        let makeID = collector.makeID

        _ = ChatTurnEngine.apply(event: .thinkingDelta("thinking…"), to: &state, now: fixedNow, makeID: makeID)
        _ = ChatTurnEngine.apply(event: .textDelta("ok"), to: &state, now: fixedNow, makeID: makeID)

        let outcome = ChatTurnEngine.apply(event: .done, to: &state, now: fixedNow, makeID: makeID)

        #expect(thinkingMessages(state).count == 1)
        #expect(thinkingMessages(state).allSatisfy { $0.isComplete })
        #expect(state.streamingStatus == .done)
        #expect(state.isSending == false)
        #expect(state.currentPartialText == "")
        #expect(state.currentPartialThinking == "")
        #expect(state.streamingThinkingID == nil)
        #expect(state.streamingAnswerID == nil)

        guard case let .turnCompleted(finalizedMessages) = outcome else {
            Issue.record("Expected turnCompleted outcome")
            return
        }
        #expect(finalizedMessages.count == 2)
        #expect(finalizedMessages.map(\.id) == [collector.ids[0], collector.ids[1]])
        #expect(finalizedMessages.allSatisfy { message in
            switch message {
            case let .thinking(thinking): thinking.isComplete
            case let .text(text): text.isComplete
            case .system: false
            }
        })
    }

    @Test("Error resets streaming accumulators and reports failure")
    func errorResetsStreamingState() {
        var state = ChatTurnState(streamingStatus: .running, isSending: true)
        let collector = IDCollector()
        let makeID = collector.makeID

        _ = ChatTurnEngine.apply(event: .thinkingDelta("partial"), to: &state, now: fixedNow, makeID: makeID)
        _ = ChatTurnEngine.apply(event: .textDelta("also"), to: &state, now: fixedNow, makeID: makeID)

        let outcome = ChatTurnEngine.apply(
            event: .error(ChatStreamError(message: "network down")),
            to: &state,
            now: fixedNow,
            makeID: makeID
        )

        #expect(outcome == .turnFailed(message: "network down"))
        #expect(state.streamingStatus == .failed)
        #expect(state.isSending == false)
        #expect(state.currentPartialText == "")
        #expect(state.currentPartialThinking == "")
        #expect(state.streamingThinkingID == nil)
        #expect(state.streamingAnswerID == nil)
        // Partial rows remain in the timeline; only accumulators reset.
        #expect(state.messages.count == 2)
    }
}
