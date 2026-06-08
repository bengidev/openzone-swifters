# Module Layout

Part of this repo's multi-context documentation. See [CONTEXT-MAP.md](../../CONTEXT-MAP.md) for per-feature glossaries and [docs/agents/domain.md](../agents/domain.md) for how agents consume domain docs.

OpenZone uses feature-oriented folders inside the app target today. The folders are intentionally shaped like modules so they can be promoted to internal Swift Package or Xcode framework targets later without rewriting the feature boundaries.

State management is implemented with [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture). New product workflows should follow the same reducer/store pattern.

Swift code must also follow the repo's Swift 6 strictness rules in `docs/architecture/swift-6-strictness.md`.

## Current layout

```text
OpenZone/
├── OpenZoneApp.swift
├── ContentView.swift
├── Item.swift
├── Features/
│   ├── AppFeature.swift
│   ├── Chat/
│   │   ├── Domain/           # ChatModel, messages, requests
│   │   ├── Application/
│   │   ├── Infrastructure/   # streaming client, history
│   │   └── Presenter/
│   ├── Home/
│   │   ├── Domain/
│   │   ├── Application/
│   │   ├── Infrastructure/   # ModelCatalogClient, catalog cache preference
│   │   └── Presenter/
│   └── Onboarding/
│       ├── Application/
│       ├── Domain/
│       ├── Infrastructure/
│       └── Presenter/
├── Externals/                # External integrations (internal module)
│   ├── Networking/
│   ├── Preference/
│   └── Security/
└── Shared/
    ├── Theme/
    └── UI/
```

## State management rules

- The app root owns a `StoreOf<AppFeature>`.
- Each feature owns a TCA reducer named `<FeatureName>Feature` in `Application/`.
- Feature views receive `StoreOf<<FeatureName>Feature>` and send actions through `store.send(...)`.
- Do not add separate `@Observable` view-model classes for TCA-backed features. State belongs in `@ObservableState`; mutations belong in reducer actions.
- Side effects (persistence, networking, system adapters) run from reducer effects and use explicit clients from `Infrastructure/`.
- Tests should use `TestStore` for reducer behavior, plus normal view/unit tests where useful.

## Ownership rules

### `OpenZone/Features/<FeatureName>/`

A feature owns one product workflow. It may contain:

- `Domain/` — value types, enums, feature language, pure rules.
- `Application/` — TCA reducers, `@ObservableState`, actions, and use-case orchestration.
- `Infrastructure/` — persistence, system adapters, external clients scoped to the feature workflow.
- `Presenter/` — SwiftUI views that render the feature from a TCA store.

Feature code may depend on `OpenZone/Externals`, `OpenZone/Shared`, Swift standard libraries, Apple frameworks, TCA, and its own feature folders. Feature code must not depend on another feature directly unless a clear integration boundary is introduced.

### `OpenZone/Externals/`

Externals contains feature-neutral adapters for systems outside the app:

- `Networking/` — `AIProviderAPI`, `AIProviderCredentialAPI`, `AIProviderSSEDecoder`.
- `Preference/` — `AIProviderPreference`, `AIProviderReasoningModel`, `AIProviderPreferenceStore`, and `AIProviderPreferenceClient`.
- `Security/` — `CredentialStore` and `CredentialStoreClient`.

Externals must not reference feature UI or reducers. Chat domain types (e.g. `ChatModel`) belong in `Features/Chat/Domain/`. Home-scoped orchestration (e.g. `ModelCatalogClient`) belongs in `Features/Home/Infrastructure/`. Chat streaming (`OpenAICompatibleStreamingClient`) stays in `Features/Chat/Infrastructure/` because it combines provider wire behavior with chat domain types.

### `OpenZone/Shared/`

Shared contains app-wide UI primitives that are safe for more than one feature to reuse:

- `Theme/` — palette, theme preference, typography, color helpers, SwiftUI environment keys.
- `UI/` — reusable visual primitives, patterns, and button styles.

Shared code must not import or reference feature code. If a component contains onboarding-specific copy, state, or workflow behavior, keep it in `Features/<FeatureName>` instead of `Shared`.

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
