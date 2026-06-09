import Foundation

enum ChatStreamingEvent: Equatable, Sendable {
    case textDelta(String)
    case thinkingDelta(String)
    case done
    case error(ChatStreamError)
}
