import ComposableArchitecture
import Foundation

/// TCA reducer for the chat history sidebar: visibility, list load/filter,
/// and pin/rename/delete mutations. Selection and cross-feature sync are
/// reported to the parent via delegate actions.
@Reducer
struct ChatHistoryFeature {
    @Dependency(ChatHistoryClient.self) private var chatHistory

    @ObservableState
    struct State: Equatable {
        var isSidebarVisible = false

        /// Persisted conversation history shown in the sidebar drawer,
        /// most-recently-updated first. Loaded when the sidebar opens.
        var conversations: [ChatConversation] = []

        /// Live text in the sidebar history search field. Filters the history
        /// list by title, case-insensitively. Empty means show everything.
        var historySearchQuery: String = ""

        /// Conversations after applying the history search filter. Pinned-first
        /// ordering from the client is preserved; sectioning happens in the view.
        var filteredConversations: [ChatConversation] {
            let query = historySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return conversations }
            return conversations.filter {
                $0.title.localizedCaseInsensitiveContains(query)
            }
        }
    }

    enum Action: Equatable {
        case sidebarToggleTapped
        case sidebarDismissed
        case conversationsLoaded([ChatConversation])
        case historySearchQueryChanged(String)
        case conversationPinToggled(ChatConversation)
        case conversationRenamed(id: UUID, title: String)
        case conversationDeleted(UUID)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case conversationSelected(ChatConversation)
            case conversationsChanged
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

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

            case let .conversationsLoaded(conversations):
                state.conversations = conversations
                return .send(.delegate(.conversationsChanged))

            case let .historySearchQueryChanged(query):
                // Filtering is synchronous over the already-loaded list, so the
                // field just mirrors into state; `filteredConversations` derives
                // the visible set. No debounce needed for a local title filter.
                state.historySearchQuery = query
                return .none

            case let .conversationPinToggled(conversation):
                // Optimistically flip the flag in state so the row reorders
                // immediately, then persist and reload to get the authoritative
                // pinned-first ordering back from the client.
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
                return .run { send in
                    try? await history.renameConversation(id, trimmed)
                    let conversations = (try? await history.listConversations()) ?? []
                    await send(.conversationsLoaded(conversations))
                }

            case let .conversationDeleted(id):
                let history = self.chatHistory
                return .run { send in
                    try? await history.deleteConversation(id)
                    let conversations = (try? await history.listConversations()) ?? []
                    await send(.conversationsLoaded(conversations))
                }
            }
        }
    }
}
