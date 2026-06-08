import ComposableArchitecture
import Foundation

/// TCA reducer for the post-onboarding home screen and composer.
@Reducer
struct HomeFeature {
    @Dependency(CredentialStoreClient.self) private var credentialStore
    @Dependency(AIProviderPreferenceClient.self) private var providerPreference
    @Dependency(ModelCatalogClient.self) private var modelCatalog
    @Dependency(ModelCatalogCachePreferenceClient.self) private var modelCatalogCachePreference
    @Dependency(ChatHistoryClient.self) private var chatHistory
    @Dependency(\.continuousClock) private var clock

    private nonisolated enum CancelID: Hashable, Sendable { case searchDebounce }

    @ObservableState
    struct State: Equatable {
        var chat = ChatFeature.State()
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

        /// The selected provider id, mirrored from the preference store. Defaults
        /// to the catalog default until the user (or a stored preference) sets it.
        var selectedProviderID: String = AIProviderAPI.default.id
        /// The selected dynamic model id, mirrored from the preference store.
        /// `nil` until a model is chosen; the send gate stays closed while nil.
        var selectedModelID: String?

        var reasoningModel: HomeComposerReasoningLevel = .high
        var speedMode: HomeComposerSpeedMode = .standard
        var contextUsage = HomeComposerContextUsage(usedTokens: 107_000, tokenLimit: 258_000)

        /// Whether a provider API key is stored. Sending is hard-blocked until
        /// this is true; the composer shows an empty-state hint pointing to
        /// Settings while it is false. Refreshed on appear and whenever the
        /// Settings sheet reports a change.
        var hasAPIKey = false

        /// The live catalog loaded by `ModelCatalogClient`. Falls back to the
        /// curated list (via `availableModels`) when empty.
        var catalogModels: [ChatModel] = []

        /// Whether the model popup is currently presented.
        var isModelPopupPresented = false

        /// The raw text in the model search field (bound to the text field,
        /// updated on every keystroke).
        var modelSearchQuery: String = ""
        /// The debounced query that actually drives `filteredModels`. Updated
        /// 300 ms after the user stops typing.
        var appliedSearchQuery: String = ""

        /// Whether the free-tier filter is active in the model popup.
        var modelFilterFreeOnly: Bool = false

        /// Presented Settings sheet, when non-nil.
        @Presents var settings: SettingsFeature.State?

        /// The presentation option for the current selection, resolved first
        /// from the live catalog, then from the curated fallback.
        var selectedModelOption: ChatModelOption? {
            guard let selectedModelID else { return nil }
            // Prefer live catalog entry so the richer metadata is shown.
            if let live = catalogModels.first(where: { $0.id == selectedModelID }) {
                return ChatModelOption(model: live)
            }
            return ChatModelCatalog.option(for: selectedModelID, providerID: selectedProviderID)
        }

        /// Models offered for the current provider, shown in the composer popup.
        /// Uses the live catalog when available, curated fallback otherwise.
        var availableModels: [ChatModelOption] {
            let source = catalogModels.isEmpty
                ? ChatModel.curatedFallback
                : catalogModels
            return source.map { ChatModelOption(model: $0) }
        }

        /// Subset of `availableModels` filtered by the current popup search
        /// query and free-only toggle.
        var filteredModels: [ChatModelOption] {
            var result = availableModels
            if modelFilterFreeOnly {
                result = result.filter { $0.isFree }
            }
            let query = appliedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return result }
            return result.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || $0.id.localizedCaseInsensitiveContains(query)
            }
        }

        /// Whether a model has been selected. Send is gated on this in addition
        /// to a stored key.
        var hasSelectedModel: Bool {
            selectedModelOption != nil
        }
    }

    enum Action: Equatable {
        case chat(ChatFeature.Action)
        case microphoneTapped
        case attachmentTapped
        case sidebarToggleTapped
        case sidebarDismissed
        case conversationsLoaded([ChatConversation])
        case conversationSelected(ChatConversation)
        case historySearchQueryChanged(String)
        case conversationPinToggled(ChatConversation)
        case conversationRenamed(id: UUID, title: String)
        case conversationDeleted(UUID)
        case composerModelSelected(String)
        case reasoningModelSelected(HomeComposerReasoningLevel)
        case speedModeSelected(HomeComposerSpeedMode)
        case onAppear
        case catalogLoaded([ChatModel])
        case modelPopupPresented(Bool)
        case modelSearchQueryChanged(String)
        case searchQueryDebounced(String)
        case modelFilterFreeOnlyChanged(Bool)
        case settingsButtonTapped
        case settings(PresentationAction<SettingsFeature.Action>)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.chat, action: \.chat) {
            ChatFeature()
        }
        Reduce { state, action in
            switch action {
            case .chat:
                return .none

            case .microphoneTapped, .attachmentTapped:
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
                return .none

            case let .conversationSelected(conversation):
                // Close the drawer and hand off to the chat reducer, which
                // restores the persisted messages and continues in the same
                // streaming reducer for the next turn.
                state.isSidebarVisible = false
                return .send(.chat(.reopenConversation(conversation)))

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
                // Keep the open conversation's title in sync if it was renamed.
                if state.chat.conversation?.id == id {
                    state.chat.conversation?.title = trimmed
                }
                return .run { send in
                    try? await history.renameConversation(id, trimmed)
                    let conversations = (try? await history.listConversations()) ?? []
                    await send(.conversationsLoaded(conversations))
                }

            case let .conversationDeleted(id):
                let history = self.chatHistory
                // If the deleted conversation is the one on screen, clear the
                // active chat so the user isn't left viewing a gone thread.
                if state.chat.conversation?.id == id {
                    return .merge(
                        .send(.chat(.clearActiveConversation)),
                        .run { send in
                            try? await history.deleteConversation(id)
                            let conversations = (try? await history.listConversations()) ?? []
                            await send(.conversationsLoaded(conversations))
                        }
                    )
                }
                return .run { send in
                    try? await history.deleteConversation(id)
                    let conversations = (try? await history.listConversations()) ?? []
                    await send(.conversationsLoaded(conversations))
                }

            case let .composerModelSelected(modelID):
                // The preference store is the single source of truth: persist the
                // selection, then mirror it into local state. Provider is stored
                // alongside the model so the chat request can resolve both.
                providerPreference.setProviderID(state.selectedProviderID)
                providerPreference.setModelID(modelID)
                state.selectedModelID = modelID
                state.isModelPopupPresented = false
                if let option = state.selectedModelOption,
                   !option.availableSpeedModes.contains(state.speedMode) {
                    state.speedMode = .standard
                }
                return .none

            case let .reasoningModelSelected(level):
                // Persist to the single source of truth, then mirror into state.
                providerPreference.setReasoningModel(level)
                state.reasoningModel = level
                return .none

            case let .speedModeSelected(speedMode):
                state.speedMode = speedMode
                return .none

            case .onAppear:
                state.hasAPIKey = credentialStore.secret() != nil
                // Seed the selection from the single source of truth so the
                // composer reflects any previously stored provider/model.
                let preference = providerPreference.preference()
                state.selectedProviderID = preference.providerID ?? AIProviderAPI.default.id
                state.selectedModelID = preference.modelID
                state.reasoningModel = preference.reasoningModel

                // Load the model catalog. The effect resolves the provider and
                // secret at call time so the result is always up to date.
                let provider = AIProviderAPI.resolve(id: state.selectedProviderID)
                let secret = credentialStore.secret()
                let cachePreference = modelCatalogCachePreference
                let catalogClient = modelCatalog
                return .run { send in
                    let models = await catalogClient.listModels(provider, secret, cachePreference, .shared)
                    await send(.catalogLoaded(models))
                }

            case let .catalogLoaded(models):
                state.catalogModels = models
                return .none

            case let .modelPopupPresented(isPresented):
                state.isModelPopupPresented = isPresented
                if isPresented {
                    // Reset search/filter whenever the popup opens.
                    state.modelSearchQuery = ""
                    state.appliedSearchQuery = ""
                    state.modelFilterFreeOnly = false
                }
                return .none

            case let .modelSearchQueryChanged(query):
                // Update the field binding immediately for responsive input,
                // then schedule a debounced commit to `appliedSearchQuery` so
                // the filtered list only recomputes after the user pauses.
                state.modelSearchQuery = query
                return .run { [clock] send in
                    try await clock.sleep(for: .milliseconds(300))
                    await send(.searchQueryDebounced(query))
                }
                .cancellable(id: CancelID.searchDebounce, cancelInFlight: true)

            case let .searchQueryDebounced(query):
                state.appliedSearchQuery = query
                return .none

            case let .modelFilterFreeOnlyChanged(freeOnly):
                state.modelFilterFreeOnly = freeOnly
                return .none

            case .settingsButtonTapped:
                state.settings = SettingsFeature.State(
                    hasStoredKey: credentialStore.secret() != nil,
                    reasoningModel: state.reasoningModel,
                    modelSupportsReasoning: state.selectedModelOption?.supportsReasoning == true
                )
                return .none

            case .settings(.presented(.reasoningModelSelected)):
                // The sheet wrote the level to the shared store; re-read it so
                // the composer chip reflects the change immediately on dismiss.
                state.reasoningModel = providerPreference.preference().reasoningModel
                return .none

            case .settings(.presented(.saveTapped)),
                 .settings(.presented(.clearTapped)):
                // The sheet just mutated stored credentials; re-read the source
                // of truth so the send gate reflects the change immediately.
                state.hasAPIKey = credentialStore.secret() != nil
                return .none

            case .settings(.dismiss):
                state.hasAPIKey = credentialStore.secret() != nil
                return .none

            case .settings:
                return .none
            }
        }
        .ifLet(\.$settings, action: \.settings) {
            SettingsFeature()
        }
    }
}
