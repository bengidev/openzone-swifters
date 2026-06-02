import ComposableArchitecture
import SwiftData

/// Root app reducer. Composes top-level feature domains and app-wide routing.
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var onboarding: OnboardingFeature.State

        init(onboarding: OnboardingFeature.State = .init()) {
            self.onboarding = onboarding
        }
    }

    enum Action: Equatable {
        case onboarding(OnboardingFeature.Action)
    }

    let onboardingPersistence: OnboardingPersistenceClient

    init(onboardingPersistence: OnboardingPersistenceClient = .preview) {
        self.onboardingPersistence = onboardingPersistence
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.onboarding, action: \.onboarding) {
            OnboardingFeature(persistence: onboardingPersistence)
        }
    }
}
