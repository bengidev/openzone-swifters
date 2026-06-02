import ComposableArchitecture
import Foundation

/// TCA reducer that owns the onboarding flow state and side effects.
@Reducer
struct OnboardingFeature {
    @ObservableState
    struct State: Equatable {
        var currentPage = 0
        var isFinished = false
        var selectedPromptIndex = 0
        var queuedPromptCount = 2
        var reasoningLevel = 0.62
        var pairingConfirmed = true

        var totalPages: Int { OnboardingPage.all.count }
        var isLastPage: Bool { currentPage >= totalPages - 1 }
        var currentPageData: OnboardingPage {
            let safeIndex = min(max(currentPage, 0), totalPages - 1)
            return OnboardingPage.all[safeIndex]
        }
    }

    enum Action: Equatable {
        case onAppear
        case completionLoaded(Bool)
        case nextButtonTapped
        case previousButtonTapped
        case pageSelected(Int)
        case skipButtonTapped
        case finishButtonTapped
        case completionSaved
        case promptChipTapped(Int)
        case addQueuedPromptButtonTapped
        case reasoningLevelChanged(Double)
        case pairingToggleTapped
    }

    let persistence: OnboardingPersistenceClient

    init(persistence: OnboardingPersistenceClient = .preview) {
        self.persistence = persistence
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let completed = (try? await persistence.isCompleted()) ?? false
                    await send(.completionLoaded(completed))
                }

            case let .completionLoaded(completed):
                state.isFinished = completed
                return .none

            case .nextButtonTapped:
                state.currentPage = min(state.currentPage + 1, state.totalPages - 1)
                return .none

            case .previousButtonTapped:
                state.currentPage = max(state.currentPage - 1, 0)
                return .none

            case let .pageSelected(index):
                state.currentPage = min(max(index, 0), state.totalPages - 1)
                return .none

            case .skipButtonTapped:
                state.currentPage = state.totalPages - 1
                return .none

            case .finishButtonTapped:
                state.isFinished = true
                return .run { send in
                    try? await persistence.complete()
                    await send(.completionSaved)
                }

            case .completionSaved:
                return .none

            case let .promptChipTapped(index):
                state.selectedPromptIndex = min(max(index, 0), OnboardingPromptOption.samples.count - 1)
                return .none

            case .addQueuedPromptButtonTapped:
                state.queuedPromptCount = state.queuedPromptCount >= OnboardingQueueItem.samples.count
                    ? 2
                    : state.queuedPromptCount + 1
                return .none

            case let .reasoningLevelChanged(value):
                state.reasoningLevel = min(max(value, 0), 1)
                return .none

            case .pairingToggleTapped:
                state.pairingConfirmed.toggle()
                return .none
            }
        }
    }
}
