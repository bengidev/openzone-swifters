# Home Feature Context

| | |
| --- | --- |
| **Code** | `OpenZone/Features/Home/` |
| **Role-based layout** | `Core/`, `Models/`, `Views/`, `Utilities/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The Home feature manages the main landing screen where users start new conversations, configure AI provider preferences, and view recent chat history.

## Folder Structure

```text
OpenZone/Features/Home/
├── Core/
│   ├── HomeFeature.swift                    # Reducer + state management
│   ├── HomeModelCatalogClient.swift         # Model catalog fetching
│   └── HomeModelCatalogCachePreference.swift # Cache preferences
├── Models/
│   ├── HomeModelOption.swift                # Model selection value type
│   ├── HomeComposerSpeedMode.swift          # Speed mode selection
│   └── HomeComposerContextUsage.swift       # Context usage display
└── Views/
    ├── HomeView.swift                       # Main view container
    ├── HomeWelcomeView.swift                # Welcome state view
    ├── HomeComposerView.swift               # Message composer interface
    ├── HomeModelPopupView.swift             # Model selection popover
    └── HomeParticleOrbView.swift            # Animated orb visual
```

## Dependencies

**Required:**
- `OpenZone/Externals/` - Uses `ExternalAIProviderPreferenceStore`, `ExternalCredentialStore`
- `OpenZone/Shared/` - Uses `SharedAppTheme`, `SharedOpenZonePalette`

**Feature Dependencies:**
- `OpenZone/Features/Chat/` - Calls `ChatFeature.send()` to start conversations
- `OpenZone/Features/SidePanel/` - Embeds sidebar view for recent chats

## State Management (TCA)

The Home feature uses a single reducer pattern:

```swift
@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var composerMode: HomeComposerMode = .text
        var composerText: String = ""
        var speedMode: HomeComposerSpeedMode = .high
        var modelCatalog: HomeModelCatalog?
        var selectedProviderID: ProviderID = .openRouter
        // ... more state
    }
    
    enum Action {
        case onAppear
        case composerTextChanged(String)
        case speedModeChanged(HomeComposerSpeedMode)
        case sendMessage
        case delegate(Delegate)
        
        enum Delegate {
            case openChat(threadID: ThreadID)
        }
    }
}
```

## External Integrations

- **AI Provider API** - Fetches model catalog via `HomeModelCatalogClient`
- **Provider Preferences** - Reads/writes current provider ID via `ExternalAIProviderPreferenceStore`
- **Credentials** - Validates API keys via `ExternalCredentialStore` before sending messages
- **Chat History** - Reads recent threads to populate sidebar (uses Chat feature's persistence API)

## Cross-Feature Communication

Home communicates with other features through **delegate actions**:

```swift
// User taps on recent chat message
store.send(.delegate(.openChat(threadID: selectedThreadID)))

// Parent AppFeature routes to Chat feature
case .home(.delegate(.openChat(let threadID))):
    state.path.append(.chat(ChatFeature.State(threadID: threadID)))
```

## Recent Architecture Changes

- Restructured into role-based subfolders (Core/Models/Views/Utilities)
- Removed `HomeComposerReasoningLevel` shim - now uses `ExternalAIProviderReasoningModel`
- Renamed types to use `Home` prefix consistently
- Removed `public` modifiers (internal access by default)
