import Foundation

struct ChatStreamError: Equatable, Sendable, ExpressibleByStringLiteral {
    let message: String

    nonisolated init(message: String) {
        self.message = message
    }

    nonisolated init(stringLiteral value: String) {
        self.init(message: value)
    }
}
