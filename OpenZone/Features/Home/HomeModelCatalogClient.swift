import ComposableArchitecture
import Foundation

// MARK: - Provider wire types

private nonisolated struct ProviderModelsResponse: Decodable, Sendable {
    let data: [ProviderModelEntry]
}

private nonisolated struct ProviderModelEntry: Decodable, Sendable {
    let id: String
    let name: String?
    let contextLength: Int?
    let architecture: Architecture?
    let pricing: Pricing?

    enum CodingKeys: String, CodingKey {
        case id, name
        case contextLength = "context_length"
        case architecture
        case pricing
    }

    nonisolated struct Architecture: Decodable, Sendable {
        let modality: String?
    }

    nonisolated struct Pricing: Decodable, Sendable {
        let prompt: String?
        let completion: String?
        let promo: String?
    }

    var isFree: Bool {
        // If pricing info exists (OpenRouter style), use it.
        if let pricing { return pricing.promo == "0" || pricing.completion == "0" }
        // For providers without pricing info, check if name contains "free"
        if let name { return name.lowercased().contains("free") }
        return false
    }

    var supportsReasoning: Bool {
        // OpenRouter uses model id patterns. Keep existing logic for OpenRouter,
        // but also check for common reasoning model patterns.
        let reasoningIDs: Set<String> = [
            "deepseek-r1", "deepseek-r1-distill",
            "deepseek/deepseek-r1", "deepseek/deepseek-r1-distill",
            "openai/o1", "openai/o3", "openai/o1-mini", "openai/o3-mini",
            "qwen/qwq", "qwen/qvq",
            "deepseek-v4-pro", "deepseek-v4-flash",
            "deepseek-v4-pro-free", "deepseek-v4-flash-free",
            "kimi-k2.5", "kimi-k2.6"
        ]
        for prefix in reasoningIDs {
            if id.hasPrefix(prefix) || id.contains(prefix) { return true }
        }
        // OpenRouter-style detection via architecture
        if let modality = architecture?.modality, modality.contains("reasoning") { return true }
        return false
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

nonisolated let modelCatalogCacheTTL: TimeInterval = 60 * 60 // 1 hour

/// TCA dependency for fetching the provider model catalog for the Home composer.
nonisolated struct HomeModelCatalogClient: Sendable {
    /// The result of a catalog fetch, carrying either the models list (possibly
    /// the curated fallback) and an optional error hint when the fetch failed
    /// with an actionable problem (e.g. 403 — key present but plan lacks access).
    nonisolated struct CatalogResult: Equatable, Sendable {
        let models: [ChatModel]
        /// Non-nil when the live fetch failed and the user should be notified.
        /// E.g. "Your Command Code Go plan doesn't include API access."
        let errorHint: String?

        init(models: [ChatModel], errorHint: String? = nil) {
            self.models = models
            self.errorHint = errorHint
        }
    }

    var listModels: @Sendable (
        _ provider: AIProviderAPI,
        _ secret: String?,
        _ cachePreference: HomeModelCatalogCachePreferenceClient,
        _ urlSession: URLSession
    ) async -> CatalogResult

    init(
        listModels: @escaping @Sendable (
            _ provider: AIProviderAPI,
            _ secret: String?,
            _ cachePreference: HomeModelCatalogCachePreferenceClient,
            _ urlSession: URLSession
        ) async -> CatalogResult
    ) {
        self.listModels = listModels
    }
}

extension HomeModelCatalogClient {
    static let live = HomeModelCatalogClient { provider, secret, cachePreference, urlSession in
        guard let secret else {
            return CatalogResult(models: ChatModel.curatedFallback(for: provider.id))
        }

        let now = Date()

        if let cached = cachePreference.cachedCatalog(),
           cached.providerID == provider.id,
           !cached.isStale(maxAge: modelCatalogCacheTTL, now: now),
           !cached.models.isEmpty {
            return CatalogResult(models: cached.models)
        }

        do {
            let models = try await Self.fetchModels(
                from: provider,
                secret: secret,
                urlSession: urlSession
            )
            guard !models.isEmpty else {
                return CatalogResult(models: ChatModel.curatedFallback(for: provider.id))
            }

            let catalog = ModelCatalogCachePreference(
                providerID: provider.id,
                models: models,
                fetchedAt: now
            )
            cachePreference.setCachedCatalog(catalog)
            return CatalogResult(models: models)
        } catch let catalogError as CatalogFetchError {
            if let cached = cachePreference.cachedCatalog(),
               cached.providerID == provider.id,
               !cached.models.isEmpty {
                return CatalogResult(models: cached.models, errorHint: catalogError.errorHint)
            }
            return CatalogResult(
                models: ChatModel.curatedFallback(for: provider.id),
                errorHint: catalogError.errorHint
            )
        } catch {
            if let cached = cachePreference.cachedCatalog(),
               cached.providerID == provider.id,
               !cached.models.isEmpty {
                return CatalogResult(models: cached.models)
            }
            return CatalogResult(models: ChatModel.curatedFallback(for: provider.id))
        }
    }

    /// An actionable catalog-fetch error that carries a user-facing hint.
    /// Thrown by `fetchModels` when the server returns a status that
    /// indicates a plan or permission problem (e.g. 403 on Command Code
    /// when the Go plan lacks API access).
    nonisolated struct CatalogFetchError: Error, Sendable {
        let errorHint: String
    }

    private static func fetchModels(
        from provider: AIProviderAPI,
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
            // 403 with a key present usually means the plan doesn't include
            // API access (e.g. Command Code Go plan). Surface a hint so the
            // user knows to upgrade rather than wondering why models don't work.
            if http.statusCode == 403 {
                let providerMessage = OpenAICompatibleStreamingClient.decodeErrorBody(data)
                let hint = providerMessage
                    ?? "Your plan doesn't include API access. Upgrade to use these endpoints."
                throw CatalogFetchError(errorHint: hint)
            }
            throw URLError(.badServerResponse)
        }

        let envelope = try JSONDecoder().decode(ProviderModelsResponse.self, from: data)
        return envelope.data
            .filter { entry in
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

extension HomeModelCatalogClient: DependencyKey {
    static let liveValue = HomeModelCatalogClient.live
    static let testValue = HomeModelCatalogClient { _, _, _, _ in CatalogResult(models: ChatModel.curatedFallback) }
    static let previewValue = HomeModelCatalogClient { _, _, _, _ in CatalogResult(models: ChatModel.curatedFallback) }
}

extension DependencyValues {
    var modelCatalog: HomeModelCatalogClient {
        get { self[HomeModelCatalogClient.self] }
        set { self[HomeModelCatalogClient.self] = newValue }
    }
}
