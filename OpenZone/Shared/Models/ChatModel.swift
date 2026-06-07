import Foundation

/// A model entry from a provider catalog — the shared value type that flows
/// from the infrastructure layer through the feature layer to the UI.
///
/// Identity is the string `id` (e.g. `"meta-llama/llama-3.3-70b-instruct:free"`).
/// `isFree`, `contextLength`, and `supportsReasoning` are presentation/filter
/// metadata; the `id` alone is what the preference store persists and each
/// request carries on the wire.
nonisolated struct ChatModel: Equatable, Identifiable, Sendable, Codable {
    /// Wire/persistence identifier sent on every request.
    let id: String
    /// Human-facing label shown in the model popup and composer chip.
    let displayName: String
    /// Whether this model is available without a paid tier (`:free` suffix on
    /// OpenRouter, or marked free in the provider response).
    let isFree: Bool
    /// Maximum context window in tokens. `nil` when the provider does not
    /// report it.
    let contextLength: Int?
    /// Whether this model returns reasoning / chain-of-thought tokens.
    let supportsReasoning: Bool

    init(
        id: String,
        displayName: String,
        isFree: Bool = false,
        contextLength: Int? = nil,
        supportsReasoning: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.isFree = isFree
        self.contextLength = contextLength
        self.supportsReasoning = supportsReasoning
    }
}

// MARK: - Curated fallback catalog

/// The curated free-model list that is always available — before a key is
/// stored, while offline, or when the live fetch has not yet completed.
/// It is never empty so the picker always shows something useful.
extension ChatModel {
    nonisolated static let curatedFallback: [ChatModel] = [
        ChatModel(
            id: "meta-llama/llama-3.3-70b-instruct:free",
            displayName: "Llama 3.3 70B",
            isFree: true,
            contextLength: 131_072,
            supportsReasoning: false
        ),
        ChatModel(
            id: "deepseek/deepseek-r1:free",
            displayName: "DeepSeek R1",
            isFree: true,
            contextLength: 163_840,
            supportsReasoning: true
        ),
        ChatModel(
            id: "google/gemini-2.0-flash-exp:free",
            displayName: "Gemini 2.0 Flash",
            isFree: true,
            contextLength: 1_048_576,
            supportsReasoning: false
        ),
        ChatModel(
            id: "mistralai/mistral-7b-instruct:free",
            displayName: "Mistral 7B",
            isFree: true,
            contextLength: 32_768,
            supportsReasoning: false
        ),
        ChatModel(
            id: "qwen/qwen3-14b:free",
            displayName: "Qwen3 14B",
            isFree: true,
            contextLength: 40_960,
            supportsReasoning: true
        )
    ]
}
