import ComposableArchitecture
import Foundation

/// TCA reducer for the post-onboarding home welcome screen and composer.
@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var draftMessage = ""
        var isSending = false
        var isSidebarVisible = false
        var selectedModel: HomeComposerModelOption = .gpt54
        var reasoningLevel: HomeComposerReasoningLevel = .high
        var speedMode: HomeComposerSpeedMode = .standard
        var contextUsage = HomeComposerContextUsage(usedTokens: 107_000, tokenLimit: 258_000)
    }

    enum Action: Equatable {
        case draftMessageChanged(String)
        case sendMessageTapped
        case microphoneTapped
        case attachmentTapped
        case sidebarToggleTapped
        case sidebarDismissed
        case composerModelSelected(HomeComposerModelOption)
        case reasoningLevelSelected(HomeComposerReasoningLevel)
        case speedModeSelected(HomeComposerSpeedMode)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .draftMessageChanged(message):
                state.draftMessage = message
                return .none

            case .sendMessageTapped:
                let trimmed = state.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, !state.isSending else {
                    return .none
                }
                state.draftMessage = ""
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
