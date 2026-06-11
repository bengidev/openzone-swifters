import ComposableArchitecture
import Foundation

/// The persisted selection of provider and model.
///
/// Pure value data: a provider id (matching a `AIProviderAPI` descriptor in the
/// catalog) plus a dynamic model id string. The model id is intentionally a
/// free-form string — model identity is no longer a closed enum, so any model
/// the provider exposes can be selected without a code change.
nonisolated struct AIProviderPreference: Equatable, Sendable {
    /// Stable provider identifier (e.g. `"openrouter"`). `nil` until chosen.
    var providerID: String?
    /// Dynamic model identifier (e.g. `"meta-llama/llama-3.3-70b-instruct:free"`).
    /// `nil` until a model is selected; send is gated until this is set.
    var modelID: String?
    /// Persisted reasoning effort tier. Defaults to `.high` so a capable model
    /// reasons by default; persists across launches once the user changes it.
    var reasoningModel: AIProviderReasoningModel

    init(
        providerID: String? = nil,
        modelID: String? = nil,
        reasoningModel: AIProviderReasoningModel = .high
    ) {
        self.providerID = providerID
        self.modelID = modelID
        self.reasoningModel = reasoningModel
    }
}

// MARK: - Store abstraction

/// A minimal store for the provider/model preference.
///
/// This is the single source of truth for which provider and model the app
/// sends with. The live adapter persists to `UserDefaults`; an in-memory double
/// backs tests and previews.
///
/// The preference is read lazily (`preference()`), never cached by callers, so
/// a change made in one surface takes effect on the next read with no stale
/// value — mirroring how `CredentialStore` resolves the secret per request.
nonisolated protocol AIProviderPreferenceStore: Sendable {
    /// The current stored preference.
    func preference() -> AIProviderPreference
    /// Persists the selected provider id.
    func setProviderID(_ providerID: String?)
    /// Persists the selected model id.
    func setModelID(_ modelID: String?)
    /// Persists the selected reasoning effort tier.
    func setReasoningModel(_ model: AIProviderReasoningModel)
}

// MARK: - UserDefaults adapter

/// Live `AIProviderPreferenceStore` backed by `UserDefaults`.
nonisolated struct UserDefaultsAIProviderPreferenceStore: AIProviderPreferenceStore {
    let suiteName: String?

    private enum Key {
        static let providerID = "openzone.provider.selectedProviderID"
        static let modelID = "openzone.provider.selectedModelID"
        static let reasoningLevel = "openzone.provider.reasoningLevel"
    }

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    func preference() -> AIProviderPreference {
        AIProviderPreference(
            providerID: nonEmpty(defaults.string(forKey: Key.providerID)),
            modelID: nonEmpty(defaults.string(forKey: Key.modelID)),
            reasoningModel: AIProviderReasoningModel(rawValue: defaults.string(forKey: Key.reasoningLevel) ?? "")
                ?? .high
        )
    }

    func setProviderID(_ providerID: String?) {
        if let providerID = nonEmpty(providerID) {
            defaults.set(providerID, forKey: Key.providerID)
        } else {
            defaults.removeObject(forKey: Key.providerID)
        }
    }

    func setModelID(_ modelID: String?) {
        if let modelID = nonEmpty(modelID) {
            defaults.set(modelID, forKey: Key.modelID)
        } else {
            defaults.removeObject(forKey: Key.modelID)
        }
    }

    func setReasoningModel(_ model: AIProviderReasoningModel) {
        defaults.set(model.rawValue, forKey: Key.reasoningLevel)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - In-memory test double

nonisolated final class InMemoryAIProviderPreferenceStore: AIProviderPreferenceStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: AIProviderPreference

    init(preference: AIProviderPreference = AIProviderPreference()) {
        self.stored = preference
    }

    func preference() -> AIProviderPreference {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func setProviderID(_ providerID: String?) {
        lock.lock()
        defer { lock.unlock() }
        stored.providerID = providerID
    }

    func setModelID(_ modelID: String?) {
        lock.lock()
        defer { lock.unlock() }
        stored.modelID = modelID
    }

    func setReasoningModel(_ model: AIProviderReasoningModel) {
        lock.lock()
        defer { lock.unlock() }
        stored.reasoningModel = model
    }
}

// MARK: - TCA dependency

nonisolated struct AIProviderPreferenceClient: Sendable {
    var preference: @Sendable () -> AIProviderPreference
    var setProviderID: @Sendable (String?) -> Void
    var setModelID: @Sendable (String?) -> Void
    var setReasoningModel: @Sendable (AIProviderReasoningModel) -> Void
}

extension AIProviderPreferenceClient {
    static func wrap(_ store: some AIProviderPreferenceStore) -> AIProviderPreferenceClient {
        AIProviderPreferenceClient(
            preference: { store.preference() },
            setProviderID: { store.setProviderID($0) },
            setModelID: { store.setModelID($0) },
            setReasoningModel: { store.setReasoningModel($0) }
        )
    }
}

extension AIProviderPreferenceClient: DependencyKey {
    static let liveValue = AIProviderPreferenceClient.wrap(UserDefaultsAIProviderPreferenceStore())
    static let testValue = AIProviderPreferenceClient.wrap(InMemoryAIProviderPreferenceStore())
    static let previewValue = AIProviderPreferenceClient.wrap(InMemoryAIProviderPreferenceStore())
}

extension DependencyValues {
    var providerPreference: AIProviderPreferenceClient {
        get { self[AIProviderPreferenceClient.self] }
        set { self[AIProviderPreferenceClient.self] = newValue }
    }
}
