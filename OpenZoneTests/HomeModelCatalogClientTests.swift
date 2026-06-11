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

    @Test("displayTitle humanizes wire model ids")
    func displayTitleHumanizesModelID() {
        #expect(HomeModelCatalog.displayTitle(for: "openai/gpt-4o:free") == "gpt 4o")
        #expect(HomeModelCatalog.displayTitle(for: "meta-llama/llama-3.3-70b-instruct:free") == "llama 3.3 70b instruct")
    }

    @Test("Command Code curated fallback is never empty and differs from OpenRouter fallback")
    func commandCodeFallbackDiffersFromOpenRouter() {
        #expect(!ChatModel.commandCodeFallback.isEmpty)
        let openRouterIDs = Set(ChatModel.curatedFallback.map(\.id))
        let commandCodeIDs = Set(ChatModel.commandCodeFallback.map(\.id))
        #expect(openRouterIDs != commandCodeIDs)
    }

    @Test("curatedFallback(for:) returns provider-specific catalogs")
    func curatedFallbackProviderScoped() {
        let openRouter = ChatModel.curatedFallback(for: AIProviderAPI.openRouter.id)
        let commandCode = ChatModel.curatedFallback(for: AIProviderAPI.commandCode.id)
        let openCode = ChatModel.curatedFallback(for: AIProviderAPI.openCode.id)

        #expect(openRouter == ChatModel.curatedFallback)
        #expect(commandCode == ChatModel.commandCodeFallback)
        #expect(openCode == ChatModel.openCodeFallback)

        // Unknown provider falls back to default (OpenRouter)
        #expect(ChatModel.curatedFallback(for: "unknown") == ChatModel.curatedFallback)
        #expect(ChatModel.curatedFallback(for: nil) == ChatModel.curatedFallback)
    }
}


// MARK: - ModelCatalogCachePreference

@Suite("ModelCatalogCachePreference")
struct ModelCatalogCachePreferenceTests {

    @Test("Fresh cache is not stale")
    func freshCacheIsNotStale() {
        let now = Date()
        let cache = ModelCatalogCachePreference(
            providerID: "openrouter",
            models: ChatModel.curatedFallback,
            fetchedAt: now
        )
        #expect(!cache.isStale(maxAge: 3600, now: now.addingTimeInterval(1800)))
    }

    @Test("Cache older than TTL is stale")
    func oldCacheIsStale() {
        let now = Date()
        let cache = ModelCatalogCachePreference(
            providerID: "openrouter",
            models: ChatModel.curatedFallback,
            fetchedAt: now.addingTimeInterval(-7200)
        )
        #expect(cache.isStale(maxAge: 3600, now: now))
    }

    @Test("ModelCatalogCachePreference round-trips through Codable")
    func cachedCatalogCodable() throws {
        let cache = ModelCatalogCachePreference(
            providerID: "openrouter",
            models: ChatModel.curatedFallback,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        let data = try JSONEncoder().encode(cache)
        let decoded = try JSONDecoder().decode(ModelCatalogCachePreference.self, from: data)
        #expect(decoded == cache)
    }
}

// MARK: - Model catalog cache preference store

@Suite("ModelCatalogCachePreferenceStore")
struct ModelCatalogCachePreferenceStoreTests {

    @Test("Cache is nil by default")
    func defaultCacheIsNil() {
        let store = InMemoryModelCatalogCachePreferenceStore()
        #expect(store.cachedCatalog() == nil)
    }

    @Test("Set and get catalog round-trips")
    func setCatalogRoundTrips() {
        let store = InMemoryModelCatalogCachePreferenceStore()
        let catalog = ModelCatalogCachePreference(
            providerID: "openrouter",
            models: ChatModel.curatedFallback,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        store.setCachedCatalog(catalog)
        #expect(store.cachedCatalog() == catalog)
    }

    @Test("Setting nil clears the catalog")
    func clearCatalog() {
        let store = InMemoryModelCatalogCachePreferenceStore()
        let catalog = ModelCatalogCachePreference(
            providerID: "openrouter",
            models: ChatModel.curatedFallback,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        store.setCachedCatalog(catalog)
        store.setCachedCatalog(nil)
        #expect(store.cachedCatalog() == nil)
    }
}

// MARK: - HomeModelCatalogClient

/// A separate URLProtocol stub used exclusively by `ModelCatalogClientTests`
/// so it never shares static state with `StubURLProtocol` used by the
/// streaming client tests. Both suites are `.serialized` but Swift Testing
/// runs suites in parallel; separate classes keep each suite hermetic.
nonisolated final class CatalogStubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub: Sendable {
        var statusCode: Int
        var body: Data
        var headers: [String: String]
    }

    nonisolated(unsafe) static var stub: Stub?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let stub = Self.stub ?? Stub(statusCode: 200, body: Data(), headers: [:])
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("HomeModelCatalogClient", .serialized)
struct ModelCatalogClientTests {

    private func makeCachePreference(
        cached: ModelCatalogCachePreference? = nil
    ) -> HomeModelCatalogCachePreferenceClient {
        .wrap(InMemoryModelCatalogCachePreferenceStore(cachedCatalog: cached))
    }

    private func makeSession(responseJSON: String, statusCode: Int = 200) -> URLSession {
        CatalogStubURLProtocol.stub = .init(
            statusCode: statusCode,
            body: Data(responseJSON.utf8),
            headers: ["Content-Type": "application/json"]
        )
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CatalogStubURLProtocol.self]
        return URLSession(configuration: config)
    }

    // MARK: No key → curated fallback

    @Test("Returns curated fallback when no secret is provided")
    func noKeyReturnsFallback() async {
        let client = HomeModelCatalogClient.live
        let result = await client.listModels(.openRouter, nil, makeCachePreference(), .shared)
        #expect(result.models == ChatModel.curatedFallback)
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
        let cacheStore = InMemoryModelCatalogCachePreferenceStore()
        let cacheClient = HomeModelCatalogCachePreferenceClient.wrap(cacheStore)
        let session = makeSession(responseJSON: json)

        let client = HomeModelCatalogClient.live
        let result = await client.listModels(.openRouter, "sk-test", cacheClient, session)

        // Both models should be present.
        #expect(result.models.contains { $0.id == "openai/gpt-4o" })
        #expect(result.models.contains { $0.id == "meta-llama/llama-3.3-70b-instruct:free" })

        // Free model is correctly identified.
        let freeModel = result.models.first { $0.id == "meta-llama/llama-3.3-70b-instruct:free" }
        #expect(freeModel?.isFree == true)

        // Paid model is correctly identified.
        let paidModel = result.models.first { $0.id == "openai/gpt-4o" }
        #expect(paidModel?.isFree == false)

        // Cache was written.
        #expect(cacheStore.cachedCatalog() != nil)
        #expect(cacheStore.cachedCatalog()?.providerID == "openrouter")
        #expect(cacheStore.cachedCatalog()?.models.count == result.models.count)
    }

    @Test("Returns cached catalog when fresh, skipping the network")
    func returnsCachedCatalogWhenFresh() async {
        let cachedModels = [
            ChatModel(id: "cached/model-a", displayName: "Cached A", isFree: true)
        ]
        let cache = ModelCatalogCachePreference(
            providerID: "openrouter",
            models: cachedModels,
            fetchedAt: Date()  // Just fetched — not stale.
        )

        // The stub would return different data if the network were hit.
        let json = #"{"data": [{"id": "network/model-b", "name": "Network B"}]}"#
        let session = makeSession(responseJSON: json)

        let client = HomeModelCatalogClient.live
        let result = await client.listModels(
            .openRouter, "sk-test", makeCachePreference(cached: cache), session
        )

        // Should return cached models, not the network ones.
        #expect(result.models == cachedModels)
    }

    @Test("Fetches fresh catalog when cache is stale")
    func fetchesFreshWhenCacheIsStale() async {
        let staleModels = [
            ChatModel(id: "stale/model", displayName: "Stale", isFree: true)
        ]
        let staleCache = ModelCatalogCachePreference(
            providerID: "openrouter",
            models: staleModels,
            // Fetched 2 hours ago — stale against the 1-hour TTL.
            fetchedAt: Date().addingTimeInterval(-7200)
        )

        let json = """
        {"data": [{"id": "fresh/model", "name": "Fresh Model", "pricing": {"prompt": "0", "completion": "0"}}]}
        """
        let session = makeSession(responseJSON: json)

        let client = HomeModelCatalogClient.live
        let result = await client.listModels(
            .openRouter, "sk-test", makeCachePreference(cached: staleCache), session
        )

        // Should have bypassed the stale cache and returned the fresh network result.
        #expect(result.models.contains { $0.id == "fresh/model" })
        #expect(!result.models.contains { $0.id == "stale/model" })
    }

    @Test("Falls back to curated list on network error")
    func fallbackOnNetworkError() async {
        // Empty body + 500 → fetch throws → should return curated fallback.
        let session = makeSession(responseJSON: "", statusCode: 500)
        let client = HomeModelCatalogClient.live
        let result = await client.listModels(.openRouter, "sk-test", makeCachePreference(), session)
        #expect(result.models == ChatModel.curatedFallback)
    }

    @Test("Falls back to stale cache on network error before curated list")
    func fallbackToStaleCacheBeforeCurated() async {
        let staleModels = [
            ChatModel(id: "stale/model", displayName: "Stale", isFree: true)
        ]
        let staleCache = ModelCatalogCachePreference(
            providerID: "openrouter",
            models: staleModels,
            fetchedAt: Date().addingTimeInterval(-7200)
        )
        let session = makeSession(responseJSON: "", statusCode: 500)
        let client = HomeModelCatalogClient.live

        let result = await client.listModels(
            .openRouter, "sk-test", makeCachePreference(cached: staleCache), session
        )
        // Should serve the stale cache rather than the curated fallback.
        #expect(result.models == staleModels)
    }

    @Test("403 response surfaces upgrade hint in catalog error")
    func forbiddenSurfacesErrorHint() async {
        let body = #"{"error":{"message":"Your Go plan doesn't include API access. Upgrade to Provider or higher.","code":"upgrade_required"}}"#
        let session = makeSession(responseJSON: body, statusCode: 403)
        let client = HomeModelCatalogClient.live
        let result = await client.listModels(.commandCode, "sk-test", makeCachePreference(), session)

        // Should fall back to Command Code curated models.
        #expect(result.models == ChatModel.curatedFallback(for: "commandcode"))
        // And surface the error hint.
        #expect(result.errorHint != nil)
        #expect(result.errorHint!.contains("Go plan"))
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
        let client = HomeModelCatalogClient.live
        let result = await client.listModels(.openRouter, "sk-test", makeCachePreference(), session)

        let r1 = result.models.first { $0.id == "deepseek/deepseek-r1:free" }
        let llama = result.models.first { $0.id == "meta-llama/llama-3.3-70b-instruct:free" }
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
            $0[CredentialStoreClient.self] = CredentialStoreClient(
                secret: { _ in InMemoryCredentialStore(secret: "sk-test").secret() },
                save: { _, _ in },
                clear: { _ in }
            )
            $0[AIProviderPreferenceClient.self] = .wrap(InMemoryAIProviderPreferenceStore())
            $0[HomeModelCatalogClient.self] = HomeModelCatalogClient { _, _, _, _ in .init(models: expectedModels) }
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
            ChatModel(id: "b/paid", displayName: "Paid Model", isFree: false)
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
            ChatModel(id: "meta-llama/llama-3.3-70b-instruct:free", displayName: "Llama 3.3 70B", isFree: true)
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

    @Test("Empty catalog falls back to provider-scoped curated list")
    func emptyCatalogFallsBackToProviderScoped() {
        var state = HomeFeature.State()
        state.catalogModels = []
        state.appliedSearchQuery = ""
        state.modelFilterFreeOnly = false

        // Default provider (OpenRouter) uses the generic fallback.
        #expect(state.availableModels.count == ChatModel.curatedFallback.count)

        // Command Code provider uses its own fallback.
        state.selectedProviderID = AIProviderAPI.commandCode.id
        #expect(state.availableModels.count == ChatModel.commandCodeFallback.count)
        #expect(state.availableModels.first?.id == ChatModel.commandCodeFallback.first?.id)

        // OpenCode provider uses its own fallback.
        state.selectedProviderID = AIProviderAPI.openCode.id
        #expect(state.availableModels.count == ChatModel.openCodeFallback.count)
    }

    @Test("Provider change triggers catalog fetch and auto-selects first model")
    func providerChangeTriggersCatalogFetch() async {
        let commandCodeModels = [
            ChatModel(id: "deepseek/deepseek-v4-flash", displayName: "DeepSeek V4 Flash", isFree: true),
            ChatModel(id: "deepseek/deepseek-r1", displayName: "DeepSeek R1", isFree: true, supportsReasoning: true)
        ]
        var initial = HomeFeature.State()
        initial.selectedProviderID = AIProviderAPI.openRouter.id
        initial.selectedModelID = "meta-llama/llama-3.3-70b-instruct:free"
        initial.catalogModels = [ChatModel(id: "meta-llama/llama-3.3-70b-instruct:free", displayName: "Llama 3.3 70B", isFree: true)]

        let store = TestStore(initialState: initial) {
            HomeFeature()
        } withDependencies: {
            $0[CredentialStoreClient.self] = CredentialStoreClient(
                secret: { _ in nil },
                save: { _, _ in },
                clear: { _ in }
            )
            $0[AIProviderPreferenceClient.self] = .wrap(InMemoryAIProviderPreferenceStore())
            $0[HomeModelCatalogClient.self] = HomeModelCatalogClient { _, _, _, _ in .init(models: commandCodeModels) }
        }
        store.exhaustivity = .off

        await store.send(.sidePanel(.delegate(.providerChanged(AIProviderAPI.commandCode.id))))

        // The catalog should load for the new provider and auto-select the first model.
        await store.receive(\.catalogLoaded) { state in
            state.catalogModels = commandCodeModels
            state.selectedModelID = commandCodeModels[0].id
            state.sidePanel.selectedProviderID = AIProviderAPI.commandCode.id
        }

        #expect(store.state.selectedProviderID == AIProviderAPI.commandCode.id)
        #expect(store.state.selectedModelID == "deepseek/deepseek-v4-flash")
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
            $0[CredentialStoreClient.self] = CredentialStoreClient(
                secret: { _ in nil },
                save: { _, _ in },
                clear: { _ in }
            )
            $0[AIProviderPreferenceClient.self] = .wrap(InMemoryAIProviderPreferenceStore())
            $0[HomeModelCatalogClient.self] = HomeModelCatalogClient { _, _, _, _ in .init(models: []) }
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
            $0[CredentialStoreClient.self] = CredentialStoreClient(
                secret: { _ in nil },
                save: { _, _ in },
                clear: { _ in }
            )
            $0[AIProviderPreferenceClient.self] = .wrap(InMemoryAIProviderPreferenceStore())
            $0[HomeModelCatalogClient.self] = HomeModelCatalogClient { _, _, _, _ in .init(models: []) }
            $0.continuousClock = clock
        }

        await store.send(.modelSearchQueryChanged("llama")) { state in
            state.modelSearchQuery = "llama"
        }

        // Before the debounce window, appliedSearchQuery is still empty.
        #expect(store.state.appliedSearchQuery.isEmpty)

        // Advance past the 300 ms window.
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.searchQueryDebounced) { state in
            state.appliedSearchQuery = "llama"
        }
    }
}
