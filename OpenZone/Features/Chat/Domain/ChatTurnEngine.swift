import Foundation

struct ChatTurnState: Equatable, Sendable {
    var messages: [ChatMessage] = []
    var currentPartialText = ""
    var currentPartialThinking = ""
    var streamingThinkingID: UUID?
    var streamingAnswerID: UUID?
    var streamingStatus: ChatStreamingStatus = .idle
    var isSending = false
}

enum ChatTurnApplyOutcome: Equatable, Sendable {
    case none
    case turnCompleted(finalizedMessages: [ChatMessage])
    case turnFailed(message: String)
}

enum ChatTurnEngine {
    static func apply(
        event: ChatStreamingEvent,
        to state: inout ChatTurnState,
        now: Date,
        makeID: () -> UUID
    ) -> ChatTurnApplyOutcome {
        switch event {
        case let .thinkingDelta(delta):
            state.currentPartialThinking += delta
            state.streamingStatus = .running

            // Merge into the turn's reasoning row by stable ID — never by "last
            // index". A reasoning delta that arrives after answer text began must
            // still land in the original reasoning row, not spawn a new one.
            if let thinkingID = state.streamingThinkingID,
               let index = state.messages.firstIndex(where: { $0.id == thinkingID }),
               case .thinking(var thinkingMessage) = state.messages[index] {
                thinkingMessage.content = state.currentPartialThinking
                thinkingMessage.isComplete = false
                state.messages[index] = .thinking(thinkingMessage)
            } else {
                let newID = makeID()
                state.streamingThinkingID = newID
                state.messages.append(
                    .thinking(
                        id: newID,
                        content: state.currentPartialThinking,
                        isComplete: false,
                        timestamp: now
                    )
                )
            }
            return .none

        case let .textDelta(delta):
            state.currentPartialText += delta
            state.streamingStatus = .running

            // Merge into the turn's answer row by stable ID.
            // NOTE: we do NOT mark reasoning complete or clear the reasoning
            // accumulator here — reasoning may resume after text (interleaved
            // streams). Finalization happens once, in `.done`.
            if let answerID = state.streamingAnswerID,
               let index = state.messages.firstIndex(where: { $0.id == answerID }),
               case .text(var textMessage) = state.messages[index] {
                textMessage.content = state.currentPartialText
                textMessage.isComplete = false
                state.messages[index] = .text(textMessage)
            } else {
                let newID = makeID()
                state.streamingAnswerID = newID
                state.messages.append(
                    .text(
                        id: newID,
                        role: .assistant,
                        content: state.currentPartialText,
                        isComplete: false,
                        timestamp: now
                    )
                )
            }
            return .none

        case .done:
            if let thinkingID = state.streamingThinkingID,
               let index = state.messages.firstIndex(where: { $0.id == thinkingID }),
               case .thinking(var thinkingMessage) = state.messages[index] {
                thinkingMessage.isComplete = true
                state.messages[index] = .thinking(thinkingMessage)
            }
            if let answerID = state.streamingAnswerID,
               let index = state.messages.firstIndex(where: { $0.id == answerID }),
               case .text(var textMessage) = state.messages[index] {
                textMessage.isComplete = true
                state.messages[index] = .text(textMessage)
            }

            let finalizedMessages: [ChatMessage] = [
                state.streamingThinkingID,
                state.streamingAnswerID
            ]
            .compactMap { id in
                guard let id else { return nil }
                return state.messages.first(where: { $0.id == id })
            }

            state.currentPartialText = ""
            state.currentPartialThinking = ""
            state.streamingThinkingID = nil
            state.streamingAnswerID = nil
            state.streamingStatus = .done
            state.isSending = false

            return .turnCompleted(finalizedMessages: finalizedMessages)

        case let .error(streamError):
            state.streamingStatus = .failed
            state.isSending = false
            state.currentPartialText = ""
            state.currentPartialThinking = ""
            state.streamingThinkingID = nil
            state.streamingAnswerID = nil
            return .turnFailed(message: streamError.message)
        }
    }
}
