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
  /// The provider descriptor now rides on each `ChatRequest` (filled by the
  /// reducer from the preference store), so the live client is no longer
  /// constructed against a fixed provider. The secret is resolved at request
  /// time from the Keychain-backed `ExternalCredentialStore`, so a key entered or
  /// updated in Settings takes effect on the next send. When no key is stored
  /// the send path reports a missing-key error instead of calling out
  /// unauthenticated. Test/preview replay a deterministic canned-event stub so
  /// they never touch the network.
  static let liveValue = ChatAPIClient.wrap(
    OpenAICompatibleStreamingClient(
      credentialProvider: ExternalAIProviderCredentialAPI { providerID in
        ExternalKeychainCredentialStore(
          service: "io.github.bengidev.OpenZone",
          account: "\(providerID)-api-key"
        ).secret()
      }
    )
  )
  static let testValue = ChatAPIClient.wrap(ChatCannedEventClient())
  static let previewValue = ChatAPIClient.wrap(ChatCannedEventClient())
}

extension DependencyValues {
  var chatAPIClient: ChatAPIClient {
    get { self[ChatAPIClient.self] }
    set { self[ChatAPIClient.self] = newValue }
  }
}
