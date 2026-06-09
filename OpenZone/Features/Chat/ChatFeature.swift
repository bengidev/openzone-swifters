import ComposableArchitecture
import Foundation

nonisolated private enum ChatStreamingCancelID: Hashable, Sendable {
    case streaming
}

@Reducer
struct ChatFeature {
  @Dependency(ChatAPIClient.self) private var apiClient
  @Dependency(AIProviderPreferenceClient.self) private var providerPreference
  @Dependency(ChatHistoryClient.self) private var history
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
    /// User tapped Retry on the failure banner — re-issue the request for the
    /// last user message without appending a new one.
    case retryTapped
    /// User dismissed the failure banner.
    case errorDismissed
    /// Reopen a persisted conversation from the sidebar. Cancels any in-flight
    /// stream, swaps in the selected conversation, and triggers a message load.
    case reopenConversation(ChatConversation)
    /// Restored messages for a reopened conversation are folded into state.
    case messagesRestored([ChatMessage])
    /// Clear the active conversation and message thread (e.g. the open
    /// conversation was deleted from history). Cancels any in-flight stream.
    case clearActiveConversation
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .draftMessageChanged(text):
        state.draftMessage = text
        return .none

      case .sendMessageTapped:
        let content = state.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        // Send is gated on a non-empty draft, no in-flight turn, AND a selected
        // model. The preference store is the single source of truth for the
        // model identity; with no model chosen we never construct a request.
        let preference = providerPreference.preference()
        guard !content.isEmpty,
              !state.isSending,
              let modelID = preference.modelID else {
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
          provider: AIProviderAPI.resolve(id: preference.providerID),
          modelID: modelID,
          reasoningEffort: preference.reasoningModel.effort
        )
        let stream = apiClient.stream(request)

        // Persist at the turn boundary: the conversation metadata and the user
        // message are durable the moment send fires. The assistant message is
        // persisted later, once, in `.done` — never per-delta and never on a
        // failed/killed turn. We merge the persistence effect with streaming so
        // a write never blocks token delivery.
        let conversationToPersist = state.conversation
        let history = self.history
        return .merge(
          .run { _ in
            if let conversation = conversationToPersist {
              try? await history.saveConversation(conversation)
              try? await history.appendMessage(conversation.id, userMessage)
            }
          },
          .run { send in
            for await event in stream {
              await send(.streamingEvent(event))
            }
          }
          .cancellable(id: ChatStreamingCancelID.streaming, cancelInFlight: true)
        )

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

          // Persist the assistant's finalized output exactly once, at the turn
          // boundary. Only completed rows are written — a failed/killed turn
          // routes through `.error` and never reaches here, so partial
          // assistant text is never persisted. The user message was already
          // durable from the send path.
          let conversationID = state.conversation?.id
          let updatedConversation = state.conversation
          let finalizedMessages: [ChatMessage] = [
            state.streamingThinkingID,
            state.streamingAnswerID
          ]
          .compactMap { id in
            guard let id else { return nil }
            return state.messages.first(where: { $0.id == id })
          }
          let history = self.history

          state.currentPartialText = ""
          state.currentPartialThinking = ""
          state.streamingThinkingID = nil
          state.streamingAnswerID = nil
          state.streamingStatus = .done
          state.isSending = false

          return .merge(
            .run { _ in
              guard let conversationID else { return }
              if let updatedConversation {
                try? await history.saveConversation(updatedConversation)
              }
              for message in finalizedMessages {
                try? await history.appendMessage(conversationID, message)
              }
            },
            .send(.streamCompleted)
          )

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

      case .errorDismissed:
        state.streamErrorMessage = nil
        if state.streamingStatus == .failed {
          state.streamingStatus = .idle
        }
        return .none

      case .retryTapped:
        // Re-issue the request for the conversation as it already stands — the
        // last user message is still in `state.messages` from the failed turn,
        // so we do NOT append a new one. Send remains gated on a selected model.
        let preference = providerPreference.preference()
        guard !state.isSending,
              let modelID = preference.modelID,
              !state.messages.isEmpty else {
          return .none
        }

        state.isSending = true
        state.streamingStatus = .running
        state.currentPartialText = ""
        state.currentPartialThinking = ""
        state.streamErrorMessage = nil
        state.streamingThinkingID = nil
        state.streamingAnswerID = nil

        let conversationID = state.conversation?.id ?? uuid()
        let request = ChatRequest(
          conversationID: conversationID,
          messages: state.messages,
          provider: AIProviderAPI.resolve(id: preference.providerID),
          modelID: modelID,
          reasoningEffort: preference.reasoningModel.effort
        )
        let stream = apiClient.stream(request)

        return .run { send in
          for await event in stream {
            await send(.streamingEvent(event))
          }
        }
        .cancellable(id: ChatStreamingCancelID.streaming, cancelInFlight: true)

      case let .reopenConversation(conversation):
        // Swap in the selected conversation and clear all transient streaming
        // state. Any in-flight stream is cancelled so a reopened conversation
        // never receives deltas belonging to the previous one. Messages are
        // loaded asynchronously and folded in via `.messagesRestored`.
        state.conversation = conversation
        state.messages = []
        state.draftMessage = ""
        state.isSending = false
        state.streamingStatus = .idle
        state.currentPartialText = ""
        state.currentPartialThinking = ""
        state.streamErrorMessage = nil
        state.streamingThinkingID = nil
        state.streamingAnswerID = nil

        let history = self.history
        let conversationID = conversation.id
        return .concatenate(
          .cancel(id: ChatStreamingCancelID.streaming),
          .run { send in
            let restored = (try? await history.loadMessages(conversationID)) ?? []
            await send(.messagesRestored(restored))
          }
        )

      case let .messagesRestored(messages):
        state.messages = messages
        return .none

      case .clearActiveConversation:
        state.conversation = nil
        state.messages = []
        state.draftMessage = ""
        state.isSending = false
        state.streamingStatus = .idle
        state.currentPartialText = ""
        state.currentPartialThinking = ""
        state.streamErrorMessage = nil
        state.streamingThinkingID = nil
        state.streamingAnswerID = nil
        return .cancel(id: ChatStreamingCancelID.streaming)
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
