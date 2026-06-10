import Foundation

/// A selectable chat model as presented in the composer — a thin presentation
/// wrapper over the shared `ChatModel` value type.
///
/// Model identity is the wrapped model's string `id`; `title` mirrors its
/// `displayName`. `availableSpeedModes` is composer-only presentation metadata.
/// The `id` is what the preference store persists and the request carries.
nonisolated struct HomeModelOption: Equatable, Identifiable, Sendable {
    /// The underlying shared model value (id, free flag, context length, reasoning).
    let model: ChatModel
    /// Speed modes offered for this model in the composer rail.
    let availableSpeedModes: [HomeComposerSpeedMode]

    var id: String { model.id }
    var title: String { model.displayName }
    var isFree: Bool { model.isFree }
    var contextLength: Int? { model.contextLength }
    var supportsReasoning: Bool { model.supportsReasoning }

    init(
        model: ChatModel,
        availableSpeedModes: [HomeComposerSpeedMode] = HomeComposerSpeedMode.allCases
    ) {
        self.model = model
        self.availableSpeedModes = availableSpeedModes
    }

    /// Convenience initializer kept for call-site compatibility with code and
    /// tests that built options from id/title before the `ChatModel` wrapper.
    init(
        id: String,
        title: String,
        availableSpeedModes: [HomeComposerSpeedMode] = HomeComposerSpeedMode.allCases
    ) {
        self.model = ChatModel(id: id, displayName: title)
        self.availableSpeedModes = availableSpeedModes
    }
}

/// The curated fallback catalog, scoped by provider id.
///
/// This is the always-available presentation data used before a live catalog
/// is fetched (no key yet, offline, or first launch). The live catalog flows
/// through `HomeModelCatalogClient` and is held in feature state; this type only
/// provides the never-empty fallback and stale-id resolution.
enum HomeModelCatalog {
    /// Curated fallback models offered for the given provider id. Unknown/absent
    /// providers fall back to the default provider's list. Sourced from the
    /// shared `ChatModel.curatedFallback` so there is one fallback definition.
    static func models(for providerID: String?) -> [HomeModelOption] {
        switch providerID ?? AIProviderAPI.default.id {
        case AIProviderAPI.openRouter.id:
            return ChatModel.curatedFallback.map { HomeModelOption(model: $0) }
        default:
            return ChatModel.curatedFallback.map { HomeModelOption(model: $0) }
        }
    }

    /// Resolves a stored model id to its presentation option for the provider,
    /// or `nil` when the id is absent or not in the fallback catalog.
    static func option(for modelID: String?, providerID: String?) -> HomeModelOption? {
        guard let modelID else { return nil }
        return models(for: providerID).first { $0.id == modelID }
    }

    /// Humanizes a wire model id for display when the catalog no longer lists it.
    static func displayTitle(for modelID: String) -> String {
        let leaf = modelID.split(separator: "/").last.map(String.init) ?? modelID
        let withoutFreeSuffix = leaf.replacingOccurrences(of: ":free", with: "")
        return withoutFreeSuffix
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }
}
