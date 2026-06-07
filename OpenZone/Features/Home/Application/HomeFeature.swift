import ComposableArchitecture
import Foundation

/// TCA reducer for the post-onboarding home screen and composer.
@Reducer
struct HomeFeature {
    @Dependency(CredentialStoreClient.self) private var credentialStore

    @ObservableState
    struct State: Equatable {
        var chat = ChatFeature.State()
        var isSidebarVisible = false
        var selectedModel: HomeComposerModelOption = .gpt54
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
    }

    enum Action: Equatable {
        case chat(ChatFeature.Action)
        case microphoneTapped
        case attachmentTapped
        case sidebarToggleTapped
        case sidebarDismissed
        case composerModelSelected(HomeComposerModelOption)
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

            case let .composerModelSelected(model):
                state.selectedModel = model
                if !model.availableSpeedModes.contains(state.speedMode) {
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
