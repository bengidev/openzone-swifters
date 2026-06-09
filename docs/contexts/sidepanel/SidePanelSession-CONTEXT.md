# Side Panel — Session Scope

| | |
| --- | --- |
| **Context** | Side panel → session scope |
| **Code** | `OpenZone/Features/SidePanel/` (`SidePanelSession…` symbols) |
| **Parent** | [SidePanel context](./SidePanel-CONTEXT.md) |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The session scope is the saved-conversation browser inside the side panel. It replaces the former "history chat" surface. It lists persisted conversations, groups them by recency, and lets the user open, pin, and manage them.

## Language

- **Session** — a saved conversation as presented for browsing/resuming (was "history chat" entry). The underlying persisted thread is the Chat `ChatConversation`.
- **Session section** — a recency- or pin-based group of sessions (`SidePanelSessionSection`): Pinned, Today, Yesterday, Previous 7 Days, Previous 30 Days, Older.
- **Session list** — the rendered, grouped list of sessions in the side panel (`SidePanelSessionSidebarView`).

## Architecture

- The session scope is its own reducer, `SidePanelSessionFeature`. Its state owns the loaded conversation list, the search query (with a `filteredConversations` view), sidebar visibility, and the active-conversation id used to highlight the open thread.
- It reads/writes persisted conversations through the chat history persistence (`ChatHistoryClient`): loading on open, and persisting pin/rename/delete before reloading the authoritative order.
- Grouping/relative-time labeling logic lives with the session scope (`SidePanelSessionSection`).
- It never touches the live chat reducer directly. Instead it emits `delegate` outputs the parent acts on: `openConversation` (resume in chat), `activeConversationRenamed`, and `activeConversationDeleted`.
- Naming the session symbols `…Section`/`…SidebarView`/`…Feature` follows the [file-naming rules](../../architecture/modules.md#file-naming).

## Naming convention

All session-scope symbols and files use the `SidePanelSession` prefix, then a role suffix per the [file-naming rules](../../architecture/modules.md#file-naming) — e.g. `SidePanelSessionSidebarView` (view), `SidePanelSessionSection` (value type).

## Migration note

This scope supersedes the old "history chat" naming. Former Home-scoped browsing symbols (`ChatHistorySidebarView`, `ChatHistorySection`) are renamed to `SidePanelSessionSidebarView` / `SidePanelSessionSection` and moved into `Features/SidePanel/`. Persistence types owned by Chat (`ChatHistoryClient`, `ChatHistoryEntities`) remain in `Features/Chat/`; this scope consumes them.

## Boundaries

- Owns browsing/navigation across saved sessions only — not the live stream (Chat) or the composer (Home).
- Reuse theme and UI primitives from `OpenZone/Shared`.
