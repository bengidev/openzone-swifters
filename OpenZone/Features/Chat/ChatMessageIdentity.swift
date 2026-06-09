import Foundation

enum ChatMessageRole: String, Equatable, Sendable, Codable {
    case user
    case assistant
    case system
}

enum ChatStreamingStatus: Equatable, Sendable {
    case idle
    case running
    case done
    case failed
}
