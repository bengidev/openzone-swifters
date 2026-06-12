import ComposableArchitecture
import SwiftData

/// Root app reducer. Composes top-level feature domains and app-wide routing.
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var onboarding: OnboardingFeature.State
        var home: HomeFeature.State

        init(
            onboarding: OnboardingFeature.State = .init(),
            home: HomeFeature.State = .init()
        ) {
            self.onboarding = onboarding
            self.home = home
        }
    }

    enum Action: Equatable {
        case onboarding(OnboardingFeature.Action)
        case home(HomeFeature.Action)
    }

    let onboardingPersistence: OnboardingPersistenceClient
    let chatHistory: ChatHistoryClient

    init(
        onboardingPersistence: OnboardingPersistenceClient = .preview,
        chatHistory: ChatHistoryClient = .testValue
    ) {
        self.onboardingPersistence = onboardingPersistence
        self.chatHistory = chatHistory
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.onboarding, action: \.onboarding) {
            OnboardingFeature(persistence: onboardingPersistence)
        }
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        .dependency(\.chatHistoryClient, chatHistory)
    }
}
