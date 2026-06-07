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
  /// The secret is resolved at request time from the Keychain-backed
  /// `CredentialStore`, so a key entered or updated in Settings takes effect on
  /// the next send. When no key is stored the send path reports a missing-key
  /// error instead of calling out unauthenticated. Test/preview keep the inline
  /// mock so they never touch the network.
  static let liveValue = ChatAPIClient.wrap(
    OpenAICompatibleStreamingClient(
      provider: .openRouter,
      credentialProvider: .keychain(KeychainCredentialStore.openRouter)
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
