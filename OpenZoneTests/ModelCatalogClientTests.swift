import ComposableArchitecture
import Foundation
import Testing

@testable import OpenZone

// MARK: - ChatModel value type

@Suite("ChatModel")
struct ChatModelTests {

    @Test("Curated fallback is never empty")
    func curatedFallbackNonEmpty() {
        #expect(!ChatModel.curatedFallback.isEmpty)
    }

    @Test("All curated fallback models are marked free")
    func curatedFallbackAllFree() {
        #expect(ChatModel.curatedFallback.allSatisfy { $0.isFree })
    }

    @Test("ChatModel round-trips through Codable")
    func chatModelCodable() throws {
        let model = ChatModel(
            id: "meta-llama/llama-3.3-70b-instruct:free",
            displayName: "Llama 3.3 70B",
            isFree: true,
            contextLength: 131_072,
            supportsReasoning: false
        )
        let data = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(ChatModel.self, from: data)
        #expect(decoded == model)
    }
}

// MARK: - CachedModelCatalog

@Suite("CachedModelCatalog")
struct CachedModelCatalogTests {

    @Test("Fresh cache is not stale")
    func freshCacheIsNotStale() {
        let now = Date()
        let cache = CachedModelCatalog(
            providerID: "openrouter",
            models: ChatModel.curatedFallback,
            fetchedAt: now
        )
        #expect(!cache.isStale(maxAge: 3600, now: now.addingTimeInterval(1800)))
    }

    @Test("Cache older than TTL is stale")
    func oldCacheIsStale() {
        let now = Date()
        let cache = CachedModelCatalog(
            providerID: "openrouter",
            models: ChatModel.curatedFallback,
            fetchedAt: now.addingTimeInterval(-7200)
        )
        #expect(cache.isStale(maxAge: 3600, now: now))
    }

    @Test("CachedModelCatalog round-trips through Codable")
    func cachedCatalogCodable() throws {
        let cache = CachedModelCatalog(
            providerID: "openrouter",
            models: ChatModel.curatedFallback,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        let data = try JSONEncoder().encode(cache)
        let decoded = try JSONDecoder().decode(CachedModelCatalog.self, from: data)
        #expect(decoded == cache)
    }
}

// MARK: - InMemoryProviderPreferenceStore cache methods

@Suite("ProviderPreferenceStore catalog cache")
struct ProviderPreferenceCatalogCacheTests {

    @Test("Cache is nil by default")
    func defaultCacheIsNil() {
        let store = InMemoryProviderPreferenceStore()
        #expect(store.cachedCatalog() == nil)
    }

    @Test("Set and get catalog round-trips")
    func setCatalogRoundTrips() {
        let store = InMemoryProviderPreferenceStore()
        let catalog = CachedModelCatalog(
            providerID: "openrouter",
            models: ChatModel.curatedFallback,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        store.setCachedCatalog(catalog)
        #expect(store.cachedCatalog() == catalog)
    }

    @Test("Setting nil clears the catalog")
    func clearCatalog() {
        let store = InMemoryProviderPreferenceStore()
        let catalog = CachedModelCatalog(
            providerID: "openrouter",
            models: ChatModel.curatedFallback,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        store.setCachedCatalog(catalog)
        store.setCachedCatalog(nil)
        #expect(store.cachedCatalog() == nil)
    }
}

// MARK: - ModelCatalogClient

@Suite("ModelCatalogClient", .serialized)
struct ModelCatalogClientTests {

    private func makePreference(
        cached: CachedModelCatalog? = nil
    ) -> ProviderPreferenceClient {
        .wrap(InMemoryProviderPreferenceStore(cachedCatalog: cached))
    }

    private func makeSession(responseJSON: String, statusCode: Int = 200) -> URLSession {
        StubURLProtocol.stub = .init(
            statusCode: statusCode,
            body: Data(responseJSON.utf8),
            headers: ["Content-Type": "application/json"]
        )
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    // MARK: No key → curated fallback

    @Test("Returns curated fallback when no secret is provided")
    func noKeyReturnsFallback() async {
        let client = ModelCatalogClient.live
        let result = await client.listModels(.openRouter, nil, makePreference(), .shared)
        #expect(result == ChatModel.curatedFallback)
    }

    // MARK: Live fetch

    @Test("Parses live catalog response and caches it")
    func parsesLiveCatalogAndCaches() async {
        let json = """
        {
            "data": [
                {
                    "id": "openai/gpt-4o",
                    "name": "GPT-4o",
                    "context_length": 128000,
                    "architecture": {"modality": "text+image->text"},
                    "pricing": {"prompt": "0.0000025", "completion": "0.00001"}
                },
                {
                    "id": "meta-llama/llama-3.3-70b-instruct:free",
                    "name": "Llama 3.3 70B Instruct",
                    "context_length": 131072,
                    "architecture": {"modality": "text->text"},
                    "pricing": {"prompt": "0", "completion": "0"}
                }
            ]
        }
        """
        let preferenceStore = InMemoryProviderPreferenceStore()
        let preferenceClient = ProviderPreferenceClient.wrap(preferenceStore)
        let session = makeSession(responseJSON: json)

        let client = ModelCatalogClient.live
        let result = await client.listModels(.openRouter, "sk-test", preferenceClient, session)

        // Both models should be present.
        #expect(result.contains { $0.id == "openai/gpt-4o" })
        #expect(result.contains { $0.id == "meta-llama/llama-3.3-70b-instruct:free" })

        // Free model is correctly identified.
        let freeModel = result.first { $0.id == "meta-llama/llama-3.3-70b-instruct:free" }
        #expect(freeModel?.isFree == true)

        // Paid model is correctly identified.
        let paidModel = result.first { $0.id == "openai/gpt-4o" }
        #expect(paidModel?.isFree == false)

        // Cache was written.
        #expect(preferenceStore.cachedCatalog() != nil)
        #expect(preferenceStore.cachedCatalog()?.providerID == "openrouter")
        #expect(preferenceStore.cachedCatalog()?.models.count == result.count)
    }

    @Test("Returns cached catalog when fresh, skipping the network")
    func returnsCachedCatalogWhenFresh() async {
        let cachedModels = [
            ChatModel(id: "cached/model-a", displayName: "Cached A", isFree: true)
        ]
        let cache = CachedModelCatalog(
            providerID: "openrouter",
            models: cachedModels,
            fetchedAt: Date()  // Just fetched — not stale.
        )

        // The stub would return different data if the network were hit.
        let json = #"{"data": [{"id": "network/model-b", "name": "Network B"}]}"#
        let session = makeSession(responseJSON: json)

        let client = ModelCatalogClient.live
        let result = await client.listModels(
            .openRouter, "sk-test", makePreference(cached: cache), session
        )

        // Should return cached models, not the network ones.
        #expect(result == cachedModels)
    }

    @Test("Fetches fresh catalog when cache is stale")
    func fetchesFreshWhenCacheIsStale() async {
        let staleModels = [
            ChatModel(id: "stale/model", displayName: "Stale", isFree: true)
        ]
        let staleCache = CachedModelCatalog(
            providerID: "openrouter",
            models: staleModels,
            // Fetched 2 hours ago — stale against the 1-hour TTL.
            fetchedAt: Date().addingTimeInterval(-7200)
        )

        let json = """
        {"data": [{"id": "fresh/model", "name": "Fresh Model", "pricing": {"prompt": "0", "completion": "0"}}]}
        """
        let session = makeSession(responseJSON: json)

        let client = ModelCatalogClient.live
        let result = await client.listModels(
            .openRouter, "sk-test", makePreference(cached: staleCache), session
        )

        // Should have bypassed the stale cache and returned the fresh network result.
        #expect(result.contains { $0.id == "fresh/model" })
        #expect(!result.contains { $0.id == "stale/model" })
    }

    @Test("Falls back to curated list on network error")
    func fallbackOnNetworkError() async {
        // Empty body + 500 → fetch throws → should return curated fallback.
        let session = makeSession(responseJSON: "", statusCode: 500)
        let client = ModelCatalogClient.live
        let result = await client.listModels(.openRouter, "sk-test", makePreference(), session)
        #expect(result == ChatModel.curatedFallback)
    }

    @Test("Falls back to stale cache on network error before curated list")
    func fallbackToStaleCacheBeforeCurated() async {
        let staleModels = [
            ChatModel(id: "stale/model", displayName: "Stale", isFree: true)
        ]
        let staleCache = CachedModelCatalog(
            providerID: "openrouter",
            models: staleModels,
            fetchedAt: Date().addingTimeInterval(-7200)
        )
        let session = makeSession(responseJSON: "", statusCode: 500)
        let client = ModelCatalogClient.live

        let result = await client.listModels(
            .openRouter, "sk-test", makePreference(cached: staleCache), session
        )
        // Should serve the stale cache rather than the curated fallback.
        #expect(result == staleModels)
    }

    @Test("Reasoning support detected for known model ids")
    func reasoningSupport() async {
        let json = """
        {"data": [
            {"id": "deepseek/deepseek-r1:free", "name": "DeepSeek R1",
             "pricing": {"prompt": "0", "completion": "0"}},
            {"id": "meta-llama/llama-3.3-70b-instruct:free", "name": "Llama 3.3",
             "pricing": {"prompt": "0", "completion": "0"}}
        ]}
        """
        let session = makeSession(responseJSON: json)
        let client = ModelCatalogClient.live
        let result = await client.listModels(.openRouter, "sk-test", makePreference(), session)

        let r1 = result.first { $0.id == "deepseek/deepseek-r1:free" }
        let llama = result.first { $0.id == "meta-llama/llama-3.3-70b-instruct:free" }
        #expect(r1?.supportsReasoning == true)
        #expect(llama?.supportsReasoning == false)
    }
}

// MARK: - HomeFeature catalog wiring

@MainActor
@Suite("HomeFeature catalog loading")
struct HomeFeatureCatalogTests {

    @Test("onAppear triggers catalog load and catalogLoaded updates state")
    func onAppearLoadsCatalog() async {
        let expectedModels = [
            ChatModel(id: "test/model-a", displayName: "Test A", isFree: true)
        ]
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0[CredentialStoreClient.self] = .wrap(InMemoryCredentialStore(secret: "sk-test"))
            $0[ProviderPreferenceClient.self] = .wrap(InMemoryProviderPreferenceStore())
            $0[ModelCatalogClient.self] = ModelCatalogClient { _, _, _, _ in expectedModels }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.catalogLoaded) { state in
            state.catalogModels = expectedModels
        }
    }

    @Test("filteredModels uses catalog when available")
    func filteredModelsUsesCatalog() async {
        var state = HomeFeature.State()
        state.catalogModels = [
            ChatModel(id: "a/free", displayName: "Free Model", isFree: true),
            ChatModel(id: "b/paid", displayName: "Paid Model", isFree: false),
        ]
        state.appliedSearchQuery = ""
        state.modelFilterFreeOnly = false
        #expect(state.filteredModels.count == 2)

        state.modelFilterFreeOnly = true
        #expect(state.filteredModels.count == 1)
        #expect(state.filteredModels.first?.id == "a/free")
    }

    @Test("Search query filters by title and id")
    func searchQueryFilters() {
        var state = HomeFeature.State()
        state.catalogModels = [
            ChatModel(id: "openai/gpt-4o", displayName: "GPT-4o", isFree: false),
            ChatModel(id: "meta-llama/llama-3.3-70b-instruct:free", displayName: "Llama 3.3 70B", isFree: true),
        ]
        state.appliedSearchQuery = "llama"
        #expect(state.filteredModels.count == 1)
        #expect(state.filteredModels.first?.id == "meta-llama/llama-3.3-70b-instruct:free")
    }

    @Test("Empty catalog falls back to curated list in filteredModels")
    func emptyCatalogFallsBackToCurated() {
        var state = HomeFeature.State()
        state.catalogModels = []
        state.appliedSearchQuery = ""
        state.modelFilterFreeOnly = false
        #expect(state.filteredModels.count == ChatModel.curatedFallback.count)
    }

    @Test("modelPopupPresented resets search state")
    func popupOpenResetsSearch() async {
        // Seed state that already has a search query and filter, so the reset
        // behavior is observable without triggering the debounce effect.
        var initial = HomeFeature.State()
        initial.modelSearchQuery = "gpt"
        initial.appliedSearchQuery = "gpt"
        initial.modelFilterFreeOnly = true

        let store = TestStore(initialState: initial) {
            HomeFeature()
        } withDependencies: {
            $0[CredentialStoreClient.self] = .wrap(InMemoryCredentialStore())
            $0[ProviderPreferenceClient.self] = .wrap(InMemoryProviderPreferenceStore())
            $0[ModelCatalogClient.self] = ModelCatalogClient { _, _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        // Opening the popup resets search query and filter.
        await store.send(.modelPopupPresented(true)) { state in
            state.modelSearchQuery = ""
            state.appliedSearchQuery = ""
            state.modelFilterFreeOnly = false
            state.isModelPopupPresented = true
        }
    }

    @Test("Debounced search commits to appliedSearchQuery after sleep")
    func debouncedSearchCommits() async {
        let clock = TestClock()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0[CredentialStoreClient.self] = .wrap(InMemoryCredentialStore())
            $0[ProviderPreferenceClient.self] = .wrap(InMemoryProviderPreferenceStore())
            $0[ModelCatalogClient.self] = ModelCatalogClient { _, _, _, _ in [] }
            $0.continuousClock = clock
        }

        await store.send(.modelSearchQueryChanged("llama")) { state in
            state.modelSearchQuery = "llama"
        }

        // Before the debounce window, appliedSearchQuery is still "".
        #expect(store.state.appliedSearchQuery == "")

        // Advance past the 300 ms window.
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.searchQueryDebounced) { state in
            state.appliedSearchQuery = "llama"
        }
    }
}
