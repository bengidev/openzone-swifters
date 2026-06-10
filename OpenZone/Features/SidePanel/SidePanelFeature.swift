import ComposableArchitecture
import Foundation

/// Host reducer for the side panel. It composes the two sub-scopes that make up
/// the panel — the session browser (`SidePanelSessionFeature`) and the settings
/// sheet (`SidePanelSettingFeature`) — and owns their state so the panel is a
/// self-contained module rather than slices borrowed from Home.
///
/// The panel does not depend on Chat or Home. Cross-feature effects (opening a
/// conversation in the live chat, refreshing the send gate after a credential
/// change) are surfaced to the parent through `delegate` actions; the parent
/// translates them into chat/home state changes.
@Reducer
struct SidePanelFeature {
    @Dependency(CredentialStoreClient.self) private var credentialStore
    @Dependency(AIProviderPreferenceClient.self) private var providerPreference

    @ObservableState
    struct State: Equatable {
        /// The session browser scope (saved-conversation list + sidebar).
        var session = SidePanelSessionFeature.State()

        /// Presented settings sheet, when non-nil.
        @Presents var setting: SidePanelSettingFeature.State?

        /// Whether the parent's selected model supports reasoning. Mirrored from
        /// Home so the settings sheet can gate the reasoning control.
        var modelSupportsReasoning = false
        /// The currently selected provider id, mirrored from Home. Drives the
        /// settings sheet so the credential field targets the active provider.
        var selectedProviderID: String = AIProviderAPI.default.id

        /// Convenience mirror of the session scope's sidebar visibility, so the
        /// parent and views can read it without reaching into the sub-scope.
        var isSidebarVisible: Bool { session.isSidebarVisible }

        init(
            session: SidePanelSessionFeature.State = .init(),
            setting: SidePanelSettingFeature.State? = nil,
            modelSupportsReasoning: Bool = false,
            selectedProviderID: String = AIProviderAPI.default.id
        ) {
            self.session = session
            self.setting = setting
            self.modelSupportsReasoning = modelSupportsReasoning
            self.selectedProviderID = selectedProviderID
        }
    }

    enum Action: Equatable {
        case session(SidePanelSessionFeature.Action)
        case setting(PresentationAction<SidePanelSettingFeature.Action>)
        case settingsButtonTapped
        case delegate(Delegate)

        /// Outputs the parent (Home) acts on.
        @CasePathable
        enum Delegate: Equatable {
            /// Open a saved conversation in the live chat reducer.
            case openConversation(ChatConversation)
            /// The on-screen conversation was renamed.
            case activeConversationRenamed(id: UUID, title: String)
            /// The on-screen conversation was deleted; clear the active chat.
            case activeConversationDeleted(id: UUID)
            /// Stored credentials changed (saved or cleared); refresh the gate.
            case credentialsChanged
            /// The reasoning tier was changed from the settings sheet.
            case reasoningModelChanged
            /// The provider was changed from the settings sheet. The associated
            /// providerID is the newly active one.
            case providerChanged(String)
        }
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.session, action: \.session) {
            SidePanelSessionFeature()
        }
        Reduce { state, action in
            switch action {
            case .settingsButtonTapped, .session(.settingsButtonTapped):
                state.setting = SidePanelSettingFeature.State(
                    hasStoredKey: credentialStore.secret(state.selectedProviderID) != nil,
                    reasoningModel: providerPreference.preference().reasoningModel,
                    modelSupportsReasoning: state.modelSupportsReasoning,
                    selectedProviderID: state.selectedProviderID
                )
                return .none

            // Forward the session scope's delegate outputs up to the parent.
            case let .session(.delegate(.openConversation(conversation))):
                return .send(.delegate(.openConversation(conversation)))

            case let .session(.delegate(.activeConversationRenamed(id, title))):
                return .send(.delegate(.activeConversationRenamed(id: id, title: title)))

            case let .session(.delegate(.activeConversationDeleted(id))):
                return .send(.delegate(.activeConversationDeleted(id: id)))

            case .session:
                return .none

            // The settings sheet mutated stored credentials; tell the parent to
            // re-read the source of truth and refresh the send gate.
            case .setting(.presented(.saveTapped)),
                 .setting(.presented(.clearTapped)),
                 .setting(.dismiss):
                return .send(.delegate(.credentialsChanged))

            case .setting(.presented(.reasoningModelSelected)):
                return .send(.delegate(.reasoningModelChanged))

            case .setting(.presented(.providerSelected)):
                state.selectedProviderID = providerPreference.preference().providerID ?? AIProviderAPI.default.id
                return .send(.delegate(.providerChanged(state.selectedProviderID)))

            case .setting:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$setting, action: \.setting) {
            SidePanelSettingFeature()
        }
    }
}
