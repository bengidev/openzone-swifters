import ComposableArchitecture
import Foundation

/// TCA reducer for the post-onboarding home screen and composer.
@Reducer
struct HomeFeature {
    @Dependency(CredentialStoreClient.self) private var credentialStore
    @Dependency(AIProviderPreferenceClient.self) private var providerPreference
    @Dependency(HomeModelCatalogClient.self) private var modelCatalog
    @Dependency(HomeModelCatalogCachePreferenceClient.self) private var modelCatalogCachePreference
    @Dependency(\.continuousClock) private var clock

    private nonisolated enum CancelID: Hashable, Sendable { case searchDebounce }

    @ObservableState
    struct State: Equatable {
        var chat = ChatFeature.State()

        /// The side panel module (session browser + settings sheet). Owns its
        /// own state; Home drives the live chat reducer in response to the
        /// panel's delegate outputs.
        var sidePanel = SidePanelFeature.State()

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

        /// The live catalog loaded by `HomeModelCatalogClient`. Falls back to the
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

        /// The presentation option for the current selection, resolved first
        /// from the live catalog, then from the curated fallback.
        var selectedModelOption: HomeModelOption? {
            guard let selectedModelID else { return nil }
            // Prefer live catalog entry so the richer metadata is shown.
            if let live = catalogModels.first(where: { $0.id == selectedModelID }) {
                return HomeModelOption(model: live)
            }
            return HomeModelCatalog.option(for: selectedModelID, providerID: selectedProviderID)
        }

        /// Models offered for the current provider, shown in the composer popup.
        /// Uses the live catalog when available, curated fallback otherwise.
        var availableModels: [HomeModelOption] {
            let source = catalogModels.isEmpty
                ? ChatModel.curatedFallback
                : catalogModels
            return source.map { HomeModelOption(model: $0) }
        }

        /// Subset of `availableModels` filtered by the current popup search
        /// query and free-only toggle.
        var filteredModels: [HomeModelOption] {
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
        case sidePanel(SidePanelFeature.Action)
        case microphoneTapped
        case attachmentTapped
        case composerModelSelected(String)
        case reasoningModelSelected(HomeComposerReasoningLevel)
        case speedModeSelected(HomeComposerSpeedMode)
        case onAppear
        case catalogLoaded([ChatModel])
        case modelPopupPresented(Bool)
        case modelSearchQueryChanged(String)
        case searchQueryDebounced(String)
        case modelFilterFreeOnlyChanged(Bool)
        case sidebarToggleTapped
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.chat, action: \.chat) {
            ChatFeature()
        }
        Scope(state: \.sidePanel, action: \.sidePanel) {
            SidePanelFeature()
        }
        Reduce { state, action in
            switch action {
            case .chat:
                return .none

            case .microphoneTapped, .attachmentTapped:
                return .none

            // MARK: Side panel button shortcuts (driven from the top bar / composer)

            case .sidebarToggleTapped:
                // Mirror the active conversation into the session scope so the
                // list can highlight the open thread, then toggle the drawer.
                state.sidePanel.session.activeConversationID = state.chat.conversation?.id
                return .send(.sidePanel(.session(.sidebarToggleTapped)))

            // MARK: Side panel delegate outputs

            case let .sidePanel(.delegate(.openConversation(conversation))):
                // Hand off to the chat reducer, which restores the persisted
                // messages and continues in the same streaming reducer.
                return .send(.chat(.reopenConversation(conversation)))

            case let .sidePanel(.delegate(.activeConversationRenamed(id, title))):
                // Keep the open conversation's title in sync if it was renamed.
                if state.chat.conversation?.id == id {
                    state.chat.conversation?.title = title
                }
                return .none

            case let .sidePanel(.delegate(.activeConversationDeleted(id))):
                // If the deleted conversation is on screen, clear the active
                // chat so the user isn't left viewing a gone thread.
                guard state.chat.conversation?.id == id else { return .none }
                return .send(.chat(.clearActiveConversation))

            case .sidePanel(.delegate(.credentialsChanged)):
                // The settings sheet mutated stored credentials; re-read the
                // source of truth so the send gate reflects the change.
                state.hasAPIKey = credentialStore.secret() != nil
                return .none

            case .sidePanel(.delegate(.reasoningModelChanged)):
                // The sheet wrote the level to the shared store; re-read it so
                // the composer chip reflects the change immediately on dismiss.
                state.reasoningModel = providerPreference.preference().reasoningModel
                return .none

            case .sidePanel:
                return .none

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
                state.sidePanel.modelSupportsReasoning =
                    state.selectedModelOption?.supportsReasoning == true
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
                state.sidePanel.modelSupportsReasoning =
                    state.selectedModelOption?.supportsReasoning == true

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
                state.sidePanel.modelSupportsReasoning =
                    state.selectedModelOption?.supportsReasoning == true
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
            }
        }
    }
}
