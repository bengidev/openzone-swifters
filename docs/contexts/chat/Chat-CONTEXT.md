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
│   ├── ChatAction.swift                     # User actions and events
│   └── ChatAPIClient.swift                  # API integration layer
├── Models/
│   ├── ChatEntity.swift                     # SwiftData @Model for persistence
│   ├── ChatMessage.swift                    # Message value type
│   ├── ChatModel.swift                      # Model metadata
│   └── ChatReasoningLevel.swift             # Reasoning effort enum
├── Views/
│   ├── ChatView.swift                       # Full conversation screen
│   ├── ChatMessageRow.swift                 # Single message bubble
│   ├── ChatComposer.swift                   # Message input with controls
│   ├── ChatReasoningLevelView.swift         # Reasoning level selector
│   └── ChatStreamingTextView.swift          # Markdown rendering view
└── Utilities/
    ├── ChatMarkdownRenderer.swift           # Markdown to AttributedString
    └── ChatMessageFormatter.swift           # Message content formatting
```

## Dependencies

**Required:**
- `OpenZone/Externals/` - Uses `ExternalAIProviderAPI`, `ExternalCredentialStore`, `ExternalAIProviderPreferenceStore`
- `OpenZone/Shared/` - Uses `SharedAppTheme`, `SharedOpenZonePalette`, `SharedButtonStyle`

**Feature Dependencies:**
- None - Chat is a feature leaf (Onboarding and Home route into Chat, not reverse)

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

Chat supports three reasoning effort levels:

```swift
enum ChatReasoningLevel: String, CaseIterable, Sendable {
    case low = "low"        // Fast responses, minimal reasoning
    case medium = "medium"  // Balanced speed and quality
    case high = "high"      // Thorough reasoning, slower responses
}
```

Users can adjust reasoning level per conversation through the UI.

## Recent Architecture Changes

- Restructured into role-based subfolders (Core/Models/Views/Utilities)
- Renamed persistence entity from `ConversationEntity` to `ChatEntity` for consistency
- Added `Chat` prefix to all types for clarity
- Removed `public` modifiers (internal access by default)
- Simplified message model to use associated values for different message types
- Added dedicated Markdown renderer utility for streaming responses
