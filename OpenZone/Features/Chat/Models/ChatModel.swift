import Foundation

/// A model entry from the provider catalog — chat domain value that flows
/// from infrastructure through features to the UI.
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
    /// The curated free-model list that is always available — before a key is
    /// stored, while offline, or when the live fetch has not yet completed.
    /// It is never empty so the picker always shows something useful.
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

    /// Curated fallback models for Command Code. Model ids match the
    /// Command Code Provider API catalog per https://commandcode.ai/docs/reference/cli/models.
    nonisolated static let commandCodeFallback: [ChatModel] = [
        ChatModel(
            id: "moonshotai/Kimi-K2.5",
            displayName: "Kimi K2.5",
            isFree: true,
            contextLength: 131_072,
            supportsReasoning: true
        ),
        ChatModel(
            id: "deepseek/deepseek-v4-flash",
            displayName: "DeepSeek V4 Flash",
            isFree: true,
            contextLength: 131_072,
            supportsReasoning: false
        ),
        ChatModel(
            id: "deepseek/deepseek-v4-pro",
            displayName: "DeepSeek V4 Pro",
            isFree: false,
            contextLength: 131_072,
            supportsReasoning: true
        ),
        ChatModel(
            id: "Qwen/Qwen3.7-Max",
            displayName: "Qwen 3.7 Max",
            isFree: false,
            contextLength: 131_072,
            supportsReasoning: true
        ),
        ChatModel(
            id: "claude-sonnet-4-6",
            displayName: "Claude Sonnet 4.6",
            isFree: false,
            contextLength: 200_000,
            supportsReasoning: true
        )
    ]

    /// Curated fallback models for OpenCode. Model ids match the
    /// OpenCode zen API catalog.
    nonisolated static let openCodeFallback: [ChatModel] = [
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
            id: "qwen/qwen3-14b:free",
            displayName: "Qwen3 14B",
            isFree: true,
            contextLength: 40_960,
            supportsReasoning: true
        )
    ]

    /// Returns the provider-scoped curated fallback for the given provider id.
    /// Unknown or absent providers fall back to the default provider's list.
    nonisolated static func curatedFallback(for providerID: String?) -> [ChatModel] {
        switch providerID {
        case "commandcode":
            return commandCodeFallback
        case "opencode":
            return openCodeFallback
        default:
            // nil, "openrouter", or unknown provider ids fall back to the
            // OpenRouter catalog (the default provider).
            return curatedFallback
        }
    }
}
