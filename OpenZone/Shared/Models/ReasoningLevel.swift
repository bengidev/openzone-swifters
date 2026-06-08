import Foundation

/// Capability-driven reasoning effort.
///
/// The four tiers map 1:1 to the provider's `reasoning.effort` wire parameter,
/// with `off` meaning "send no reasoning parameter at all". There are no
/// fabricated higher tiers: this is the complete, closed set the app exposes.
///
/// Lives in Shared because it is feature-neutral: the composer, the Settings
/// sheet, the preference store, and the wire layer all source the level from
/// this one type. `HomeComposerReasoningLevel` is a typealias of it so existing
/// composer call sites keep compiling unchanged.
nonisolated enum ReasoningLevel: String, CaseIterable, Equatable, Identifiable, Sendable, Codable {
    case off
    case low
    case medium
    case high

    var id: String { rawValue }

    /// Human-facing label shown in the composer chip and Settings control.
    var title: String {
        switch self {
        case .off:
            return "Off"
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }

    /// The provider `reasoning.effort` value, or `nil` when reasoning is off.
    /// `off` deliberately maps to `nil` so the request omits the reasoning
    /// parameter entirely rather than sending an empty/zero effort.
    var effort: String? {
        switch self {
        case .off:
            return nil
        case .low:
            return "low"
        case .medium:
            return "medium"
        case .high:
            return "high"
        }
    }
}
