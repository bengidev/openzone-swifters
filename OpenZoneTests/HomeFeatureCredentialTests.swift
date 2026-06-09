import ComposableArchitecture
import Foundation
import Testing

@testable import OpenZone

@MainActor
@Suite("Home Credential Gating")
struct HomeFeatureCredentialTests {
    private func makeStore(
        backing: InMemoryCredentialStore
    ) -> TestStoreOf<HomeFeature> {
        TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.credentialStore = .wrap(backing)
        }
    }

    @Test("onAppear with no stored key leaves the send gate closed")
    func onAppearNoKeyClosesGate() async {
        let store = makeStore(backing: InMemoryCredentialStore())
        store.exhaustivity = .off

        await store.send(.onAppear)
        #expect(store.state.hasAPIKey == false)
    }

    @Test("onAppear with a stored key opens the send gate")
    func onAppearWithKeyOpensGate() async {
        let store = makeStore(backing: InMemoryCredentialStore(secret: "sk-existing"))
        store.exhaustivity = .off

        await store.send(.onAppear)
        #expect(store.state.hasAPIKey == true)
    }

    @Test("Tapping settings emits a delegate action")
    func settingsButtonEmitsDelegate() async {
        let store = makeStore(backing: InMemoryCredentialStore(secret: "sk-existing"))
        store.exhaustivity = .off

        await store.send(.settingsButtonTapped)
        await store.receive(\.delegate.openSettings)
    }

    @Test("credentialStoreChanged refreshes the send gate")
    func credentialStoreChangedRefreshesGate() async {
        let backing = InMemoryCredentialStore()
        let store = makeStore(backing: backing)
        store.exhaustivity = .off

        await store.send(.onAppear)
        #expect(store.state.hasAPIKey == false)

        try? backing.save(secret: "sk-new")
        await store.send(.credentialStoreChanged)
        #expect(store.state.hasAPIKey == true)
    }
}

@MainActor
@Suite("AppFeature Settings Integration")
struct AppFeatureSettingsTests {
    @Test("Home settings delegate presents the shell-owned sheet")
    func settingsDelegatePresentsSheet() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0[CredentialStoreClient.self] = .wrap(InMemoryCredentialStore(secret: "sk-existing"))
            $0[AIProviderPreferenceClient.self] = .wrap(InMemoryAIProviderPreferenceStore())
        }
        store.exhaustivity = .off

        await store.send(.home(.settingsButtonTapped))
        await store.receive(\.home.delegate.openSettings)
        #expect(store.state.settings != nil)
        #expect(store.state.settings?.hasStoredKey == true)
    }

    @Test("Saving a key in Settings refreshes the home send gate")
    func saveInSettingsOpensGate() async {
        let backing = InMemoryCredentialStore()
        var state = AppFeature.State()
        state.settings = SettingsFeature.State(draftAPIKey: "sk-new")
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0[CredentialStoreClient.self] = .wrap(backing)
            $0[AIProviderPreferenceClient.self] = .wrap(InMemoryAIProviderPreferenceStore())
        }
        store.exhaustivity = .off

        await store.send(.home(.onAppear))
        #expect(store.state.home.hasAPIKey == false)

        await store.send(.settings(.presented(.saveTapped)))
        await store.receive(\.home.credentialStoreChanged)
        #expect(backing.secret() == "sk-new")
        #expect(store.state.home.hasAPIKey == true)
    }
}
