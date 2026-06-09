# Chat Context

| | |
| --- | --- |
| **Context** | Chat feature |
| **Code** | `OpenZone/Features/Chat/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The chat feature owns the active conversation thread: message list, draft input, streaming assistant turns, and persistence of conversations and messages through the chat history module.

## Language

- **Chat thread** — the on-screen message list for the active conversation, including user, assistant, and reasoning rows.
- **Chat turn** — one user send through streaming completion (or failure); the unit at which persistence and retry boundaries are defined.
- **Streaming** — incremental delivery of reasoning and answer text via `ChatStreamingEvent` deltas until `.done` or `.error`.
- **Chat history module** — SwiftData-backed persistence (`ChatHistoryClient`, entities) for conversations and messages; owned by this context's `Infrastructure/`.
- **ChatTurnEngine** — application-layer reducer module that orchestrates a single turn: request construction, stream subscription, delta merging into stable message rows, and turn-boundary persistence.
- **ChatHistoryFeature** — child reducer (composed by [Home](../home/CONTEXT.md)) that loads, filters, and mutates the sidebar conversation list; delegates thread restoration to `ChatFeature`.

## Architecture

- Thread state lives in `ChatFeature.State`; user intents are `ChatFeature.Action`.
- Turn orchestration and streaming delta handling are extracted into `ChatTurnEngine` so `ChatFeature` stays focused on thread lifecycle (open, clear, restore).
- Side effects use explicit clients from `Infrastructure/`: `ChatAPIClient` (streaming), `ChatHistoryClient` (persistence).
- Domain types (`ChatMessage`, `ChatConversation`, `ChatRequest`, `ChatModel`, streaming events) live in `Domain/`.
- SwiftUI views in `Presenter/` receive scoped stores and send actions; they do not own thread or streaming state.

## Boundaries

- Keep chat wire protocol, message shapes, streaming semantics, and history persistence inside this context.
- Composer, model catalog, and sidebar chrome belong in [Home](../home/CONTEXT.md); Home scopes `ChatFeature` and forwards thread actions.
- Provider credentials and global preferences come from `OpenZone/Externals/` via dependency clients, not duplicated here.
- Do not add separate `@Observable` view-model classes; TCA is the source of truth for this feature.
