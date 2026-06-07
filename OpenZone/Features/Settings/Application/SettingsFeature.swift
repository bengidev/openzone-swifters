import ComposableArchitecture
import Foundation

/// Drives the Settings sheet: entering, updating, and clearing the provider API
/// key. The key is persisted to the Keychain through `CredentialStoreClient`;
/// this reducer never holds the secret beyond the in-flight draft the user is
/// typing, and surfaces only whether a key is stored — never the value itself.
@Reducer
struct SettingsFeature {
    @Dependency(CredentialStoreClient.self) private var credentialStore

    @ObservableState
    struct State: Equatable, Sendable {
        /// The in-progress value bound to the secure field. Cleared after a
        /// successful save so the secret does not linger in feature state.
        var draftAPIKey = ""
        /// Whether a key is currently stored. Drives the "saved" affordance and
        /// the parent send-gate.
        var hasStoredKey = false
        /// Transient error surfaced when a Keychain write fails.
        var errorMessage: String?

        var canSave: Bool {
            !draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case saveTapped
        case clearTapped
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                state.hasStoredKey = credentialStore.secret() != nil
                return .none

            case .saveTapped:
                let key = state.draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { return .none }
                do {
                    try credentialStore.save(key)
                    state.draftAPIKey = ""
                    state.hasStoredKey = true
                    state.errorMessage = nil
                } catch {
                    state.errorMessage = "Could not save the key to the Keychain."
                }
                return .none

            case .clearTapped:
                do {
                    try credentialStore.clear()
                    state.draftAPIKey = ""
                    state.hasStoredKey = false
                    state.errorMessage = nil
                } catch {
                    state.errorMessage = "Could not remove the key from the Keychain."
                }
                return .none
            }
        }
    }
}
