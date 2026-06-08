import Foundation

/// Reasoning depth preset for the home composer.
///
/// A typealias of the shared `ReasoningLevel` so the composer, the Settings
/// sheet, the preference store, and the wire layer share a single source of
/// truth. Kept as a named alias to preserve composer call-site compatibility
/// (mirrors the `HomePalette`/`ChatModel` aliasing pattern used elsewhere).
typealias HomeComposerReasoningLevel = ReasoningLevel
