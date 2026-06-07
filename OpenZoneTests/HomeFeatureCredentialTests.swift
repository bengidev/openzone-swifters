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

    @Test("Tapping settings presents the sheet seeded with stored state")
    func settingsButtonPresentsSheet() async {
        let store = makeStore(backing: InMemoryCredentialStore(secret: "sk-existing"))
        store.exhaustivity = .off

        await store.send(.settingsButtonTapped)
        #expect(store.state.settings != nil)
        #expect(store.state.settings?.hasStoredKey == true)
    }

    @Test("Saving a key in the sheet opens the send gate")
    func saveInSheetOpensGate() async {
        let backing = InMemoryCredentialStore()
        let store = TestStore(
            initialState: HomeFeature.State(
                settings: SettingsFeature.State(draftAPIKey: "sk-new")
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0[CredentialStoreClient.self] = .wrap(backing)
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        #expect(store.state.hasAPIKey == false)

        // The user saves from the open sheet; the parent re-reads the credential
        // source and opens the send gate.
        await store.send(.settings(.presented(.saveTapped)))

        #expect(backing.secret() == "sk-new")
        #expect(store.state.hasAPIKey == true)
    }

    @Test("Clearing the key in the sheet closes the send gate")
    func clearInSheetClosesGate() async {
        let backing = InMemoryCredentialStore(secret: "sk-existing")
        let store = makeStore(backing: backing)
        store.exhaustivity = .off

        await store.send(.onAppear)
        #expect(store.state.hasAPIKey == true)

        await store.send(.settingsButtonTapped)
        await store.send(.settings(.presented(.clearTapped)))

        #expect(backing.secret() == nil)
        #expect(store.state.hasAPIKey == false)
    }
}
