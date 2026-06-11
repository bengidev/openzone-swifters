# Side Panel Context

| | |
| --- | --- |
| **Context** | Side panel feature |
| **Code** | `OpenZone/Features/SidePanel/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The side panel is the single navigation surface that slides in alongside the main content. It is one module that hosts two sub-scopes that were previously separate: **session** (saved-conversation browsing, formerly "history chat") and **setting** (app preferences).

```text
OpenZone/Features/SidePanel/   # flat — no boundary subfolders
├── SidePanelFeature.swift          # host reducer: composes session + setting
├── SidePanelSessionFeature.swift   # session scope reducer (owns the list)
├── SidePanelSessionSection.swift
├── SidePanelSessionSidebarView.swift
├── SidePanelSettingFeature.swift   # setting scope reducer
└── SidePanelSettingView.swift
```

## Sub-scopes

- **Session** — list, group, open, pin, and manage saved conversations. Replaces the old "history chat" surface. See [SidePanelSession context](./SidePanelSession-CONTEXT.md).
- **Setting** — app-wide preferences (theme, provider, credentials entry points). See [SidePanelSetting context](./SidePanelSetting-CONTEXT.md).

## Language

- **Side panel** — the slide-in container (`SidePanelFeature`) that presents session and setting scopes.
- **Session scope** — the saved-conversation browser inside the side panel (`SidePanelSession*`).
- **Setting scope** — the preferences surface inside the side panel (`SidePanelSetting*`).

## Architecture

- `SidePanelFeature` is the host reducer. Its state holds `session: SidePanelSessionFeature.State` and a presented `@Presents var setting: SidePanelSettingFeature.State?`; it composes both via `Scope` + `ifLet`.
- Each sub-scope owns its own state slice, effects, and dependencies: the session scope holds the conversation list, search query, sidebar visibility, and the active-conversation id, and talks to `ChatHistoryClient`; the setting scope holds preference/credential draft state.
- The panel does not reach into the live chat reducer. The session scope emits `SidePanelSessionFeature.Action.delegate` outputs (open / active-renamed / active-deleted); the host re-emits them as `SidePanelFeature.Action.delegate` for the parent.
- The parent (Home) handles the panel delegate: it opens the chosen conversation in [Chat](../chat/Chat-CONTEXT.md), re-reads credentials on `credentialsChanged`, and syncs the active-conversation id back into the session scope so the sidebar can highlight the open thread.

## Naming convention

All symbols and files in this module carry the `SidePanel` scope prefix, and the two sub-scopes extend it:

- `SidePanelSession…` for the session (ex-"history chat") scope — e.g. `SidePanelSessionFeature`, `SidePanelSessionSidebarView`, `SidePanelSessionSection`.
- `SidePanelSetting…` for the setting scope — e.g. `SidePanelSettingView`, `SidePanelSettingFeature`.

## Boundaries

- The side panel owns navigation across saved conversations and app settings; it does not own the live chat stream (that is [Chat](../chat/Chat-CONTEXT.md)) or the landing composer (that is [Home](../home/Home-CONTEXT.md)).
- Reuse theme and UI primitives from `OpenZone/Shared`; reuse provider/credential/preference adapters from `OpenZone/Shared` (`API/`, `Credential/`, `Preference/`).
- Do not depend on other feature reducers directly; integrate through the app shell.
