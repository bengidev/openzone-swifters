import ComposableArchitecture
import Foundation

/// TCA reducer for the post-onboarding home screen and composer.
@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var chat = ChatFeature.State()
        var isSidebarVisible = false
        var selectedModel: HomeComposerModelOption = .gpt54
        var reasoningLevel: HomeComposerReasoningLevel = .high
        var speedMode: HomeComposerSpeedMode = .standard
        var contextUsage = HomeComposerContextUsage(usedTokens: 107_000, tokenLimit: 258_000)
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
            }
        }
    }
}
