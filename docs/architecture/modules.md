# Module Layout

Part of this repo's multi-context documentation. See [CONTEXT-MAP.md](../../CONTEXT-MAP.md) for per-feature glossaries and [docs/agents/domain.md](../agents/domain.md) for how agents consume domain docs.

OpenZone uses feature-oriented folders inside the app target. The folders are intentionally shaped like modules so they can be promoted to internal Swift Package or Xcode framework targets later without rewriting the feature boundaries.

State management is implemented with [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture). New product workflows should follow the same reducer/store pattern.

Swift code must also follow the repo's Swift 6 strictness rules in `docs/architecture/swift-6-strictness.md`.

## Module map

The app is a single root that composes feature modules as siblings, plus a cross-cutting shared layer. `SidePanel` is one module that hosts two sub-scopes — `Session` (saved-conversation browsing, formerly "history chat") and `Setting` (app preferences):

```text
App
├── Shared        # API/Theme/Credential + UI primitives (cross-cutting)
├── Onboarding
├── Home
├── Chat
└── SidePanel
    ├── Session    # SidePanelSession… (ex "history chat")
    └── Setting    # SidePanelSetting…
```

## Current layout

```text
OpenZone/
├── App/                      # App shell
│   ├── OpenZoneApp.swift
│   └── Core/
│       └── AppFeature.swift
├── Features/
│   ├── Onboarding/           # Role-based
│   │   └── (Core/Models/Views/Utilities)
│   ├── Home/                 # Role-based
│   │   └── (Core/Models/Views)
│   ├── Chat/                 # Role-based
│   │   └── (Core/Models/Views/Utilities)
│   └── SidePanel/            # Hosts Session + Setting sub-scopes
│       ├── Session/          # Role-based
│       │   └── (Core/Views)
│       └── Setting/          # Role-based
│           └── (Core/Views)
├── Externals/                # External integrations (internal module)
│   ├── Networking/
│   ├── Preference/
│   └── Security/
└── Shared/                   # Cross-cutting UI primitives
    ├── Theme/
    └── UI/
```

> **Role-based folders**: Each feature organizes files by responsibility — `Core/` (reducers, clients), `Models/` (domain types, entities), `Views/` (SwiftUI), `Utilities/` (helpers, factories). This structure supports future SPM package extraction.
>
> **Type prefixes**: Boundary prefixes clarify ownership — `Shared…` for cross-cutting types (`SharedOpenZonePalette`, `SharedAppTheme`), `External…` for integration adapters (`ExternalAIProviderAPI`, `ExternalCredentialStore`). Features use scope prefixes (`HomeComposerView`, `ChatMessage`). Sub-scopes extend the parent (`SidePanelSessionView`).

## State management rules

- The app root owns a `StoreOf<AppFeature>`.
- Each feature owns a TCA reducer named `<FeatureName>Feature`.
- Feature views receive `StoreOf<<FeatureName>Feature>` and send actions through `store.send(...)`.
- Do not add separate `@Observable` view-model classes for TCA-backed features. State belongs in `@ObservableState`; mutations belong in reducer actions.
- Side effects (persistence, networking, system adapters) run from reducer effects and use explicit dependency clients.
- Tests should use `TestStore` for reducer behavior, plus normal view/unit tests where useful.

## File naming

One type per file; the file name matches its primary type. The suffix conveys the type's **role**, not the module — the module is already conveyed by the scope prefix.

- `…Feature` — a TCA reducer (`@Reducer struct …Feature`). There is normally exactly one per module. The `Feature` suffix is reserved for reducers; do not append it to non-reducer files.
- `…View` — a SwiftUI view (`HomeView`, `ChatThreadView`, `OnboardingView`, `SidePanelSettingView`).
- `…Client` — a dependency client used from reducer effects (`ChatHistoryClient`, `HomeModelCatalogClient`).
- Everything else — named after the value type / enum it defines (`ChatMessage`, `HomeModelOption`, `OnboardingPage`).

So within a module only the single reducer file carries `Feature`; every other file is named by its role. This is why most files have no `Feature` suffix — they aren't reducers.

> Note: a literal "Feature" inside a domain name (e.g. `OnboardingFeatureHighlight`, `OnboardingFeaturePageView` — "feature highlight" as a product concept) is part of the noun, not the reducer suffix, and does not imply a reducer.

## Ownership rules

### `OpenZone/Features/<FeatureName>/`

A feature owns one product workflow. Its folder organizes files by role — reducers in `Core/`, domain types in `Models/`, SwiftUI in `Views/`, helpers in `Utilities/`. Use scope-prefixed type names (e.g. `HomeFeature`, `HomeComposerView`, `ChatHistoryClient`).

Feature code may depend on `OpenZone/Externals`, `OpenZone/Shared`, Swift standard libraries, Apple frameworks, TCA, and its own feature folders. Feature code must not depend on another feature directly unless a clear integration boundary is introduced.

#### `OpenZone/Features/SidePanel/`

The side panel is one feature module that hosts two sub-scopes, each scope-prefixed:

- **Session** (`SidePanelSession…`) — saved-conversation browsing, formerly "history chat". Lists and groups persisted conversations and hands off to Chat to open a thread. Consumes Chat's history persistence (`ChatHistoryClient`); does not own the live stream.
- **Setting** (`SidePanelSetting…`) — app preferences. Reads/writes through `Externals` clients and the shared theme preference.

### `OpenZone/Externals/`

Externals contains feature-neutral adapters for systems outside the app:

- `Networking/` — `ExternalAIProviderAPI`, `ExternalAIProviderCredentialAPI`, `ExternalAIProviderSSEDecoder`.
- `Preference/` — `ExternalAIProviderPreference`, `ExternalAIProviderReasoningModel`, `ExternalAIProviderPreferenceStore`, and `ExternalAIProviderPreferenceClient`.
- `Security/` — `ExternalCredentialStore` and `ExternalCredentialStoreClient`.

Externals must not reference feature UI or reducers. Chat domain types (e.g. `ChatModel`) belong in `Features/Chat/Models/`. Home-scoped orchestration (e.g. `HomeModelCatalogClient`) belongs in `Features/Home/Core/`. Chat streaming (`OpenAICompatibleStreamingClient`) and chat history persistence (`ChatHistoryClient`) stay in `Features/Chat/` because they combine provider wire behavior with chat domain types. The side panel's session scope consumes that persistence; it does not duplicate it.

> **Prefix exception**: `OpenAICompatibleStreamingClient` intentionally keeps its descriptive technical name (it describes the wire protocol, not a domain concept) and carries no feature prefix. It lives in `Features/Chat/Models/` because it combines provider wire behavior with chat domain types. If a type name is already established in the ecosystem (like "OpenAI-compatible"), prefer clarity over prefix consistency.

### `OpenZone/Shared/`

Shared contains app-wide UI primitives that are safe for more than one feature to reuse:

- `Theme/` — palette, theme preference, typography, color helpers, SwiftUI environment keys (`.sharedPalette`, `.sharedAppTheme`).
- `UI/` — reusable visual primitives, patterns, and button styles.

Shared code must not import or reference feature code. If a component contains onboarding-specific copy, state, or workflow behavior, keep it in `Features/<FeatureName>` instead of `Shared`.

## Access control

All types default to `internal`. Use `public` only when promoting a module to an internal framework or Swift Package boundary. This keeps the API surface implicit until you deliberately expose it across a package boundary.

## Why not marker enum files?

Do not add empty `enum SharedModule {}` or `enum FeatureModules {}` files just to document folders. They add symbols without runtime value. Keep developer guidance in `docs/architecture/` and keep source folders focused on executable app code.

## Future internal-library path

If module boundaries need compiler enforcement, promote these folders in this order:

1. Promote `OpenZone/Externals/` to an internal Xcode framework or Swift Package.
2. Promote `OpenZone/Shared/` (Theme + UI) to an internal `OpenZoneShared` library.
3. Promote `OpenZone/Features/<FeatureName>/` to feature targets.
4. Wire dependencies: features → `Externals`, `OpenZoneShared`, TCA.
5. Make the app target depend on the feature libraries.

Keep those libraries private to this repo unless a feature becomes reusable across multiple apps. Remote packages add versioning, CI, and cross-repo coordination overhead, so they should be introduced only when reuse justifies it.
