# Chat Context

| | |
| --- | --- |
| **Context** | Chat feature |
| **Code** | `OpenZone/Features/Chat/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The chat feature owns the live conversation workflow: composing a request, streaming the assistant response, rendering messages and reasoning, and surfacing stream errors.

## Language

- **Conversation** — a single chat thread (`ChatConversation`) and its ordered messages.
- **Message** — one turn (`ChatMessage`), identified by `ChatMessageIdentity`, carrying a `ChatMessagePayload`.
- **Model** — the selected AI model descriptor (`ChatModel`) used for a request.
- **Request** — the outbound `ChatRequest` sent to the provider.
- **Streaming event** — an incremental `ChatStreamingEvent` decoded from the wire.
- **Stream error** — a terminal failure surfaced as `ChatStreamError` and shown in the error banner.

## Architecture

- State lives in `ChatFeature.State`; intents are `ChatFeature.Action`.
- Streaming, persistence, and provider wiring run as effects from the `ChatFeature` reducer.
- Value types: `ChatConversation`, `ChatMessage`, `ChatModel`, `ChatRequest`, `ChatStreamingEvent`, `ChatStreamError`, `ChatTextMessages`, `ChatMessageIdentity`, `ChatMessagePayload`.
- Clients (streaming + persistence): `ChatAPIClient`, `ChatOpenAICompatibleStreamingClient`, `ChatHistoryClient`, `ChatHistoryConversationEntity`, `ChatHistoryMessageEntity`, `ChatHistoryMessageKind`, `ChatCannedEventClient`.
- Views: `ChatThreadView`, `ChatMessageRowView`, `ChatReasoningCardView`, `ChatErrorBannerView`.

## Boundaries

- Chat domain types stay in `Features/Chat/`; do not move them to `Externals/`.
- `ChatOpenAICompatibleStreamingClient` stays here because it combines provider wire behavior with chat domain types.
- Reuse theme and UI primitives from `OpenZone/Shared`; reuse provider/credential adapters from `OpenZone/Externals`.
- Do not depend on other feature reducers directly; integrate through the app shell.

## Relation to the side panel

Persisted conversations produced by this feature are listed and resumed from the side panel's session scope — see [SidePanel context](../sidepanel/SidePanel-CONTEXT.md). Chat owns the active thread; the side panel owns navigation across saved conversations.
