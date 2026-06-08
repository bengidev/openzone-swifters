import Foundation

/// A thin, Sendable value descriptor for an OpenAI-compatible chat provider.
///
/// This is pure data with no behavior: it carries everything the generic
/// streaming client needs to address a backend (endpoint, auth scheme, and any
/// default headers the provider recommends). One concrete client is
/// parameterized by this descriptor, so adding another OpenAI-compatible
/// backend is a value, not a new client.
///
/// Lives in Shared because it is feature-neutral infrastructure configuration;
/// it names no chat domain types.
nonisolated struct ChatProvider: Equatable, Sendable {
    /// How the credential is presented on the wire.
    enum AuthScheme: Equatable, Sendable {
        /// `Authorization: Bearer <token>`.
        case bearer
    }

    /// Stable provider identifier (e.g. `"openrouter"`).
    let id: String
    /// Human-facing name (e.g. `"OpenRouter"`).
    let displayName: String
    /// Base URL of the OpenAI-compatible API root (no trailing `/chat/completions`).
    let baseURL: URL
    /// How the secret is attached to each request.
    let authScheme: AuthScheme
    /// Provider-recommended default headers attached to every request
    /// (e.g. OpenRouter attribution headers). Never carries the secret.
    let defaultHeaders: [String: String]

    init(
        id: String,
        displayName: String,
        baseURL: URL,
        authScheme: AuthScheme,
        defaultHeaders: [String: String] = [:]
    ) {
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
        self.authScheme = authScheme
        self.defaultHeaders = defaultHeaders
    }

    /// The chat-completions endpoint derived from the base URL.
    var chatCompletionsURL: URL {
        baseURL.appendingPathComponent("chat/completions")
    }

    /// The models-catalog endpoint derived from the base URL. OpenAI-compatible
    /// backends expose the catalog at `GET {base}/models`.
    var modelsURL: URL {
        baseURL.appendingPathComponent("models")
    }
}

extension ChatProvider {
    /// OpenRouter, configured with bearer auth and recommended attribution
    /// headers. The attribution headers identify the app to OpenRouter and are
    /// safe to commit (they carry no secret).
    static let openRouter = ChatProvider(
        id: "openrouter",
        displayName: "OpenRouter",
        baseURL: URL(string: "https://openrouter.ai/api/v1")!,
        authScheme: .bearer,
        defaultHeaders: [
            "HTTP-Referer": "https://github.com/bengidev/openzone-swifters",
            "X-Title": "OpenZone"
        ]
    )

    /// Every provider the app knows how to address. Adding an OpenAI-compatible
    /// backend is a value appended here, not a new client.
    static let all: [ChatProvider] = [.openRouter]

    /// The provider used when no preference has been stored yet.
    static let `default`: ChatProvider = .openRouter

    /// Resolves a stored provider id to its descriptor, falling back to the
    /// default when the id is unknown or absent (e.g. a stale persisted id from
    /// a removed provider).
    static func resolve(id: String?) -> ChatProvider {
        guard let id else { return .default }
        return all.first { $0.id == id } ?? .default
    }
}
