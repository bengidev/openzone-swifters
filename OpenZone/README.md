# OpenZone App

The main iOS application entry point.

## Purpose

OpenZone is a native SwiftUI iOS app that provides a chat interface for AI-powered conversations with multiple provider support.

## Architecture

### App Shell (`OpenZone/App/`)

- `OpenZoneApp.swift` - @main entry point and App lifecycle
- `AppRootView.swift` - Root view router with TCA store injection

### Features

Role-based TCA (The Composable Architecture) feature modules:

| Feature | Location | Description |
|---------|----------|-------------|
| **Home** | `Features/Home/` | Main chat interface, conversation threads |
| **Chat** | `Features/Chat/` | Message streaming, persistence entities |
| **Onboarding** | `Features/Onboarding/` | First-time user setup flow |
| **SidePanel** | `Features/SidePanel/` | Settings menu and navigation drawer |

Each feature follows role-based organization:
- `Core/` - TCA reducer, actions, state definitions
- `Models/` - Domain entities, value types
- `Views/` - SwiftUI view components
- `Utilities/` - Helpers and extensions

### Externals

- `Networking/` - AI provider API clients (ExternalAIProviderAPI, ExternalAIProviderCredentialAPI)
- `Security/` - Credential storage (ExternalCredentialStore)
- `Preference/` - User settings and provider preferences

### Shared

- `Theme/` - SharedAppTheme, SharedOpenZonePalette, colors
- `UI/` - Reusable components (buttons, cards, badges, modifiers)

## Build Configuration

- **Platform:** iOS 17.0+
- **Swift:** 6.0 (strict concurrency)
- **Dependencies:** The Composable Architecture, SwiftData

## Running

```bash
# Open in Xcode
open OpenZone.xcodeproj

# Build from command line
xcodebuild -project OpenZone.xcodeproj \
  -scheme OpenZone \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run tests
xcodebuild test -project OpenZone.xcodeproj \
  -scheme OpenZone \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Testing

- **Unit Tests:** `OpenZoneTests/` - Feature reducer and model logic
- **Integration Tests:** `OpenZoneIntegrationTests/` - API client and provider integration
- **UI Tests:** `OpenZoneUITests/` - End-to-end user flows

## Recent Architecture Updates

1. **Role-based folder structure** - Features now organize by Core/Models/Views/Utilities instead of flat structure
2. **Boundary prefixes** - Types use prefixes indicating ownership:
   - `Shared*` — cross-feature reusable
   - `External*` — external system adapters
   - `Home*`, `Chat*`, etc. — feature domain
3. **Persistence entity renaming** - `ChatConversationEntity`, `ChatMessageEntity` now include `History` in names
4. **Composition root** - App creates TCA store and dependencies, passes to root view
5. **Strict concurrency** - Swift 6.0 mode with explicit Sendable conformances
