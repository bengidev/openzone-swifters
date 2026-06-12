# Onboarding Feature Context

| | |
| --- | --- |
| **Code** | `OpenZone/Features/Onboarding/` |
| **Role-based layout** | `Core/`, `Models/`, `Views/`, `Utilities/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The Onboarding feature manages the first-time user setup flow, including welcome screens, provider selection, and initial credential configuration.

## Folder Structure

```text
OpenZone/Features/Onboarding/
├── Core/
│   ├── OnboardingFeature.swift              # TCA Reducer + State
│   └── OnboardingStep.swift                 # Step enum for flow control
├── Models/
│   ├── OnboardingProviderSelection.swift    # Provider choice value type
│   └── OnboardingCredentials.swift          # Initial credentials value type
├── Views/
│   ├── OnboardingView.swift                 # Main container view
│   ├── OnboardingWelcomeView.swift          # First welcome screen
│   ├── OnboardingProviderView.swift         # Provider selection screen
│   ├── OnboardingCredentialsView.swift      # API key entry screen
│   └── OnboardingCompletionView.swift       # Final confirmation screen
└── Utilities/
    └── OnboardingPersistence.swift          # Completion status persistence
```

## Dependencies

**Required:**
- `OpenZone/Externals/` - Uses `ExternalAIProviderAPI`, `ExternalCredentialStore`, `ExternalAIProviderPreferenceStore`
- `OpenZone/Shared/` - Uses `SharedAppTheme`, `SharedOpenZonePalette`, `SharedButtonStyle`

**Optional:**
- None - Onboarding is a leaf feature with no downstream dependencies

## State Management (TCA)

The Onboarding feature uses a single reducer pattern with step-based navigation:

```swift
@Reducer
struct OnboardingFeature {
    @ObservableState
    struct State: Equatable {
        var currentStep: OnboardingStep = .welcome
        var providerSelection: OnboardingProviderSelection?
        var credentials: OnboardingCredentials?
        var isCompleting: Bool = false
    }
    
    enum Action {
        case onAppear
        case nextTapped
        case backTapped
        case providerSelected(ProviderID)
        case credentialsEntered(apiKey: String)
        case complete
        case cancel
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .nextTapped:
                switch state.currentStep {
                case .welcome:
                    state.currentStep = .providerSelection
                case .providerSelection:
                    guard let provider = state.providerSelection else { return .none }
                    state.currentStep = .credentials(provider: provider)
                case .credentials:
                    state.currentStep = .completion
                case .completion:
                    return .send(.complete)
                }
                return .none
                
            case .complete:
                state.isCompleting = true
                // Persist onboarding completion
                // Save initial provider and credentials
                return .run { [provider = state.providerSelection, 
                                credentials = state.credentials] send in
                    try await OnboardingPersistence.markCompleted()
                    if let provider = provider {
                        try await ExternalAIProviderPreferenceStore.save(providerID: provider.id)
                    }
                    if let credentials = credentials {
                        try await ExternalCredentialStore.save(apiKey: credentials.apiKey, 
                                                               for: provider?.id ?? .openRouter)
                    }
                    await send(.completed)
                }
                
            // ... other actions
            }
        }
    }
}
```

## External Integrations

- **AI Provider API** - `ExternalAIProviderAPI.all` to show available providers
- **Provider Preferences** - `ExternalAIProviderPreferenceStore` to save selected provider ID
- **Credentials** - `ExternalCredentialStore` to save API key securely

## User Flow

1. **Welcome** - Introduction to OpenZone, explains what the app does
2. **Provider Selection** - User chooses from available AI providers (OpenRouter, OpenAI, CommandCode, etc.)
3. **Credentials Entry** - User enters API key for selected provider
4. **Completion** - Confirmation screen, then transition to Home feature

## Cross-Feature Communication

Onboarding communicates completion via parent router:

```swift
// OnboardingFeature sends completion delegate
case .complete:
    // ... persist data ...
    return .send(.delegate(.didComplete))

// AppRootView handles delegation and navigates to Home
case .onboarding(.delegate(.didComplete)):
    state.route = .home
```

## Recent Architecture Changes

- Restructured into role-based subfolders (Core/Models/Views/Utilities)
- Added `Onboarding` prefix to all types for clarity
- Removed `public` modifiers (internal access by default)
- Simplified step enum to use associated values for context-specific steps
