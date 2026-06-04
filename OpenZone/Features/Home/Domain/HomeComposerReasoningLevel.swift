import Foundation

/// Reasoning depth preset for the home composer.
enum HomeComposerReasoningLevel: String, CaseIterable, Equatable, Identifiable, Sendable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
}
