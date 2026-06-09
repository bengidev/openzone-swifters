import ComposableArchitecture
import Foundation

/// Orchestrates the post-onboarding workspace: chat thread, history sidebar,
/// model catalog, and composer rail. Settings presentation is delegated to AppFeature.
@Reducer
struct HomeFeature {
    @Dependency(CredentialStoreClient.self) private var credentialStore
    @Dependency(AIProviderPreferenceClient.self) private var providerPreference

    @ObservableState
    struct State: Equatable {
        var chat = ChatFeature.State()
        var history = ChatHistoryFeature.State()
        var catalog = ModelCatalogFeature.State()
        var composer = ComposerFeature.State()

        /// Whether a provider API key is stored. Sending is hard-blocked until
        /// this is true. Refreshed on appear and when AppFeature reports credential changes.
        var hasAPIKey = false
    }

    enum Action: Equatable {
        case chat(ChatFeature.Action)
        case history(ChatHistoryFeature.Action)
        case catalog(ModelCatalogFeature.Action)
        case composer(ComposerFeature.Action)
        case onAppear
        case credentialStoreChanged
        case microphoneTapped
        case attachmentTapped
        case settingsButtonTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case openSettings(
                hasStoredKey: Bool,
                reasoningModel: AIProviderReasoningModel,
                modelSupportsReasoning: Bool
            )
        }
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.chat, action: \.chat) {
            ChatFeature()
        }
        Scope(state: \.history, action: \.history) {
            ChatHistoryFeature()
        }
        Scope(state: \.catalog, action: \.catalog) {
            ModelCatalogFeature()
        }
        Scope(state: \.composer, action: \.composer) {
            ComposerFeature()
        }
        Reduce { state, action in
            switch action {
            case .chat, .catalog, .composer:
                return .none

            case .delegate:
                return .none

            case .onAppear:
                state.hasAPIKey = credentialStore.secret() != nil
                let preference = providerPreference.preference()
                state.catalog.selectedProviderID = preference.providerID ?? AIProviderAPI.default.id
                state.catalog.selectedModelID = preference.modelID
                state.composer.reasoningModel = preference.reasoningModel
                return .send(.catalog(.loadCatalog))

            case .credentialStoreChanged:
                state.hasAPIKey = credentialStore.secret() != nil
                return .send(.catalog(.loadCatalog))

            case .microphoneTapped, .attachmentTapped:
                return .none

            case .settingsButtonTapped:
                return .send(.delegate(.openSettings(
                    hasStoredKey: credentialStore.secret() != nil,
                    reasoningModel: state.composer.reasoningModel,
                    modelSupportsReasoning: state.catalog.selectedModelOption?.supportsReasoning == true
                )))

            case let .history(.delegate(.conversationSelected(conversation))):
                return .send(.chat(.reopenConversation(conversation)))

            case .history(.delegate(.conversationsChanged)):
                return .none

            case let .history(.conversationRenamed(id, title)):
                if state.chat.conversation?.id == id {
                    state.chat.conversation?.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return .none

            case let .history(.conversationDeleted(id)):
                guard state.chat.conversation?.id == id else { return .none }
                return .send(.chat(.clearActiveConversation))

            case let .catalog(.modelSelected(modelID)):
                if let option = state.catalog.selectedModelOption,
                   !option.availableSpeedModes.contains(state.composer.speedMode) {
                    state.composer.speedMode = .standard
                }
                return .none

            case .history:
                return .none
            }
        }
    }
}
