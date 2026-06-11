# Module Layout

Part of this repo's multi-context documentation. See [CONTEXT-MAP.md](../../CONTEXT-MAP.md) for per-feature glossaries and [docs/agents/domain.md](../agents/domain.md) for how agents consume domain docs.

OpenZone uses feature-oriented folders inside the app target today. The folders are intentionally shaped like modules so they can be promoted to internal Swift Package or Xcode framework targets later without rewriting the feature boundaries.

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
├── OpenZoneApp.swift
├── ContentView.swift
├── Item.swift
├── Features/
│   ├── AppFeature.swift
│   ├── Onboarding/           # OnboardingFeature, pages, visuals, persistence
│   ├── Home/                 # HomeFeature, composer, model catalog
│   ├── Chat/                 # ChatFeature, streaming, history persistence
│   └── SidePanel/            # hosts Session + Setting sub-scopes
│       ├── SidePanelSessionSection.swift
│       ├── SidePanelSessionSidebarView.swift
│       ├── SidePanelSettingFeature.swift
│       └── SidePanelSettingView.swift
└── Shared/                   # Cross-cutting primitives (internal module)
    ├── API/
    ├── Credential/
    ├── Preference/
    ├── Theme/
    └── UI/
```

> Flat feature folders: each feature folder holds its files directly — no `Domain/Application/Infrastructure/Presenter` boundary subfolders. File responsibility is conveyed by the scope-prefixed name, not by a folder layer.
>
> Scope prefixes: every symbol/file carries its module scope. The side panel's sub-scopes extend the parent prefix — `SidePanelSession…` for the session (ex "history chat") scope and `SidePanelSetting…` for the setting scope.

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
>
> A few clients are deliberately named for what they do rather than their module: `OpenAICompatibleStreamingClient` keeps its descriptive technical name (OpenAI-compatible wire protocol) and lives in `Features/Chat/` because it combines provider wire behavior with chat domain types.

## Ownership rules

### `OpenZone/Features/<FeatureName>/`

A feature owns one product workflow. Its folder holds all of the feature's files directly (flat) — reducers, `@ObservableState`, actions, value types, feature-scoped clients, and SwiftUI views. Use scope-prefixed file names (e.g. `HomeFeature`, `HomeComposerView`, `ChatHistoryClient`) so responsibility is clear without boundary subfolders.

Feature code may depend on `OpenZone/Shared`, Swift standard libraries, Apple frameworks, TCA, and its own feature folders. Feature code must not depend on another feature directly unless a clear integration boundary is introduced.

#### `OpenZone/Features/SidePanel/`

The side panel is one feature module that hosts two sub-scopes, each scope-prefixed:

- **Session** (`SidePanelSession…`) — saved-conversation browsing, formerly "history chat". Lists and groups persisted conversations and hands off to Chat to open a thread. Consumes Chat's history persistence (`ChatHistoryClient`); does not own the live stream.
- **Setting** (`SidePanelSetting…`) — app preferences. Reads/writes through Shared clients (`AIProviderPreferenceClient`, `CredentialStoreClient`) and the shared theme preference.

### `OpenZone/Shared/`

Shared contains cross-cutting, feature-neutral code that more than one feature may depend on:

- `API/` — `AIProviderAPI`, `AIProviderCredentialAPI`, `AIProviderSSEDecoder`.
- `Credential/` — `CredentialStore` and `CredentialStoreClient`.
- `Preference/` — `AIProviderPreference`, `AIProviderReasoningModel`, `AIProviderPreferenceStore`, and `AIProviderPreferenceClient`.
- `Theme/` — palette, theme preference, typography, color helpers, SwiftUI environment keys.
- `UI/` — reusable visual primitives, patterns, and button styles.

Shared must not reference feature UI or reducers. Chat domain types (e.g. `ChatModel`) belong in `Features/Chat/`. Home-scoped orchestration (e.g. `HomeModelCatalogClient`) belongs in `Features/Home/`. Chat streaming (`OpenAICompatibleStreamingClient`) and chat history persistence (`ChatHistoryClient`) stay in `Features/Chat/` because they combine provider wire behavior with chat domain types. The side panel's session scope consumes that persistence; it does not duplicate it.

Shared code must not import or reference feature code. If a component contains onboarding-specific copy, state, or workflow behavior, keep it in `Features/<FeatureName>` instead of `Shared`.

## Why not marker enum files?

Do not add empty `enum SharedModule {}` or `enum FeatureModules {}` files just to document folders. They add symbols without runtime value. Keep developer guidance in `docs/architecture/` and keep source folders focused on executable app code.

## Future internal-library path

If module boundaries need compiler enforcement, promote these folders in this order:

1. Promote `OpenZone/Shared/` to an internal `OpenZoneShared` Xcode framework or Swift Package.
2. Promote `OpenZone/Features/<FeatureName>/` to feature targets.
3. Wire dependencies: features → `OpenZoneShared`, TCA.
4. Make the app target depend on the feature libraries.

Keep those libraries private to this repo unless a feature becomes reusable across multiple apps. Remote packages add versioning, CI, and cross-repo coordination overhead, so they should be introduced only when reuse justifies it.
