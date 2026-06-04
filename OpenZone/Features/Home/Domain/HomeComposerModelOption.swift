import Foundation

/// Chat model choices shown in the home composer rail.
enum HomeComposerModelOption: String, CaseIterable, Equatable, Identifiable, Sendable {
    case gpt54 = "gpt-5.4"
    case gpt55 = "gpt-5.5"
    case local = "local"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gpt54:
            return "GPT-5.4"
        case .gpt55:
            return "GPT-5.5"
        case .local:
            return "Local"
        }
    }

    var availableSpeedModes: [HomeComposerSpeedMode] {
        switch self {
        case .gpt54, .gpt55:
            return HomeComposerSpeedMode.allCases
        case .local:
            return []
        }
    }
}
