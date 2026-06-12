# Chat Feature Context

| | |
| --- | --- |
| **Code** | `OpenZone/Features/Chat/` |
| **Role-based layout** | `Core/`, `Models/`, `Views/`, `Utilities/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The Chat feature manages conversation threads with AI providers, handling message streaming, UI rendering, and conversation lifecycle.

## Folder Structure

```text
OpenZone/Features/Chat/
├── Core/
│   ├── ChatFeature.swift                    # TCA Reducer + State
│   ├── ChatAPIClient.swift                  # Provider-agnostic chat client protocol
│   └── ChatHistoryClient.swift              # SwiftData persistence bridge
├── Models/
│   ├── ChatHistoryEntities.swift             # SwiftData @Model: ChatHistoryConversationEntity, ChatHistoryMessageEntity
│   ├── ChatConversation.swift               # Domain conversation value type
│   ├── ChatMessage.swift                    # Domain message value type
│   ├── ChatModel.swift                      # Model metadata (id, name, capabilities)
│   └── ChatOpenAICompatibleStreamingClient.swift # OpenAI-compatible wire streaming client
├── Views/
│   ├── ChatThreadView.swift                 # Full conversation screen
│   ├── ChatMessageRowView.swift             # Single message bubble
│   ├── ChatReasoningCardView.swift          # Reasoning/thinking card
│   └── ChatErrorBannerView.swift            # Stream error feedback
└── Utilities/
    └── ChatCannedEventClient.swift          # Test fixture support
```

## Dependencies

**Required:**
- `OpenZone/Externals/` - Uses `ExternalAIProviderAPI`, `ExternalCredentialStore`, `ExternalAIProviderPreferenceStore`
- `OpenZone/Shared/` - Uses `SharedAppTheme`, `SharedOpenZonePalette`, `SharedButtonStyle`

**Feature Dependencies:**
- None - Chat is a feature leaf (Onboarding and Home route into Chat, not reverse)

## Sub-Scopes

The Chat feature contains one sub-scope for history management:

- **ChatHistory** — Persistence layer for saved conversations. Entities use the `ChatHistory` prefix (`ChatHistoryConversationEntity`, `ChatHistoryMessageEntity`, `ChatHistoryClient`). This scope owns SwiftData models and the client that bridges them to domain types. Live streaming and message rendering stay at the Chat root level.

## State Management (TCA)

The Chat feature uses a single reducer pattern with streaming state management:

```swift
@Reducer
struct ChatFeature {
    @ObservableState
    struct State: Equatable {
        var conversationID: UUID
        var messages: [ChatMessage] = []
        var isStreaming: Bool = false
        var inputText: String = ""
        var selectedModel: ChatModel?
        var selectedReasoningLevel: ChatReasoningLevel = .medium
        var credentials: String?
    }
    
    enum Action {
        case onAppear
        case inputTextChanged(String)
        case sendMessage
        case messageReceived(ChatMessage)
        case streamingStarted
        case streamingCompleted
        case modelChanged(ChatModel)
        case reasoningLevelChanged(ChatReasoningLevel)
        case retryLastMessage
        case deleteMessage(ChatMessage.ID)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .sendMessage:
                guard !state.inputText.isEmpty,
                      let model = state.selectedModel else { return .none }
                state.isStreaming = true
                let userMessage = ChatMessage(role: .user, content: state.inputText)
                state.messages.append(userMessage)
                state.inputText = ""
                return .run { [model = model, 
                                level = state.selectedReasoningLevel,
                                cred = state.credentials] send in
                    try await ExternalAIProviderAPI.streamMessage(
                        model: model,
                        reasoningLevel: level,
                        credentials: cred,
                        onMessage: { message in
                            await send(.messageReceived(message))
                        }
                    )
                    await send(.streamingCompleted)
                }
                
            case .messageReceived(let message):
                state.messages.append(message)
                return .none
                
            // ... other actions
            }
        }
    }
}
```

## External Integrations

- **AI Provider API** - `ExternalAIProviderAPI.streamMessage()` for real-time message streaming
- **Credentials** - `ExternalCredentialStore.fetch()` to retrieve API key for authentication
- **Provider Preferences** - `ExternalAIProviderPreferenceStore.fetch()` to get selected model and reasoning level

## Message Rendering

The Chat feature uses a custom Markdown renderer:

```swift
struct ChatStreamingTextView: View {
    let text: String
    @State private var attributedText: AttributedString?
    
    var body: some View {
        Group {
            if let attributedText {
                Text(attributedText)
            } else {
                Text(text)
            }
        }
        .task(id: text) {
            attributedText = await ChatMarkdownRenderer.render(text)
        }
    }
}
```

This provides syntax highlighting, code blocks, and link formatting for AI-generated content.

## Cross-Feature Communication

Chat operates independently but receives initial state from parent:

```swift
// Parent routes into Chat with conversation ID
case .home(.delegate(.navigateToChat(let id))):
    state.path.append(.chat(conversationID: id))
    path.presentedState = .chat(ChatFeature.State(conversationID: id))

// Chat handles its own lifecycle, sends completion if needed
case .chat(.delegate(.chatCompleted)):
    state.path.removeLast()
```

## Reasoning Levels

Chat uses `ExternalAIProviderReasoningModel` from the Externals boundary for reasoning effort. The home composer selects the level; Chat reads it when building the streaming request. No Chat-local reasoning enum exists.

## Recent Architecture Changes

- Restructured into role-based subfolders (Core/Models/Views/Utilities)
- Entities renamed to `ChatHistoryConversationEntity` and `ChatHistoryMessageEntity` (ChatHistory sub-scope)
- `OpenAICompatibleStreamingClient` renamed to `ChatOpenAICompatibleStreamingClient` for prefix consistency
- Removed `public` modifiers (internal access by default)
- ChatDomainModel.swift → `ChatMessage` with associated values for different message types
