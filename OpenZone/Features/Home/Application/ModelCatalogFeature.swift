import ComposableArchitecture
import Foundation

/// Owns model catalog loading, popup presentation, search debounce, and selection.
@Reducer
struct ModelCatalogFeature {
    @Dependency(CredentialStoreClient.self) private var credentialStore
    @Dependency(AIProviderPreferenceClient.self) private var providerPreference
    @Dependency(ModelCatalogClient.self) private var modelCatalog
    @Dependency(ModelCatalogCachePreferenceClient.self) private var modelCatalogCachePreference
    @Dependency(\.continuousClock) private var clock

    private nonisolated enum CancelID: Hashable, Sendable { case searchDebounce }

    @ObservableState
    struct State: Equatable {
        /// The selected provider id, mirrored from the preference store.
        var selectedProviderID: String = AIProviderAPI.default.id
        /// The selected dynamic model id, mirrored from the preference store.
        var selectedModelID: String?

        /// The live catalog loaded by `ModelCatalogClient`.
        var catalogModels: [ChatModel] = []

        /// Whether the model popup is currently presented.
        var isModelPopupPresented = false

        var modelSearchQuery: String = ""
        var appliedSearchQuery: String = ""
        var modelFilterFreeOnly: Bool = false

        var selectedModelOption: ChatModelOption? {
            guard let selectedModelID else { return nil }
            if let live = catalogModels.first(where: { $0.id == selectedModelID }) {
                return ChatModelOption(model: live)
            }
            return ChatModelCatalog.option(for: selectedModelID, providerID: selectedProviderID)
        }

        var availableModels: [ChatModelOption] {
            let source = catalogModels.isEmpty ? ChatModel.curatedFallback : catalogModels
            return source.map { ChatModelOption(model: $0) }
        }

        var filteredModels: [ChatModelOption] {
            var result = availableModels
            if modelFilterFreeOnly {
                result = result.filter(\.isFree)
            }
            let query = appliedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return result }
            return result.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || $0.id.localizedCaseInsensitiveContains(query)
            }
        }

        var hasSelectedModel: Bool {
            selectedModelOption != nil
        }
    }

    enum Action: Equatable {
        case loadCatalog
        case catalogLoaded([ChatModel])
        case modelSelected(String)
        case modelPopupPresented(Bool)
        case modelSearchQueryChanged(String)
        case searchQueryDebounced(String)
        case modelFilterFreeOnlyChanged(Bool)
        case preferenceSynced(providerID: String, modelID: String?, reasoningModel: AIProviderReasoningModel)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .loadCatalog:
                let preference = providerPreference.preference()
                state.selectedProviderID = preference.providerID ?? AIProviderAPI.default.id
                state.selectedModelID = preference.modelID

                let provider = AIProviderAPI.resolve(id: state.selectedProviderID)
                let secret = credentialStore.secret()
                let cachePreference = modelCatalogCachePreference
                let catalogClient = modelCatalog
                return .run { send in
                    let models = await catalogClient.listModels(provider, secret, cachePreference, .shared)
                    await send(.catalogLoaded(models))
                }

            case let .catalogLoaded(models):
                state.catalogModels = models
                return .none

            case let .modelSelected(modelID):
                providerPreference.setProviderID(state.selectedProviderID)
                providerPreference.setModelID(modelID)
                state.selectedModelID = modelID
                state.isModelPopupPresented = false
                return .none

            case let .modelPopupPresented(isPresented):
                state.isModelPopupPresented = isPresented
                if isPresented {
                    state.modelSearchQuery = ""
                    state.appliedSearchQuery = ""
                    state.modelFilterFreeOnly = false
                }
                return .none

            case let .modelSearchQueryChanged(query):
                state.modelSearchQuery = query
                return .run { [clock] send in
                    try await clock.sleep(for: .milliseconds(300))
                    await send(.searchQueryDebounced(query))
                }
                .cancellable(id: CancelID.searchDebounce, cancelInFlight: true)

            case let .searchQueryDebounced(query):
                state.appliedSearchQuery = query
                return .none

            case let .modelFilterFreeOnlyChanged(freeOnly):
                state.modelFilterFreeOnly = freeOnly
                return .none

            case let .preferenceSynced(providerID, modelID, _):
                state.selectedProviderID = providerID
                state.selectedModelID = modelID
                return .none
            }
        }
    }
}
