import ComposableArchitecture
import Foundation

// MARK: - OpenRouter wire types

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

    var isFree: Bool {
        guard let prompt = pricing?.prompt, let completion = pricing?.completion else {
            return id.hasSuffix(":free")
        }
        return (prompt == "0" || prompt == "0.0") && (completion == "0" || completion == "0.0")
    }

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

nonisolated let modelCatalogCacheTTL: TimeInterval = 60 * 60 // 1 hour

/// TCA dependency for fetching the provider model catalog for the Home composer.
nonisolated struct ModelCatalogClient: Sendable {
    var listModels: @Sendable (
        _ provider: AIProviderAPI,
        _ secret: String?,
        _ cachePreference: ModelCatalogCachePreferenceClient,
        _ urlSession: URLSession
    ) async -> [ChatModel]

    init(
        listModels: @escaping @Sendable (
            _ provider: AIProviderAPI,
            _ secret: String?,
            _ cachePreference: ModelCatalogCachePreferenceClient,
            _ urlSession: URLSession
        ) async -> [ChatModel]
    ) {
        self.listModels = listModels
    }
}

extension ModelCatalogClient {
    static let live = ModelCatalogClient { provider, secret, cachePreference, urlSession in
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

        let envelope = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
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
