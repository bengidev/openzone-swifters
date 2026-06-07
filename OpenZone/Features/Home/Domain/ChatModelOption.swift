import Foundation

/// A selectable chat model, presented in the composer.
///
/// Model identity is the dynamic string `id` (e.g.
/// `"meta-llama/llama-3.3-70b-instruct:free"`), NOT a closed enum — any model a
/// provider exposes can be offered by appending a value here, with no change to
/// the request, reducer, or client. `title` and `availableSpeedModes` are
/// presentation metadata only; the `id` is what the preference store persists
/// and the request carries.
nonisolated struct ChatModelOption: Equatable, Identifiable, Sendable {
    /// Dynamic model identifier sent on the wire and persisted as the selection.
    let id: String
    /// Human-facing label shown in the model chip and menu.
    let title: String
    /// Speed modes offered for this model in the composer rail.
    let availableSpeedModes: [HomeComposerSpeedMode]

    init(
        id: String,
        title: String,
        availableSpeedModes: [HomeComposerSpeedMode] = HomeComposerSpeedMode.allCases
    ) {
        self.id = id
        self.title = title
        self.availableSpeedModes = availableSpeedModes
    }
}

/// The catalog of selectable models, scoped by provider id.
///
/// This is presentation data: the set of models the composer offers for a given
/// provider. It deliberately holds no model identity of its own beyond the
/// dynamic string ids — retiring the old `HomeComposerModelOption` enum as the
/// identity. A model unknown to the catalog (e.g. a persisted id that was later
/// removed) resolves to `nil`, leaving the send gate closed until the user
/// picks a known model.
enum ChatModelCatalog {
    /// Models offered for the given provider id. Unknown/absent providers fall
    /// back to the default provider's catalog.
    static func models(for providerID: String?) -> [ChatModelOption] {
        switch providerID ?? ChatProvider.default.id {
        case ChatProvider.openRouter.id:
            return openRouterModels
        default:
            return openRouterModels
        }
    }

    /// Resolves a stored model id to its presentation option for the provider,
    /// or `nil` when the id is absent or not in the catalog.
    static func option(for modelID: String?, providerID: String?) -> ChatModelOption? {
        guard let modelID else { return nil }
        return models(for: providerID).first { $0.id == modelID }
    }

    private static let openRouterModels: [ChatModelOption] = [
        ChatModelOption(
            id: "meta-llama/llama-3.3-70b-instruct:free",
            title: "Llama 3.3 70B"
        ),
        ChatModelOption(
            id: "deepseek/deepseek-r1:free",
            title: "DeepSeek R1"
        ),
        ChatModelOption(
            id: "google/gemini-2.0-flash-exp:free",
            title: "Gemini 2.0 Flash"
        )
    ]
}
