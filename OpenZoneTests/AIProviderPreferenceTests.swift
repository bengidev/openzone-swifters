import ComposableArchitecture
import Foundation
import Testing

@testable import OpenZone

/// Covers the Slice 3 single-source-of-truth wiring: the canned-event stub that
/// replaced the deleted mocks, the UserDefaults-backed preference store, and the
/// reducer's send-gate on a selected model.
struct AIProviderPreferenceTests {

    // MARK: - Canned-event stub (mock replacement)

    @Test("Canned-event stub replays its script and terminates with .done")
    func cannedStubReplaysScript() async {
        let client = ChatCannedEventClient()
        let request = ChatRequest(
            conversationID: UUID(),
            messages: [.text(role: .user, content: "Hello")],
            provider: .openRouter,
            modelID: "any-model"
        )

        var events: [ChatStreamingEvent] = []
        for await event in client.stream(request: request) {
            events.append(event)
        }

        #expect(events.contains { if case .thinkingDelta = $0 { return true }; return false })
        #expect(events.contains { if case .textDelta = $0 { return true }; return false })
        #expect(events.last == .done)
    }

    @Test("Canned-event stub replays a custom script verbatim")
    func cannedStubCustomScript() async {
        let script: [ChatStreamingEvent] = [.textDelta("hi"), .done]
        let client = ChatCannedEventClient(events: script)
        let request = ChatRequest(
            conversationID: UUID(),
            messages: [],
            provider: .openRouter,
            modelID: "m"
        )

        var events: [ChatStreamingEvent] = []
        for await event in client.stream(request: request) {
            events.append(event)
        }

        #expect(events == script)
    }

    // MARK: - In-memory preference store

    @Test("Preference store round-trips provider and model ids")
    func preferenceRoundTrips() {
        let store = ExternalInMemoryAIProviderPreferenceStore()
        #expect(store.preference().providerID == nil)
        #expect(store.preference().modelID == nil)

        store.setProviderID("openrouter")
        store.setModelID("deepseek/deepseek-r1:free")

        #expect(store.preference().providerID == "openrouter")
        #expect(store.preference().modelID == "deepseek/deepseek-r1:free")

        store.setModelID(nil)
        #expect(store.preference().modelID == nil)
    }

    // MARK: - Provider catalog resolution

    @Test("Unknown or absent provider id resolves to the default provider")
    func providerResolutionFallsBack() {
        #expect(ExternalAIProviderAPI.resolve(id: nil) == .default)
        #expect(ExternalAIProviderAPI.resolve(id: "does-not-exist") == .default)
        #expect(ExternalAIProviderAPI.resolve(id: ExternalAIProviderAPI.openRouter.id) == .openRouter)
        #expect(ExternalAIProviderAPI.resolve(id: ExternalAIProviderAPI.commandCode.id) == .commandCode)
    }

    @Test("Command Code provider exposes OpenAI-compatible endpoints")
    func commandCodeEndpoints() {
        let provider = ExternalAIProviderAPI.commandCode

        #expect(provider.id == "commandcode")
        #expect(provider.displayName == "Command Code")
        #expect(provider.authScheme == .bearer)
        #expect(provider.defaultHeaders.isEmpty)
        #expect(
            provider.chatCompletionsURL.absoluteString
                == "https://api.commandcode.ai/provider/v1/chat/completions"
        )
        #expect(
            provider.modelsURL.absoluteString == "https://api.commandcode.ai/provider/v1/models"
        )
        #expect(ExternalAIProviderAPI.all.contains(provider))
    }

    // MARK: - Model catalog

    @Test("Model catalog resolves a known id and rejects an unknown one")
    func modelCatalogResolution() {
        let known = HomeModelCatalog.models(for: ExternalAIProviderAPI.openRouter.id).first!
        #expect(HomeModelCatalog.option(for: known.id, providerID: ExternalAIProviderAPI.openRouter.id) != nil)
        #expect(HomeModelCatalog.option(for: "ghost-model", providerID: ExternalAIProviderAPI.openRouter.id) == nil)
        #expect(HomeModelCatalog.option(for: nil, providerID: nil) == nil)
    }
}

/// Reducer-level send-gating on a selected model, isolated from the streaming
/// assertions in `ChatReasoningStreamingTests`.
@MainActor
@Suite("Chat Send Gating")
struct ChatSendGatingTests {

    private func makeStore(
        preference: ExternalAIProviderPreference
    ) -> TestStoreOf<ChatFeature> {
        TestStore(initialState: ChatFeature.State()) {
            ChatFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0[ExternalAIProviderPreferenceClient.self] = .wrap(
                ExternalInMemoryAIProviderPreferenceStore(preference: preference)
            )
            $0[ChatAPIClient.self] = ChatAPIClient(stream: { _ in
                AsyncStream { continuation in
                    continuation.yield(.textDelta("ok"))
                    continuation.yield(.done)
                    continuation.finish()
                }
            })
        }
    }

    @Test("Send is a no-op when no model is selected")
    func sendBlockedWithoutModel() async {
        let store = makeStore(preference: ExternalAIProviderPreference(providerID: "openrouter", modelID: nil))
        store.exhaustivity = .off

        await store.send(.draftMessageChanged("Hello"))
        await store.send(.sendMessageTapped)

        // No model -> the guard short-circuits, nothing is appended and no turn starts.
        #expect(store.state.messages.isEmpty)
        #expect(store.state.isSending == false)
    }

    @Test("Send proceeds when a model is selected")
    func sendProceedsWithModel() async {
        let store = makeStore(
            preference: ExternalAIProviderPreference(
                providerID: "openrouter",
                modelID: "meta-llama/llama-3.3-70b-instruct:free"
            )
        )
        store.exhaustivity = .off

        await store.send(.draftMessageChanged("Hello"))
        await store.send(.sendMessageTapped)
        await store.receive(\.streamCompleted)

        // The user message plus a streamed assistant answer landed.
        #expect(store.state.messages.contains { if case .text = $0 { return true }; return false })
        #expect(store.state.streamingStatus == .done)
    }
}

/// Home composer selection persists to the preference store as the single
/// source of truth, and seeds from it on appear.
@MainActor
@Suite("Home Model Selection")
struct HomeModelSelectionTests {

    @Test("Selecting a model persists it to the preference store and opens the model gate")
    func selectingModelPersists() async {
        let backing = ExternalInMemoryAIProviderPreferenceStore()
        let credentialStore = ExternalInMemoryCredentialStore(secret: "sk-existing")
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0[ExternalAIProviderPreferenceClient.self] = .wrap(backing)
            $0[ExternalCredentialStoreClient.self] = ExternalCredentialStoreClient(
                secret: { _ in credentialStore.secret() },
                save: { _, secret in try credentialStore.save(secret: secret) },
                clear: { _ in try credentialStore.clear() }
            )
        }
        store.exhaustivity = .off

        #expect(store.state.hasSelectedModel == false)

        let model = HomeModelCatalog.models(for: ExternalAIProviderAPI.openRouter.id).first!
        await store.send(.composerModelSelected(model.id))

        #expect(backing.preference().modelID == model.id)
        #expect(backing.preference().providerID == ExternalAIProviderAPI.openRouter.id)
        #expect(store.state.selectedModelID == model.id)
        #expect(store.state.hasSelectedModel == true)
    }

    @Test("onAppear seeds the selection from the stored preference")
    func onAppearSeedsFromPreference() async {
        let known = HomeModelCatalog.models(for: ExternalAIProviderAPI.openRouter.id).first!
        let backing = ExternalInMemoryAIProviderPreferenceStore(
            preference: ExternalAIProviderPreference(providerID: ExternalAIProviderAPI.openRouter.id, modelID: known.id)
        )
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0[ExternalAIProviderPreferenceClient.self] = .wrap(backing)
            $0[ExternalCredentialStoreClient.self] = ExternalCredentialStoreClient(
                secret: { _ in nil },
                save: { _, _ in },
                clear: { _ in }
            )
        }
        store.exhaustivity = .off

        await store.send(.onAppear)

        #expect(store.state.selectedModelID == known.id)
        #expect(store.state.hasSelectedModel == true)
    }

    @Test("Unknown stored model id still resolves a composer option")
    func unknownStoredModelResolvesSyntheticOption() {
        var state = HomeFeature.State()
        state.selectedModelID = "openai/gpt-4o:free"

        let option = state.selectedModelOption

        #expect(option?.id == "openai/gpt-4o:free")
        #expect(option?.title == "gpt 4o")
        #expect(state.hasSelectedModel == true)
    }

    @Test("catalogLoaded auto-selects the first model when none is stored")
    func catalogLoadedAutoSelectsDefaultModel() async {
        let expectedModels = [
            ChatModel(id: "test/model-a", displayName: "Test A", isFree: true),
            ChatModel(id: "test/model-b", displayName: "Test B", isFree: false)
        ]
        let backing = ExternalInMemoryAIProviderPreferenceStore()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0[ExternalAIProviderPreferenceClient.self] = .wrap(backing)
            $0[ExternalCredentialStoreClient.self] = ExternalCredentialStoreClient(
                secret: { _ in nil },
                save: { _, _ in },
                clear: { _ in }
            )
            $0[HomeModelCatalogClient.self] = HomeModelCatalogClient { _, _, _, _ in .init(models: expectedModels) }
        }
        store.exhaustivity = .off

        await store.send(.catalogLoaded(expectedModels)) { state in
            state.catalogModels = expectedModels
            state.selectedModelID = expectedModels[0].id
            state.sidePanel.selectedProviderID = state.selectedProviderID
        }

        #expect(backing.preference().modelID == expectedModels[0].id)
        #expect(store.state.selectedModelOption?.title == "Test A")
    }

    @Test("catalogLoaded replaces an invalid stored model with the first available option")
    func catalogLoadedReplacesInvalidSelection() async {
        let expectedModels = [
            ChatModel(id: "test/model-a", displayName: "Test A", isFree: true)
        ]
        let backing = ExternalInMemoryAIProviderPreferenceStore(
            preference: ExternalAIProviderPreference(
                providerID: ExternalAIProviderAPI.openRouter.id,
                modelID: "stale/model-id"
            )
        )
        var initial = HomeFeature.State()
        initial.selectedModelID = "stale/model-id"

        let store = TestStore(initialState: initial) {
            HomeFeature()
        } withDependencies: {
            $0[ExternalAIProviderPreferenceClient.self] = .wrap(backing)
            $0[ExternalCredentialStoreClient.self] = ExternalCredentialStoreClient(
                secret: { _ in nil },
                save: { _, _ in },
                clear: { _ in }
            )
            $0[HomeModelCatalogClient.self] = HomeModelCatalogClient { _, _, _, _ in .init(models: expectedModels) }
        }
        store.exhaustivity = .off

        await store.send(.catalogLoaded(expectedModels)) { state in
            state.catalogModels = expectedModels
            state.selectedModelID = expectedModels[0].id
            state.sidePanel.selectedProviderID = state.selectedProviderID
        }

        #expect(backing.preference().modelID == expectedModels[0].id)
        #expect(store.state.selectedModelOption?.title == "Test A")
    }

    @Test("Provider change clears the old model and auto-selects from the new provider's catalog")
    func providerChangedAutoSelectsNewProviderModel() async {
        let known = HomeModelCatalog.models(for: ExternalAIProviderAPI.openRouter.id).first!
        let backing = ExternalInMemoryAIProviderPreferenceStore(
            preference: ExternalAIProviderPreference(
                providerID: ExternalAIProviderAPI.openRouter.id,
                modelID: known.id
            )
        )
        var initial = HomeFeature.State()
        initial.selectedProviderID = ExternalAIProviderAPI.openRouter.id
        initial.selectedModelID = known.id

        let store = TestStore(initialState: initial) {
            HomeFeature()
        } withDependencies: {
            $0[ExternalAIProviderPreferenceClient.self] = .wrap(backing)
            $0[ExternalCredentialStoreClient.self] = ExternalCredentialStoreClient(
                secret: { _ in nil },
                save: { _, _ in },
                clear: { _ in }
            )
            // Return empty live catalog so the provider-scoped fallback is used.
            $0[HomeModelCatalogClient.self] = HomeModelCatalogClient { _, _, _, _ in .init(models: []) }
        }
        store.exhaustivity = .off

        await store.send(.sidePanel(.delegate(.providerChanged(ExternalAIProviderAPI.openCode.id))))

        // The catalog loads (empty → falls back to OpenCode curated list),
        // and the first model is auto-selected because shouldAutoSelectDefaultModel
        // was set to true by the provider change.
        await store.receive(\.catalogLoaded)

        let expectedModel = ChatModel.curatedFallback(for: ExternalAIProviderAPI.openCode.id).first!
        #expect(store.state.selectedProviderID == ExternalAIProviderAPI.openCode.id)
        #expect(store.state.selectedModelID == expectedModel.id)
        #expect(backing.preference().modelID == expectedModel.id)
        #expect(backing.preference().providerID == ExternalAIProviderAPI.openCode.id)
    }

    @Test("Model popup auto-enables free-only for OpenRouter")
    func popupAutoEnablesFreeOnlyForOpenRouter() async {
        var initial = HomeFeature.State()
        initial.selectedProviderID = ExternalAIProviderAPI.openRouter.id
        initial.modelFilterFreeOnly = false

        let store = TestStore(initialState: initial) {
            HomeFeature()
        } withDependencies: {
            $0[ExternalAIProviderPreferenceClient.self] = .wrap(ExternalInMemoryAIProviderPreferenceStore())
            $0[ExternalCredentialStoreClient.self] = ExternalCredentialStoreClient(
                secret: { _ in nil },
                save: { _, _ in },
                clear: { _ in }
            )
            $0[HomeModelCatalogClient.self] = HomeModelCatalogClient { _, _, _, _ in .init(models: []) }
        }
        store.exhaustivity = .off

        await store.send(.modelPopupPresented(true))
        #expect(store.state.modelFilterFreeOnly == true)
    }

    @Test("Model popup does not auto-enable free-only for Command Code")
    func popupDoesNotAutoEnableFreeOnlyForCommandCode() async {
        var initial = HomeFeature.State()
        initial.selectedProviderID = ExternalAIProviderAPI.commandCode.id
        initial.modelFilterFreeOnly = false

        let store = TestStore(initialState: initial) {
            HomeFeature()
        } withDependencies: {
            $0[ExternalAIProviderPreferenceClient.self] = .wrap(ExternalInMemoryAIProviderPreferenceStore())
            $0[ExternalCredentialStoreClient.self] = ExternalCredentialStoreClient(
                secret: { _ in nil },
                save: { _, _ in },
                clear: { _ in }
            )
            $0[HomeModelCatalogClient.self] = HomeModelCatalogClient { _, _, _, _ in .init(models: []) }
        }
        store.exhaustivity = .off

        await store.send(.modelPopupPresented(true))
        #expect(store.state.modelFilterFreeOnly == false)
    }
}
