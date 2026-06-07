import ComposableArchitecture
import Foundation

protocol ChatAPIClientProtocol: Sendable {
  nonisolated func stream(request: ChatRequest) -> AsyncStream<ChatStreamingEvent>
}

struct ChatAPIClient: Sendable {
  var stream: @Sendable (ChatRequest) -> AsyncStream<ChatStreamingEvent>
}

extension ChatAPIClient {
  static func wrap(_ client: some ChatAPIClientProtocol) -> ChatAPIClient {
    ChatAPIClient(stream: { client.stream(request: $0) })
  }
}

extension ChatAPIClient: DependencyKey {
  /// Live path streams real model tokens over an OpenAI-compatible backend.
  ///
  /// Slice 1 (issue #3): OpenRouter on a temporary hardcoded free model, with a
  /// DEBUG env-supplied key (`OPENROUTER_API_KEY`). Secure Keychain entry and
  /// model selection arrive in later slices. Test/preview keep the inline mock
  /// so they never touch the network.
  static let liveValue = ChatAPIClient.wrap(
    OpenAICompatibleStreamingClient(
      provider: .openRouter,
      credentialProvider: .environment
    )
  )
  static let testValue = ChatAPIClient.wrap(ChatMockStreamingClient.fastClient())
  static let previewValue = ChatAPIClient.wrap(ChatMockStreamingClient.fastClient())
}

extension DependencyValues {
  var chatAPIClient: ChatAPIClient {
    get { self[ChatAPIClient.self] }
    set { self[ChatAPIClient.self] = newValue }
  }
}
