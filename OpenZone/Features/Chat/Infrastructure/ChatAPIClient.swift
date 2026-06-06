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
  static let liveValue = ChatAPIClient.wrap(ChatMockStreamingClient.defaultClient())
  static let testValue = ChatAPIClient.wrap(ChatMockStreamingClient.fastClient())
  static let previewValue = ChatAPIClient.wrap(ChatMockStreamingClient.fastClient())
}

extension DependencyValues {
  var chatAPIClient: ChatAPIClient {
    get { self[ChatAPIClient.self] }
    set { self[ChatAPIClient.self] = newValue }
  }
}
