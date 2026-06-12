# Context Map

This repository uses a domain-driven documentation structure where each bounded context has its own `*-CONTEXT.md` file documenting that context's domain, responsibilities, and relationships with other contexts.

## Contexts

| Context | Location | Description |
|---------|----------|-------------|
| [App Shell](app/App-CONTEXT.md) | `OpenZone/App/` | Application entry point, TCA store composition, root routing |
| [Home Feature](home/Home-CONTEXT.md) | `OpenZone/Features/Home/` | Main chat interface and conversation management |
| [Chat Feature](chat/Chat-CONTEXT.md) | `OpenZone/Features/Chat/` | Message streaming, persistence, and history entities |
| [Onboarding Feature](onboarding/Onboarding-CONTEXT.md) | `OpenZone/Features/Onboarding/` | First-time user setup and welcome flow |
| [SidePanel Feature](sidepanel/SidePanel-CONTEXT.md) | `OpenZone/Features/SidePanel/` | Settings menu and navigation drawer |
| [Externals](externals/Externals-CONTEXT.md) | `OpenZone/Externals/` | External system adapters (APIs, storage, preferences) |
| [Shared](shared/Shared-CONTEXT.md) | `OpenZone/Shared/` | Cross-feature UI components and theme |

## Architecture Overview

### Role-Based Organization

Each feature follows a consistent role-based structure:

```
OpenZone/
├── App/                          # Composition root
│   ├── OpenZoneApp.swift
│   └── AppRootView.swift
├── Features/                     # Feature modules
│   ├── Home/
│   │   ├── Core/                # TCA reducer, actions, state
│   │   ├── Models/              # Domain entities
│   │   ├── Views/               # UI components
│   │   └── Utilities/           # Helpers
│   ├── Chat/
│   ├── Onboarding/
│   └── SidePanel/
├── Externals/                    # External adapters
│   ├── Networking/              # API clients
│   ├── Security/                # Credential stores
│   └── Preference/              # User settings
└── Shared/                       # Reusable components
    ├── Theme/                   # Colors, fonts, palette
    └── UI/                      # Buttons, cards, modifiers
```

### Boundary Prefixes

Types use prefixes to indicate ownership and scope:

- **Shared*** — Cross-feature reusable components (e.g., `SharedAppTheme`, `SharedOpenZonePalette`)
- **External*** — External system adapters (e.g., `ExternalAIProviderAPI`, `ExternalCredentialStore`)
- **Home***, **Chat***, **Onboarding***, **SidePanel*** — Feature domain types

### Type Naming Conventions

#### Persistence Entities (Models/)

Suffix: `Entity`

**Entities** (`OpenZone/Features/.../Models/*.swift`):
- Use `Entity` suffix for SwiftData `@Model` types
- Prefix with sub-scope name if the type belongs to a sub-domain
- Example: `ChatHistoryConversationEntity`, `ChatHistoryMessageEntity` (ChatHistory sub-scope of Chat feature)

```swift
@Model
public final class ChatHistoryConversationEntity {
    @Attribute(.unique) public let id: UUID
    public var title: String
    public var lastModified: Date
}

@Model
public final class ChatHistoryMessageEntity {
    @Attribute(.unique) public let id: UUID
    public var content: String
    public var role: String
}
```

- `ChatConversationEntity` (not `HistoryConversationEntity`)
- `ChatMessageEntity` (not `HistoryMessageEntity`)
- Use sub-scope prefix when needed (e.g., `ChatHistory` for Chat feature's history domain)

#### Dependency Values (Core/)

TCA dependency keys use `@Dependency` wrapper:

```swift
private enum AIProviderKey: DependencyKey {
    static let liveValue: ExternalAIProviderAPI = .live
}

extension DependencyValues {
    var aiProvider: ExternalAIProviderAPI {
        get { self[AIProviderKey.self] }
        set { self[AIProviderKey.self] = newValue }
    }
}
```

**Pattern:** Lowercase camelCase, no prefix/suffix required

#### State Values (Core/)

Value types used in TCA state use descriptive names:

```swift
struct ConversationState: Equatable {
    var id: ConversationID
    var title: String
    var messages: [Message]
}
```

**Pattern:** Descriptive name + `State` suffix when appropriate

### Access Control

All types are `internal` by default:

```swift
// ✅ Correct
struct ConversationState: Equatable { ... }
final class ConversationEntity { ... }

// ❌ Incorrect (unless explicit cross-module requirement)
public struct ConversationState: Equatable { ... }
```

**Rationale:** Swift 6 strict concurrency + role-based organization means implicit boundaries work naturally without explicit `public`/`internal` modifiers.

### Swift 6 Strict Concurrency

All code must conform to Swift 6.0 strict concurrency:

```swift
@MainActor
struct HomeFeature: Reducer {
    // Reducer runs on main actor
}

// Models use implicit Sendable
struct Message: Equatable, Sendable {
    let id: MessageID
    let content: String
}

// External clients use explicit actors
actor ExternalCredentialStore {
    // Isolated credential storage
}
```

## Dependency Flow

```
┌─────────────────────────────────────────────────────────┐
│                        App Layer                         │
│  OpenZoneApp → AppRootView → Feature Stores              │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                     Feature Layer                         │
│  Home ←→ Chat ←→ Onboarding ←→ SidePanel                 │
│  (communicate via delegate actions)                      │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                    Externals Layer                        │
│  AIProviderAPI • CredentialStore • PreferenceStore       │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                     Shared Layer                          │
│  Theme • UI Components • Extensions                      │
└─────────────────────────────────────────────────────────┘
```

## Cross-Feature Communication

Features communicate through **delegate actions** rather than direct dependencies:

```swift
// HomeFeature sends delegate when user taps message
case .messageTapped(let id):
    return .send(.delegate(.viewConversation(id: id)))

// Parent router (AppRootView) handles delegation
case .home(.delegate(.viewConversation(let id))):
    state.path.append(.chat(conversationID: id))
```

## Recent Changes (December 2024)

1. **Role-based folder structure** — Features organized into Core/Models/Views/Utilities instead of flat file lists
2. **Boundary prefixes** — Added `Shared*`, `External*` prefixes for clarity
3. **Persistence entity renaming** — Dropped `History` prefix from conversation/message entities
4. **Composition root pattern** — App shell now creates TCA store and injects dependencies
5. **Shim removal** — Removed `HomeComposerReasoningLevel` compatibility layer
6. **Public modifier cleanup** — Removed unnecessary `public` keywords (internal is default)
7. **Strict concurrency** — Full Swift 6.0 compliance with explicit Sendable conformances

## Navigation Guide

### Adding a New Feature

1. Create feature folder: `OpenZone/Features/YourFeature/`
2. Add role-based subdirectories: `Core/`, `Models/`, `Views/`, `Utilities/`
3. Create reducer in `Core/YourFeatureFeature.swift`
4. Add context file: `docs/contexts/yourfeature/YourFeature-CONTEXT.md`
5. Update this Context Map with new feature entry
6. Wire up in App shell if needed

### Modifying Existing Features

1. Read the feature's `*-CONTEXT.md` file first
2. Follow the role-based structure (don't add files at feature root)
3. Use appropriate prefixes for new types
4. Keep types `internal` unless cross-module sharing is required
5. Update context file if adding new responsibilities

### Working with Persistence

1. Entities go in `Models/` folder with `Entity` suffix
2. Use SwiftData `@Model` macro
3. Keep entities as pure data holders (no business logic)
4. Create repository/client for database operations in `Core/`

### Integrating External APIs

1. API clients go in `Externals/Networking/`
2. Use `External*` prefix for all adapters
3. Expose via TCA `DependencyValues`
4. Document in `Externals-CONTEXT.md`

## Documentation Conventions

- **Location:** All docs in `docs/` directory
- **Naming:** `<Context>-CONTEXT.md` for context documentation
- **Content:** Each context file includes Purpose, Responsibilities, Dependencies, State Management, and External Integrations sections
- **Code examples:** Show actual patterns from codebase, not theoretical examples
- **Tables:** Use for summarizing type relationships and responsibilities

## File Index

```
docs/
├── CONTEXT-MAP.md                    # This file
├── architecture/
│   ├── swift-6-strictness.md         # Concurrency rules
│   └── modules.md                    # Organization rules
└── contexts/
    ├── app/
    │   └── App-CONTEXT.md
    ├── chat/
    │   └── Chat-CONTEXT.md
    ├── externals/
    │   └── Externals-CONTEXT.md
    ├── home/
    │   └── Home-CONTEXT.md
    ├── onboarding/
    │   └── Onboarding-CONTEXT.md
    ├── shared/
    │   └── Shared-CONTEXT.md
    └── sidepanel/
        └── SidePanel-CONTEXT.md
```
