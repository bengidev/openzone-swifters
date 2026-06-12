# App Shell Context

| | |
| --- | --- |
| **Context** | OpenZone app shell |
| **Code** | `OpenZone/App/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The app shell owns entry-point wiring, global routing, SwiftData `ModelContainer` setup, and coordination between features.

## Language

- **App shell** — `OpenZoneApp`, root `StoreOf<AppFeature>`, and routing that decides which top-level screen is shown.
- **App feature** — root TCA reducer (`AppFeature`) that composes child features and handles cross-feature routing; it keeps the conventional TCA root name instead of becoming `AppAppFeature` or `OpenZoneAppFeature`.
- **Root view** — `AppRootView`, the app-shell view that routes between onboarding and the post-onboarding home surface.

## Architecture

- The shell creates dependencies (e.g. SwiftData container) and passes them into feature stores.
- Onboarding completion is observed by the shell to switch from onboarding to main content.
- Feature-specific logic stays in `OpenZone/Features/<FeatureName>/`; only cross-cutting routing belongs here.

## Boundaries

- Do not put feature-specific domain language or reducers in the shell beyond `AppFeature` orchestration.
- Shared theme and UI come from `OpenZone/Shared` (`Theme/`, `UI/`); external adapters from `OpenZone/Externals/`; feature UI from each feature's folder.
