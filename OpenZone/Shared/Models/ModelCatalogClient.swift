import ComposableArchitecture
import Foundation

// MARK: - OpenRouter wire types

/// OpenRouter `/models` response envelope. Only the fields this slice
/// consumes are decoded; unknown fields are ignored.
private nonisolated struct OpenRouterModelsResponse: Decodable, Sendable {
    let data: [OpenRouterModelEntry]
}

private nonisolated struct OpenRouterModelEntry: Decodable, Sendable {
    let id: String
    let name: String?
    let contextLength: Int?
    let architecture: Architecture?
    let pricing: Pricing?

    enum CodingKeys: String, CodingKey {
        case id, name, architecture, pricing
        case contextLength = "context_length"
    }

    nonisolated struct Architecture: Decodable, Sendable {
        let modality: String?
    }

    nonisolated struct Pricing: Decodable, Sendable {
        let prompt: String?
        let completion: String?
    }

    /// A model is free when both prompt and completion prices are "0".
    var isFree: Bool {
        guard let prompt = pricing?.prompt, let completion = pricing?.completion else {
            // Fall back to the `:free` suffix convention.
            return id.hasSuffix(":free")
        }
        return (prompt == "0" || prompt == "0.0") && (completion == "0" || completion == "0.0")
    }

    /// Reasoning support: DeepSeek R1-family and models whose id contains
    /// known reasoning markers.
    var supportsReasoning: Bool {
        let lower = id.lowercased()
        return lower.contains("deepseek-r1")
            || lower.contains("deepseek-r2")
            || lower.contains("qwq")
            || lower.contains("o1")
            || lower.contains("o3")
            || lower.contains("-thinking")
    }

    func toChatModel() -> ChatModel {
        ChatModel(
            id: id,
            displayName: name ?? id,
            isFree: isFree,
            contextLength: contextLength,
            supportsReasoning: supportsReasoning
        )
    }
}

// MARK: - Catalog client

/// How long a cached catalog is considered fresh before a background refresh
/// is triggered.
nonisolated let modelCatalogCacheTTL: TimeInterval = 60 * 60 // 1 hour

/// TCA dependency for fetching the provider model catalog.
///
/// Responsibilities:
///   - Always returns the curated fallback list when no key exists or when
///     offline — the picker is never empty.
///   - When a key is present: reads the `ProviderPreferenceStore` cache; if
///     absent or stale, fetches the live catalog from the provider's `/models`
///     endpoint, writes it back to the cache, and returns the result.
///   - Parsing errors or network failures silently fall back to the curated
///     list so the UI degrades gracefully.
nonisolated struct ModelCatalogClient: Sendable {
    /// Returns the model catalog for `provider`. Hits the network only when a
    /// `secret` is supplied and the cache is absent or stale; otherwise returns
    /// the cached or curated fallback list.
    var listModels: @Sendable (
        _ provider: ChatProvider,
        _ secret: String?,
        _ preferenceClient: ProviderPreferenceClient,
        _ urlSession: URLSession
    ) async -> [ChatModel]
}

extension ModelCatalogClient {
    /// Live implementation: cache-then-network with curated fallback.
    static let live = ModelCatalogClient { provider, secret, preferenceClient, urlSession in
        // No key → always return curated fallback immediately.
        guard let secret else {
            return ChatModel.curatedFallback
        }

        let now = Date()

        // Return the cached catalog if it exists, belongs to this provider,
        // and is still fresh.
        if let cached = preferenceClient.cachedCatalog(),
           cached.providerID == provider.id,
           !cached.isStale(maxAge: modelCatalogCacheTTL, now: now),
           !cached.models.isEmpty {
            return cached.models
        }

        // Fetch the live catalog.
        do {
            let models = try await Self.fetchModels(
                from: provider,
                secret: secret,
                urlSession: urlSession
            )
            guard !models.isEmpty else { return ChatModel.curatedFallback }

            let catalog = CachedModelCatalog(
                providerID: provider.id,
                models: models,
                fetchedAt: now
            )
            preferenceClient.setCachedCatalog(catalog)
            return models
        } catch {
            // Network or parse failure — serve whatever is in the cache
            // (even if stale) before falling back to the curated list.
            if let cached = preferenceClient.cachedCatalog(),
               cached.providerID == provider.id,
               !cached.models.isEmpty {
                return cached.models
            }
            return ChatModel.curatedFallback
        }
    }

    /// Fetches and decodes the `/models` endpoint for `provider`.
    private static func fetchModels(
        from provider: ChatProvider,
        secret: String,
        urlSession: URLSession
    ) async throws -> [ChatModel] {
        var request = URLRequest(url: provider.modelsURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in provider.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        switch provider.authScheme {
        case .bearer:
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await urlSession.data(for: request)

        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let envelope = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
        // Filter to text-capable models only; sort by free-first then
        // alphabetically so the picker is immediately useful.
        return envelope.data
            .filter { entry in
                // Exclude image/audio-only modalities.
                let modality = entry.architecture?.modality ?? ""
                return modality.isEmpty || modality.contains("text")
            }
            .map { $0.toChatModel() }
            .sorted { lhs, rhs in
                if lhs.isFree != rhs.isFree { return lhs.isFree }
                return lhs.displayName.localizedCompare(rhs.displayName) == .orderedAscending
            }
    }
}

// MARK: - TCA dependency key

extension ModelCatalogClient: DependencyKey {
    static let liveValue = ModelCatalogClient.live
    static let testValue = ModelCatalogClient { _, _, _, _ in ChatModel.curatedFallback }
    static let previewValue = ModelCatalogClient { _, _, _, _ in ChatModel.curatedFallback }
}

extension DependencyValues {
    var modelCatalog: ModelCatalogClient {
        get { self[ModelCatalogClient.self] }
        set { self[ModelCatalogClient.self] = newValue }
    }
}
