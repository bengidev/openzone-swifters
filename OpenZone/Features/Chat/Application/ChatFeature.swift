import ComposableArchitecture
import Foundation

nonisolated private enum ChatStreamingCancelID: Hashable, Sendable {
    case streaming
}

@Reducer
struct ChatFeature {
  @Dependency(ChatAPIClient.self) private var apiClient
  @Dependency(\.date.now) private var now
  @Dependency(\.uuid) private var uuid

  @ObservableState
  struct State: Equatable {
    var conversation: ChatConversation?
    var messages: [ChatMessage] = []
    var draftMessage = ""
    var isSending = false
    var streamingStatus: ChatStreamingStatus = .idle
    var currentPartialText = ""
    var currentPartialThinking = ""
    var streamErrorMessage: String?
    var modelID = "mock-assistant"

    /// Stable identity of the in-flight reasoning row for the current turn.
    /// Reasoning deltas always merge into THIS row — even when they arrive
    /// interleaved with, or after, answer text — so we never spawn a second
    /// "Thinking" row. Reset to nil when a turn finishes.
    var streamingThinkingID: UUID?
    /// Stable identity of the in-flight assistant answer row for the current turn.
    var streamingAnswerID: UUID?
  }

  enum Action: Equatable {
    case draftMessageChanged(String)
    case sendMessageTapped
    case streamingEvent(ChatStreamingEvent)
    case streamFailed(String)
    case streamCompleted
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .draftMessageChanged(text):
        state.draftMessage = text
        return .none

      case .sendMessageTapped:
        let content = state.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !state.isSending else {
          return .none
        }

        state.draftMessage = ""
        state.isSending = true
        state.streamingStatus = .running
        state.currentPartialText = ""
        state.currentPartialThinking = ""
        state.streamErrorMessage = nil
        state.streamingThinkingID = nil
        state.streamingAnswerID = nil

        let timestamp = now
        let userMessage = ChatMessage.text(
          id: uuid(),
          role: .user,
          content: content,
          timestamp: timestamp
        )
        state.messages.append(userMessage)

        if state.conversation == nil {
          state.conversation = ChatConversation(
            id: uuid(),
            title: Self.conversationTitle(for: content),
            createdAt: timestamp,
            updatedAt: timestamp
          )
        } else {
          state.conversation?.title = Self.conversationTitle(for: content)
          state.conversation?.updatedAt = timestamp
        }

        let conversationID = state.conversation?.id ?? uuid()
        let request = ChatRequest(
          conversationID: conversationID,
          messages: state.messages,
          modelID: state.modelID
        )
        let stream = apiClient.stream(request)

        return .run { send in
          for await event in stream {
            await send(.streamingEvent(event))
          }
        }
        .cancellable(id: ChatStreamingCancelID.streaming, cancelInFlight: true)

      case let .streamingEvent(event):
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
            let newID = uuid()
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
            let newID = uuid()
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
          state.currentPartialText = ""
          state.currentPartialThinking = ""
          state.streamingThinkingID = nil
          state.streamingAnswerID = nil
          state.streamingStatus = .done
          state.isSending = false
          return .send(.streamCompleted)

        case let .error(streamError):
          state.streamingStatus = .failed
          state.streamErrorMessage = streamError.message
          state.isSending = false
          state.currentPartialText = ""
          state.currentPartialThinking = ""
          state.streamingThinkingID = nil
          state.streamingAnswerID = nil
          return .send(.streamFailed(streamError.message))
        }

        return .none

      case .streamCompleted, .streamFailed:
        return .none
      }
    }
  }

  private static func conversationTitle(for content: String) -> String {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "New chat" }
    if trimmed.count <= 40 { return trimmed }
    return String(trimmed.prefix(40)) + "…"
  }
}
