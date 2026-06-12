# SidePanel Feature Context

| | |
| --- | --- |
| **Code** | `OpenZone/Features/SidePanel/` |
| **Role-based layout** | `Core/`, `Models/`, `Views/`, `Utilities/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The SidePanel feature manages the navigation drawer and settings menu, providing access to app-wide settings and quick navigation between features.

## Folder Structure

```text
OpenZone/Features/SidePanel/
├── Core/
│   ├── SidePanelFeature.swift               # TCA Reducer + State
│   └── SidePanelAction.swift                # Menu action enumerations
├── Models/
│   ├── SidePanelMenuItem.swift              # Menu item value type
│   └── SidePanelSettings.swift              # App settings value type
├── Views/
│   ├── SidePanelView.swift                  # Main drawer container
│   ├── SidePanelHeaderView.swift            # User info and close button
│   ├── SidePanelMenuListView.swift          # Menu items list
│   └── SidePanelSettingsView.swift          # Settings sheet
└── Utilities/
    └── SidePanelMenuBuilder.swift           # Menu item factory
```

## Dependencies

**Required:**
- `OpenZone/Externals/` - Uses `ExternalAIProviderPreferenceStore`, `ExternalCredentialStore`
- `OpenZone/Shared/` - Uses `SharedAppTheme`, `SharedOpenZonePalette`, `SharedIconButton`

**Optional:**
- None - SidePanel is a leaf feature for navigation/settings

## State Management (TCA)

The SidePanel feature uses a single reducer pattern with menu state management:

```swift
@Reducer
struct SidePanelFeature {
    @ObservableState
    struct State: Equatable {
        var isOpen: Bool = false
        var menuItems: [SidePanelMenuItem] = []
        var settings: SidePanelSettings
        var isShowingSettings: Bool = false
    }
    
    enum Action {
        case onAppear
        case toggleOpen
        case menuItemTapped(SidePanelMenuItem.ID)
        case showSettings
        case hideSettings
        case settingChanged(SidePanelSettings.Key, Any)
        case logout
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .toggleOpen:
                state.isOpen.toggle()
                return .none
                
            case .menuItemTapped(let id):
                guard let item = state.menuItems.first(where: { $0.id == id }) else { 
                    return .none 
                }
                switch item.destination {
                case .home:
                    return .send(.delegate(.navigateToHome))
                case .chat(let id):
                    return .send(.delegate(.openChat(id: id)))
                case .newChat:
                    return .send(.delegate(.startNewChat))
                }
                
            case .showSettings:
                state.isShowingSettings = true
                return .none
                
            // ... other actions
            }
        }
    }
}
```

## External Integrations

- **Provider Preferences** - `ExternalAIProviderPreferenceStore` to read/display current provider
- **Credentials** - `ExternalCredentialStore` to check if credentials exist (for logout validation)
- **Theme** - `SharedAppTheme` to display current theme in settings

## Menu Items

The SidePanel provides navigation to:

1. **New Chat** - Starts a fresh conversation
2. **Recent Chats** - Opens chat history list
3. **Settings** - Opens app-wide settings sheet
4. **Help & Support** - External link to documentation
5. **Logout** - Clears credentials and returns to onboarding (if applicable)

## Cross-Feature Communication

SidePanel communicates navigation via delegate actions:

```swift
// User taps menu item
case .menuItemTapped(let id):
    // ... determine destination ...
    return .send(.delegate(.navigateToChat(id: chatID)))

// Parent AppRootView handles navigation
case .sidePanel(.delegate(.navigateToChat(let id))):
    state.path.append(.chat(conversationID: id))
    path.presentedState = .chat(ConversationFeature.State(conversationID: id))
```

## Settings Management

The SidePanel displays app-wide settings:

- **Theme** - Light/Dark/System theme selection
- **Provider** - Display current AI provider (read-only, configured in Onboarding)
- **Clear Data** - Reset app to fresh state (requires confirmation)

## Recent Architecture Changes

- Restructured into role-based subfolders (Core/Models/Views/Utilities)
- Added `SidePanel` prefix to all types for clarity
- Removed `public` modifiers (internal access by default)
- Simplified menu item model to use enum-based destinations instead of closures
