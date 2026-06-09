# Home Context

| | |
| --- | --- |
| **Context** | Home feature |
| **Code** | `OpenZone/Features/Home/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The home feature is the post-onboarding workspace: welcome chrome, chat thread, composer, model picker, and chat history sidebar. It composes child reducers for each major surface and coordinates them through `HomeFeature`.

## Language

- **Home workspace** — the primary post-onboarding screen (`HomeView`) shown after onboarding completes.
- **Composer** — the bottom input bar and model/reasoning controls used to draft and send messages.
- **Model catalog** — the live and curated list of selectable models for the current provider, loaded via `ModelCatalogClient`.
- **Chat history sidebar** — the drawer listing persisted conversations with search, pin, rename, and delete.
- **ComposerFeature** — child reducer for composer state: draft forwarding, model popup, reasoning and speed mode, send gating.
- **ModelCatalogFeature** — child reducer for catalog load, search debounce, and free-tier filtering.
- **ChatHistoryFeature** — child reducer for sidebar visibility, conversation list load/filter, and history mutations.

## Architecture

- `HomeFeature` is the parent reducer. It composes:
  - `ChatFeature` — active thread and streaming (see [Chat](../chat/CONTEXT.md)).
  - `ChatHistoryFeature` — sidebar conversation list and selection handoff to chat.
  - `ModelCatalogFeature` — provider model list and popup filtering.
  - `ComposerFeature` — composer controls and send eligibility (API key + selected model).
- `HomeFeature.State` holds scoped child state; actions are namespaced under each child.
- Model catalog infrastructure (`ModelCatalogClient`, cache preference) lives in `Home/Infrastructure/`.
- Presenter views (`HomeView`, `HomeComposerView`, `ChatHistorySidebarView`, `HomeModelPopupView`) receive `StoreOf<HomeFeature>` or scoped child stores.

## Boundaries

- Keep workspace layout, composer UX, catalog orchestration, and sidebar workflow inside this context.
- Thread streaming, turn persistence, and message domain types stay in [Chat](../chat/CONTEXT.md).
- Settings sheet presentation is owned by [App](../app/CONTEXT.md) at `AppFeature` level, not by `HomeFeature`.
- Use `OpenZone/Shared` for reusable theme and UI primitives only.
- Do not depend on another feature's reducers directly except through the composed child boundaries above.
