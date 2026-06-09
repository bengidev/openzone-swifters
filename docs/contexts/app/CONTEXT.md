# App Shell Context

| | |
| --- | --- |
| **Context** | OpenZone app shell |
| **Code** | `OpenZone/` (root app target sources outside feature folders) |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The app shell owns entry-point wiring, global routing, SwiftData `ModelContainer` setup, and coordination between top-level features.

## Language

- **App shell** — `OpenZoneApp`, root `StoreOf<AppFeature>`, and routing that decides which top-level screen is shown.
- **App feature** — root TCA reducer (`AppFeature`) that composes child features and handles cross-feature routing.
- **App route** — `AppRoute` enum distinguishing onboarding from home; the shell switches on this instead of scattering completion checks in views.
- **Main content** — post-onboarding primary UI (`HomeView` via `HomeFeature`).
- **Settings presentation** — modal settings sheet composed on `AppFeature` with `@Presents` / `.ifLet` over `SettingsFeature`.

## Architecture

- The shell creates dependencies (SwiftData container, live clients) and passes them into the root store.
- `AppFeature` owns `AppRoute` routing: onboarding until completion, then home workspace.
- `AppFeature` composes `OnboardingFeature`, `HomeFeature`, and presents `SettingsFeature` at the app level.
- Onboarding completion transitions the route from onboarding to home; settings can be opened from home actions forwarded to the app reducer.
- Feature-specific logic stays in `OpenZone/Features/<FeatureName>/`; only cross-cutting routing and app-wide presentation belong here.

## Boundaries

- Do not put feature-specific domain language or reducers in the shell beyond `AppFeature` orchestration.
- Shared theme and UI come from `OpenZone/Shared` (`Theme/`, `UI/`); external adapters from `OpenZone/Externals/`; feature UI from each feature's `Presenter/`.
