import ComposableArchitecture
import Foundation

/// TCA reducer for the post-onboarding home screen and composer.
@Reducer
struct HomeFeature {
    @Dependency(CredentialStoreClient.self) private var credentialStore
    @Dependency(ProviderPreferenceClient.self) private var providerPreference

    @ObservableState
    struct State: Equatable {
        var chat = ChatFeature.State()
        var isSidebarVisible = false

        /// The selected provider id, mirrored from the preference store. Defaults
        /// to the catalog default until the user (or a stored preference) sets it.
        var selectedProviderID: String = ChatProvider.default.id
        /// The selected dynamic model id, mirrored from the preference store.
        /// `nil` until a model is chosen; the send gate stays closed while nil.
        var selectedModelID: String?

        var reasoningLevel: HomeComposerReasoningLevel = .high
        var speedMode: HomeComposerSpeedMode = .standard
        var contextUsage = HomeComposerContextUsage(usedTokens: 107_000, tokenLimit: 258_000)

        /// Whether a provider API key is stored. Sending is hard-blocked until
        /// this is true; the composer shows an empty-state hint pointing to
        /// Settings while it is false. Refreshed on appear and whenever the
        /// Settings sheet reports a change.
        var hasAPIKey = false

        /// Presented Settings sheet, when non-nil.
        @Presents var settings: SettingsFeature.State?

        /// The presentation option for the current selection, or `nil` when no
        /// model is selected or the stored id is not in the catalog.
        var selectedModelOption: ChatModelOption? {
            ChatModelCatalog.option(for: selectedModelID, providerID: selectedProviderID)
        }

        /// Models offered for the current provider, shown in the composer menu.
        var availableModels: [ChatModelOption] {
            ChatModelCatalog.models(for: selectedProviderID)
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
        case composerModelSelected(String)
        case reasoningLevelSelected(HomeComposerReasoningLevel)
        case speedModeSelected(HomeComposerSpeedMode)
        case onAppear
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
                return .none

            case .sidebarDismissed:
                state.isSidebarVisible = false
                return .none

            case let .composerModelSelected(modelID):
                // The preference store is the single source of truth: persist the
                // selection, then mirror it into local state. Provider is stored
                // alongside the model so the chat request can resolve both.
                providerPreference.setProviderID(state.selectedProviderID)
                providerPreference.setModelID(modelID)
                state.selectedModelID = modelID
                if let option = state.selectedModelOption,
                   !option.availableSpeedModes.contains(state.speedMode) {
                    state.speedMode = .standard
                }
                return .none

            case let .reasoningLevelSelected(level):
                state.reasoningLevel = level
                return .none

            case let .speedModeSelected(speedMode):
                state.speedMode = speedMode
                return .none

            case .onAppear:
                state.hasAPIKey = credentialStore.secret() != nil
                // Seed the selection from the single source of truth so the
                // composer reflects any previously stored provider/model.
                let preference = providerPreference.preference()
                state.selectedProviderID = preference.providerID ?? ChatProvider.default.id
                state.selectedModelID = preference.modelID
                return .none

            case .settingsButtonTapped:
                state.settings = SettingsFeature.State(hasStoredKey: credentialStore.secret() != nil)
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
