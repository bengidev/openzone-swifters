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
    var listModels: @Sendable (
        _ provider: AIProviderAPI,
        _ secret: String?,
        _ cachePreference: HomeModelCatalogCachePreferenceClient,
        _ urlSession: URLSession
    ) async -> [ChatModel]

    init(
        listModels: @escaping @Sendable (
            _ provider: AIProviderAPI,
            _ secret: String?,
            _ cachePreference: HomeModelCatalogCachePreferenceClient,
            _ urlSession: URLSession
        ) async -> [ChatModel]
    ) {
        self.listModels = listModels
    }
}

extension HomeModelCatalogClient {
    static let live = HomeModelCatalogClient { provider, secret, cachePreference, urlSession in
        guard let secret else {
            return ChatModel.curatedFallback
        }

        let now = Date()

        if let cached = cachePreference.cachedCatalog(),
           cached.providerID == provider.id,
           !cached.isStale(maxAge: modelCatalogCacheTTL, now: now),
           !cached.models.isEmpty {
            return cached.models
        }

        do {
            let models = try await Self.fetchModels(
                from: provider,
                secret: secret,
                urlSession: urlSession
            )
            guard !models.isEmpty else { return ChatModel.curatedFallback }

            let catalog = ModelCatalogCachePreference(
                providerID: provider.id,
                models: models,
                fetchedAt: now
            )
            cachePreference.setCachedCatalog(catalog)
            return models
        } catch {
            if let cached = cachePreference.cachedCatalog(),
               cached.providerID == provider.id,
               !cached.models.isEmpty {
                return cached.models
            }
            return ChatModel.curatedFallback
        }
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
    static let testValue = HomeModelCatalogClient { _, _, _, _ in ChatModel.curatedFallback }
    static let previewValue = HomeModelCatalogClient { _, _, _, _ in ChatModel.curatedFallback }
}

extension DependencyValues {
    var modelCatalog: HomeModelCatalogClient {
        get { self[HomeModelCatalogClient.self] }
        set { self[HomeModelCatalogClient.self] = newValue }
    }
}
