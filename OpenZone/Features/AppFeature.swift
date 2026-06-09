import ComposableArchitecture
import SwiftData

/// Top-level route owned by the app shell reducer.
enum AppRoute: Equatable, Sendable {
    case onboarding
    case home
}

/// Root app reducer. Composes top-level feature domains, app-wide routing,
/// and the Settings sheet at the shell seam.
@Reducer
struct AppFeature {
    @Dependency(CredentialStoreClient.self) private var credentialStore
    @Dependency(AIProviderPreferenceClient.self) private var providerPreference

    @ObservableState
    struct State: Equatable {
        var route: AppRoute = .onboarding
        var onboarding: OnboardingFeature.State
        var home: HomeFeature.State
        @Presents var settings: SettingsFeature.State?

        init(
            route: AppRoute = .onboarding,
            onboarding: OnboardingFeature.State = .init(),
            home: HomeFeature.State = .init()
        ) {
            self.route = route
            self.onboarding = onboarding
            self.home = home
        }
    }

    enum Action: Equatable {
        case onboarding(OnboardingFeature.Action)
        case home(HomeFeature.Action)
        case settings(PresentationAction<SettingsFeature.Action>)
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
        Reduce { state, action in
            switch action {
            case let .onboarding(.completionLoaded(completed)):
                if completed {
                    state.route = .home
                }
                return .none

            case .onboarding(.completionSaved):
                state.route = .home
                return .none

            case let .home(.delegate(.openSettings(hasStoredKey, reasoningModel, modelSupportsReasoning))):
                state.settings = SettingsFeature.State(
                    hasStoredKey: hasStoredKey,
                    reasoningModel: reasoningModel,
                    modelSupportsReasoning: modelSupportsReasoning
                )
                return .none

            case .settings(.presented(.reasoningModelSelected)):
                let level = providerPreference.preference().reasoningModel
                return .send(.home(.composer(.preferenceSynced(reasoningModel: level))))

            case .settings(.presented(.saveTapped)),
                 .settings(.presented(.clearTapped)),
                 .settings(.dismiss):
                return .send(.home(.credentialStoreChanged))

            case .onboarding, .home, .settings:
                return .none
            }
        }
        .ifLet(\.$settings, action: \.settings) {
            SettingsFeature()
        }
    }
}
