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
        let store = InMemoryAIProviderPreferenceStore()
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
        #expect(AIProviderAPI.resolve(id: nil) == .default)
        #expect(AIProviderAPI.resolve(id: "does-not-exist") == .default)
        #expect(AIProviderAPI.resolve(id: AIProviderAPI.openRouter.id) == .openRouter)
    }

    // MARK: - Model catalog

    @Test("Model catalog resolves a known id and rejects an unknown one")
    func modelCatalogResolution() {
        let known = HomeModelCatalog.models(for: AIProviderAPI.openRouter.id).first!
        #expect(HomeModelCatalog.option(for: known.id, providerID: AIProviderAPI.openRouter.id) != nil)
        #expect(HomeModelCatalog.option(for: "ghost-model", providerID: AIProviderAPI.openRouter.id) == nil)
        #expect(HomeModelCatalog.option(for: nil, providerID: nil) == nil)
    }
}

/// Reducer-level send-gating on a selected model, isolated from the streaming
/// assertions in `ChatReasoningStreamingTests`.
@MainActor
@Suite("Chat Send Gating")
struct ChatSendGatingTests {

    private func makeStore(
        preference: AIProviderPreference
    ) -> TestStoreOf<ChatFeature> {
        TestStore(initialState: ChatFeature.State()) {
            ChatFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0[AIProviderPreferenceClient.self] = .wrap(
                InMemoryAIProviderPreferenceStore(preference: preference)
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
        let store = makeStore(preference: AIProviderPreference(providerID: "openrouter", modelID: nil))
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
            preference: AIProviderPreference(
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
        let backing = InMemoryAIProviderPreferenceStore()
        let credentialStore = InMemoryCredentialStore(secret: "sk-existing")
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0[AIProviderPreferenceClient.self] = .wrap(backing)
            $0[CredentialStoreClient.self] = CredentialStoreClient(
                secret: { _ in credentialStore.secret() },
                save: { _, secret in try credentialStore.save(secret: secret) },
                clear: { _ in try credentialStore.clear() }
            )
        }
        store.exhaustivity = .off

        #expect(store.state.hasSelectedModel == false)

        let model = HomeModelCatalog.models(for: AIProviderAPI.openRouter.id).first!
        await store.send(.composerModelSelected(model.id))

        #expect(backing.preference().modelID == model.id)
        #expect(backing.preference().providerID == AIProviderAPI.openRouter.id)
        #expect(store.state.selectedModelID == model.id)
        #expect(store.state.hasSelectedModel == true)
    }

    @Test("onAppear seeds the selection from the stored preference")
    func onAppearSeedsFromPreference() async {
        let known = HomeModelCatalog.models(for: AIProviderAPI.openRouter.id).first!
        let backing = InMemoryAIProviderPreferenceStore(
            preference: AIProviderPreference(providerID: AIProviderAPI.openRouter.id, modelID: known.id)
        )
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0[AIProviderPreferenceClient.self] = .wrap(backing)
            $0[CredentialStoreClient.self] = CredentialStoreClient(
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
}
