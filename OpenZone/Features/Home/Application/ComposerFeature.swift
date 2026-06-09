import ComposableArchitecture
import Foundation

/// Owns composer rail state: reasoning depth, speed mode, and context usage display.
@Reducer
struct ComposerFeature {
    @Dependency(AIProviderPreferenceClient.self) private var providerPreference

    @ObservableState
    struct State: Equatable {
        var reasoningModel: HomeComposerReasoningLevel = .high
        var speedMode: HomeComposerSpeedMode = .standard
        var contextUsage = HomeComposerContextUsage(usedTokens: 107_000, tokenLimit: 258_000)
    }

    enum Action: Equatable {
        case onAppear
        case reasoningModelSelected(HomeComposerReasoningLevel)
        case speedModeSelected(HomeComposerSpeedMode)
        case preferenceSynced(reasoningModel: AIProviderReasoningModel)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.reasoningModel = providerPreference.preference().reasoningModel
                return .none

            case let .reasoningModelSelected(level):
                providerPreference.setReasoningModel(level)
                state.reasoningModel = level
                return .none

            case let .speedModeSelected(speedMode):
                state.speedMode = speedMode
                return .none

            case let .preferenceSynced(reasoningModel):
                state.reasoningModel = reasoningModel
                return .none
            }
        }
    }
}
