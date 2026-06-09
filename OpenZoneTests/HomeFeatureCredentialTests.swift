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
        #expect(store.state.sidePanel.setting != nil)
        #expect(store.state.sidePanel.setting?.hasStoredKey == true)
    }

    @Test("Saving a key in the sheet opens the send gate")
    func saveInSheetOpensGate() async {
        let backing = InMemoryCredentialStore()
        let store = TestStore(
            initialState: HomeFeature.State(
                sidePanel: SidePanelFeature.State(
                    setting: SidePanelSettingFeature.State(draftAPIKey: "sk-new")
                )
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0[CredentialStoreClient.self] = .wrap(backing)
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        #expect(store.state.hasAPIKey == false)

        // The user saves from the open sheet; the panel forwards a delegate and
        // the parent re-reads the credential source, opening the send gate.
        await store.send(.sidePanel(.setting(.presented(.saveTapped))))
        await store.receive(\.sidePanel.delegate.credentialsChanged)

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
        await store.send(.sidePanel(.setting(.presented(.clearTapped))))
        await store.receive(\.sidePanel.delegate.credentialsChanged)

        #expect(backing.secret() == nil)
        #expect(store.state.hasAPIKey == false)
    }
}
