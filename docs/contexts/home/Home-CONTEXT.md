# Home Context

| | |
| --- | --- |
| **Context** | Home feature |
| **Code** | `OpenZone/Features/Home/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The home feature owns the main landing surface: the welcome state, the composer that starts a conversation, model selection, and the entry point into the side panel.

## Language

- **Composer** — the input surface (`HomeComposerView`) for starting a message, with speed mode, provider reasoning model, and context-usage indicators.
- **Speed mode** — `HomeComposerSpeedMode`, the latency/quality tradeoff selected for a request.
- **Provider reasoning model** — `ExternalAIProviderReasoningModel`, the cross-feature reasoning tier surfaced in the composer and persisted in provider preference.
- **Context usage** — `HomeComposerContextUsage`, the live token/context budget indicator.
- **Model option** — `HomeModelOption`, a selectable model presented in the model popup.
- **Welcome** — the empty/first-load state (`HomeWelcomeView`) shown before a conversation begins.

## Architecture

- State lives in `HomeFeature.State`; intents are `HomeFeature.Action`.
- Value types: `HomeComposerSpeedMode`, `HomeComposerContextUsage`, `HomeModelOption`.
- Cross-feature provider reasoning uses `ExternalAIProviderReasoningModel`; do not keep a `HomeComposerReasoningLevel` typealias.
- Clients: `HomeModelCatalogClient`, `HomeModelCatalogCachePreferenceClient` (model catalog fetch + cache). Concrete implementations use domain-first names after the `Home` prefix, e.g. `HomeModelCatalogCachePreferenceUserDefaultsStore` and `HomeModelCatalogCachePreferenceInMemoryStore`.
- Views: `HomeView`, `HomeWelcomeView`, `HomeComposerView`, `HomeModelPopupView`, `HomeParticleOrbView`.

## Boundaries

- Home owns the landing and composer workflow only. Live streaming belongs to [Chat](../chat/Chat-CONTEXT.md).
- Reuse theme and UI primitives from `OpenZone/Shared`; reuse provider/credential adapters from `OpenZone/Externals`.
- Do not depend on other feature reducers directly; integrate through the app shell.

## Relation to the side panel

Saved-conversation browsing and the settings sheet have moved out of Home into the side panel module. Home composes `SidePanelFeature` as a child (`sidePanel: SidePanelFeature.State` + `Scope`) and renders its surfaces (`SidePanelSessionSidebarView`, `SidePanelSettingView`) scoped to the panel's state.

Home no longer owns that state. It only:

- forwards the toggle/settings-button intents into the panel,
- handles the panel's `delegate` outputs — opening the chosen conversation in [Chat](../chat/Chat-CONTEXT.md), re-reading credentials on change, refreshing the reasoning chip,
- syncs the active-conversation id into the session scope so the sidebar highlights the open thread.

The session list and its grouping live under [SidePanel context](../sidepanel/SidePanel-CONTEXT.md).
