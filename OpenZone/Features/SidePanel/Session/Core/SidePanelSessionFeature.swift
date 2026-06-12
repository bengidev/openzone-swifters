import ComposableArchitecture
import Foundation

/// Owns the side panel's session scope (the saved-conversation browser, formerly
/// "history chat"). It holds the loaded conversation list, the sidebar
/// visibility, and the title search query, and persists pin/rename/delete edits
/// through `ChatHistoryClient`.
///
/// This reducer does not know about Chat or Home directly. When the user picks,
/// renames, or deletes the on-screen conversation, it emits a `delegate` action
/// so the parent can drive the live chat reducer. The currently open
/// conversation id is mirrored in via `activeConversationID` purely so the list
/// can highlight the active row; the session scope never owns the live thread.
@Reducer
struct SidePanelSessionFeature {
    @Dependency(ChatHistoryClient.self) private var chatHistory

    @ObservableState
    struct State: Equatable, Sendable {
        /// Whether the sliding drawer is presented.
        var isSidebarVisible = false

        /// Persisted conversation history shown in the drawer, most-recently-
        /// updated first. Loaded when the sidebar opens.
        var conversations: [ChatConversation] = []

        /// Live text in the history search field. Filters the list by title,
        /// case-insensitively. Empty means show everything.
        var historySearchQuery: String = ""

        /// The id of the conversation currently open in chat, mirrored from the
        /// parent so the row can render an active highlight. Not owned here.
        var activeConversationID: UUID?

        /// Conversations after applying the search filter. Pinned-first ordering
        /// from the client is preserved; sectioning happens in the view.
        var filteredConversations: [ChatConversation] {
            let query = historySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return conversations }
            return conversations.filter {
                $0.title.localizedCaseInsensitiveContains(query)
            }
        }

        init(
            isSidebarVisible: Bool = false,
            conversations: [ChatConversation] = [],
            historySearchQuery: String = "",
            activeConversationID: UUID? = nil
        ) {
            self.isSidebarVisible = isSidebarVisible
            self.conversations = conversations
            self.historySearchQuery = historySearchQuery
            self.activeConversationID = activeConversationID
        }
    }

    enum Action: Equatable {
        case sidebarToggleTapped
        case sidebarDismissed
        case settingsButtonTapped
        case conversationsLoaded([ChatConversation])
        case conversationSelected(ChatConversation)
        case historySearchQueryChanged(String)
        case conversationPinToggled(ChatConversation)
        case conversationRenamed(id: UUID, title: String)
        case conversationDeleted(UUID)
        case delegate(Delegate)

        /// Outputs the parent acts on. The session scope persists its own list
        /// changes; these tell the parent to drive the live chat reducer.
        @CasePathable
        enum Delegate: Equatable {
            /// The user picked a conversation to open in chat.
            case openConversation(ChatConversation)
            /// The on-screen conversation was renamed to `title`.
            case activeConversationRenamed(id: UUID, title: String)
            /// The on-screen conversation was deleted and should be cleared.
            case activeConversationDeleted(id: UUID)
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .sidebarToggleTapped:
                state.isSidebarVisible.toggle()
                // Refresh the history list each time the drawer opens so newly
                // persisted conversations appear without an app relaunch.
                guard state.isSidebarVisible else { return .none }
                let history = self.chatHistory
                return .run { send in
                    let conversations = (try? await history.listConversations()) ?? []
                    await send(.conversationsLoaded(conversations))
                }

            case .sidebarDismissed:
                state.isSidebarVisible = false
                return .none

            case .settingsButtonTapped:
                return .none

            case let .conversationsLoaded(conversations):
                state.conversations = conversations
                return .none

            case let .conversationSelected(conversation):
                // Close the drawer and hand off to the parent, which drives the
                // chat reducer to restore the persisted thread.
                state.isSidebarVisible = false
                return .send(.delegate(.openConversation(conversation)))

            case let .historySearchQueryChanged(query):
                // Filtering is synchronous over the already-loaded list, so the
                // field just mirrors into state; `filteredConversations` derives
                // the visible set. No debounce needed for a local title filter.
                state.historySearchQuery = query
                return .none

            case let .conversationPinToggled(conversation):
                // Persist then reload to get the authoritative pinned-first
                // ordering back from the client.
                let history = self.chatHistory
                let newValue = !conversation.isPinned
                let id = conversation.id
                return .run { send in
                    try? await history.setPinned(id, newValue)
                    let conversations = (try? await history.listConversations()) ?? []
                    await send(.conversationsLoaded(conversations))
                }

            case let .conversationRenamed(id, title):
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }
                let history = self.chatHistory
                // Tell the parent so it can keep the open thread's title in sync.
                let renameEffect: Effect<Action> = state.activeConversationID == id
                    ? .send(.delegate(.activeConversationRenamed(id: id, title: trimmed)))
                    : .none
                return .merge(
                    renameEffect,
                    .run { send in
                        try? await history.renameConversation(id, trimmed)
                        let conversations = (try? await history.listConversations()) ?? []
                        await send(.conversationsLoaded(conversations))
                    }
                )

            case let .conversationDeleted(id):
                let history = self.chatHistory
                // If the deleted conversation is the one on screen, tell the
                // parent to clear the active chat so the user isn't left viewing
                // a gone thread.
                let clearEffect: Effect<Action> = state.activeConversationID == id
                    ? .send(.delegate(.activeConversationDeleted(id: id)))
                    : .none
                return .merge(
                    clearEffect,
                    .run { send in
                        try? await history.deleteConversation(id)
                        let conversations = (try? await history.listConversations()) ?? []
                        await send(.conversationsLoaded(conversations))
                    }
                )

            case .delegate:
                return .none
            }
        }
    }
}
