import Foundation

protocol ChatMessagePayload {
    var id: UUID { get }
    var role: ChatMessageRole { get }
    var timestamp: Date { get }
}
