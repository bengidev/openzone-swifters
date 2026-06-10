import ComposableArchitecture
import Foundation

/// Drives the Settings sheet: entering, updating, and clearing the provider API
/// key. The key is persisted to the Keychain through `CredentialStoreClient`;
/// this reducer never holds the secret beyond the in-flight draft the user is
/// typing, and surfaces only whether a key is stored — never the value itself.
@Reducer
struct SidePanelSettingFeature {
    @Dependency(CredentialStoreClient.self) private var credentialStore
    @Dependency(AIProviderPreferenceClient.self) private var providerPreference

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

        /// The persisted reasoning effort tier, mirrored from the preference
        /// store. Edited here and from the composer; both write the same store.
        var reasoningModel: AIProviderReasoningModel = .high
        /// Whether the currently selected model supports reasoning. Seeded by
        /// the parent when presenting the sheet; the reasoning control is shown
        /// only when this is true, matching the composer-side gate.
        var modelSupportsReasoning = false
        /// The provider whose credentials are currently being managed. Mirrored
        /// from the parent so the key field targets the active provider, and
        /// updated when the user picks a different provider in this sheet.
        var selectedProviderID: String = AIProviderAPI.default.id

        var canSave: Bool {
            !draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        init(
            draftAPIKey: String = "",
            hasStoredKey: Bool = false,
            errorMessage: String? = nil,
            reasoningModel: AIProviderReasoningModel = .high,
            modelSupportsReasoning: Bool = false,
            selectedProviderID: String = AIProviderAPI.default.id
        ) {
            self.draftAPIKey = draftAPIKey
            self.hasStoredKey = hasStoredKey
            self.errorMessage = errorMessage
            self.reasoningModel = reasoningModel
            self.modelSupportsReasoning = modelSupportsReasoning
            self.selectedProviderID = selectedProviderID
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case saveTapped
        case clearTapped
        case reasoningModelSelected(AIProviderReasoningModel)
        case providerSelected(String)
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                let preference = providerPreference.preference()
                state.selectedProviderID = preference.providerID ?? AIProviderAPI.default.id
                state.hasStoredKey = credentialStore.secret(state.selectedProviderID) != nil
                state.reasoningModel = preference.reasoningModel
                return .none

            case .saveTapped:
                let key = state.draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { return .none }
                do {
                    try credentialStore.save(state.selectedProviderID, key)
                    state.draftAPIKey = ""
                    state.hasStoredKey = true
                    state.errorMessage = nil
                } catch {
                    state.errorMessage = "Could not save the key to the Keychain."
                }
                return .none

            case .clearTapped:
                do {
                    try credentialStore.clear(state.selectedProviderID)
                    state.draftAPIKey = ""
                    state.hasStoredKey = false
                    state.errorMessage = nil
                } catch {
                    state.errorMessage = "Could not remove the key from the Keychain."
                }
                return .none

            case let .reasoningModelSelected(level):
                // Persist to the shared single source of truth, then mirror it
                // into local state so the control reflects the change at once.
                providerPreference.setReasoningModel(level)
                state.reasoningModel = level
                return .none

            case let .providerSelected(id):
                providerPreference.setProviderID(id)
                state.selectedProviderID = id
                state.hasStoredKey = credentialStore.secret(id) != nil
                return .none
            }
        }
    }
}
