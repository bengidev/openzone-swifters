import ComposableArchitecture
import Foundation
import Testing

@testable import OpenZone

@MainActor
@Suite("Settings Feature")
struct SettingsFeatureTests {
    /// Builds a Settings store over an in-memory credential store so the test is
    /// hermetic and the same backing store can be asserted against directly.
    private func makeStore(
        initialState: SettingsFeature.State = .init(),
        backing: InMemoryCredentialStore
    ) -> TestStoreOf<SettingsFeature> {
        TestStore(initialState: initialState) {
            SettingsFeature()
        } withDependencies: {
            $0[CredentialStoreClient.self] = .wrap(backing)
        }
    }

    @Test("onAppear reflects an already-stored key")
    func onAppearReflectsStoredKey() async {
        let backing = InMemoryCredentialStore(secret: "sk-existing")
        let store = makeStore(backing: backing)

        await store.send(.onAppear) {
            $0.hasStoredKey = true
        }
    }

    @Test("Saving a key persists it and flips hasStoredKey")
    func savePersistsKey() async {
        let backing = InMemoryCredentialStore()
        let store = makeStore(
            initialState: SettingsFeature.State(draftAPIKey: "sk-new"),
            backing: backing
        )

        await store.send(.saveTapped) {
            $0.draftAPIKey = ""
            $0.hasStoredKey = true
        }
        #expect(backing.secret() == "sk-new")
    }

    @Test("Saving trims surrounding whitespace")
    func saveTrimsWhitespace() async {
        let backing = InMemoryCredentialStore()
        let store = makeStore(
            initialState: SettingsFeature.State(draftAPIKey: "  sk-trim  "),
            backing: backing
        )

        await store.send(.saveTapped) {
            $0.draftAPIKey = ""
            $0.hasStoredKey = true
        }
        #expect(backing.secret() == "sk-trim")
    }

    @Test("Saving a blank draft is a no-op")
    func saveBlankIsNoOp() async {
        let backing = InMemoryCredentialStore()
        let store = makeStore(
            initialState: SettingsFeature.State(draftAPIKey: "   "),
            backing: backing
        )

        // canSave is false for blank input, so no state change is expected.
        await store.send(.saveTapped)
        #expect(backing.secret() == nil)
    }

    @Test("Clearing removes the stored key and resets state")
    func clearRemovesKey() async {
        let backing = InMemoryCredentialStore(secret: "sk-existing")
        let store = makeStore(backing: backing)

        await store.send(.onAppear) {
            $0.hasStoredKey = true
        }
        await store.send(.clearTapped) {
            $0.hasStoredKey = false
        }
        #expect(backing.secret() == nil)
    }

    @Test("canSave is false for blank and true for non-blank drafts")
    func canSaveReflectsDraft() {
        var state = SettingsFeature.State()
        #expect(state.canSave == false)
        state.draftAPIKey = "   "
        #expect(state.canSave == false)
        state.draftAPIKey = "sk-x"
        #expect(state.canSave == true)
    }
}
