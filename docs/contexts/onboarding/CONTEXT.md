# Onboarding Context

| | |
| --- | --- |
| **Context** | Onboarding feature |
| **Code** | `OpenZone/Features/Onboarding/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The onboarding feature owns the first-run experience. It teaches the user the core OpenZone concepts, persists completion, and then lets the app shell route to the home workspace (`HomeView`).

## Language

- **Onboarding feature** — the full first-run workflow under `OpenZone/Features/Onboarding`.
- **Onboarding page** — one step in the five-page flow.
- **Completion** — persisted signal that onboarding has finished; when true, the app shell routes to home (`HomeView`).
- **Demo visual** — an interactive illustration inside an onboarding page.

## Architecture

- State lives in `OnboardingFeature.State`.
- User intents are modeled as `OnboardingFeature.Action`.
- Flow mutations and persistence effects live in the `OnboardingFeature` reducer.
- SwiftUI views receive `StoreOf<OnboardingFeature>` and send actions; they should not own separate flow state.
- SwiftData access is isolated behind `OnboardingPersistenceClient`.

## Boundaries

- Keep onboarding-specific copy, page models, and visual workflow inside this context.
- Use `OpenZone/Shared` for reusable theme and UI primitives only.
- Do not reintroduce an `OnboardingViewModel`; TCA is the source of truth for this feature.
