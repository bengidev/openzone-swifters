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
│   └── Onboarding/
│       ├── Application/
│       │   └── OnboardingFeature.swift
│       ├── Domain/
│       ├── Infrastructure/
│       └── Presenter/
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
- `Infrastructure/` — persistence, system adapters, external clients.
- `Presenter/` — SwiftUI views that render the feature from a TCA store.

Feature code may depend on `OpenZone/Shared`, Swift standard libraries, Apple frameworks, TCA, and its own feature folders. Feature code must not depend on another feature directly unless a clear integration boundary is introduced.

### `OpenZone/Shared/`

Shared contains app-wide primitives that are safe for more than one feature to reuse:

- `Theme/` — palette, theme preference, typography, color helpers, SwiftUI environment keys.
- `UI/` — reusable visual primitives, patterns, and button styles.
- Cross-cutting infrastructure — persistence, networking, and other external integrations, exposed behind abstractions (protocols / dependency clients) so features depend on the abstraction, not the concrete external implementation.

Shared code must not import or reference feature code. If a component contains onboarding-specific copy, state, or workflow behavior, keep it in `Features/Onboarding` instead of `Shared`. Shared infrastructure must stay feature-neutral: it exposes generic capabilities (an HTTP/SSE client, a keychain store, a database adapter), never a feature's domain types or workflow.

## Why not marker enum files?

Do not add empty `enum SharedModule {}` or `enum FeatureModules {}` files just to document folders. They add symbols without runtime value. Keep developer guidance in `docs/architecture/` and keep source folders focused on executable app code.

## Future internal-library path

If module boundaries need compiler enforcement, promote these folders in this order:

1. Create an internal `OpenZoneShared` Swift Package or Xcode framework target from `OpenZone/Shared`.
2. Create an internal `OnboardingFeature` target from `OpenZone/Features/Onboarding`.
3. Make `OnboardingFeature` depend on `OpenZoneShared` and TCA.
4. Make the app target depend on `OpenZoneShared` and `OnboardingFeature`.

Keep those libraries private to this repo unless a feature becomes reusable across multiple apps. Remote packages add versioning, CI, and cross-repo coordination overhead, so they should be introduced only when reuse justifies it.
