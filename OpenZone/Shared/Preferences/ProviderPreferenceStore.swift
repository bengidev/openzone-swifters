import ComposableArchitecture
import Foundation

/// The persisted selection of provider and model.
///
/// Pure value data: a provider id (matching a `ChatProvider` descriptor in the
/// catalog) plus a dynamic model id string. The model id is intentionally a
/// free-form string — model identity is no longer a closed enum, so any model
/// the provider exposes can be selected without a code change.
nonisolated struct ProviderPreference: Equatable, Sendable {
    /// Stable provider identifier (e.g. `"openrouter"`). `nil` until chosen.
    var providerID: String?
    /// Dynamic model identifier (e.g. `"meta-llama/llama-3.3-70b-instruct:free"`).
    /// `nil` until a model is selected; send is gated until this is set.
    var modelID: String?

    init(providerID: String? = nil, modelID: String? = nil) {
        self.providerID = providerID
        self.modelID = modelID
    }
}

// MARK: - Store abstraction

/// A minimal store for the provider/model preference.
///
/// This is the single source of truth for which provider and model the app
/// sends with. The live adapter persists to `UserDefaults`; an in-memory double
/// backs tests and previews. It names no chat domain types and is feature
/// neutral.
///
/// The preference is read lazily (`preference()`), never cached by callers, so
/// a change made in one surface takes effect on the next read with no stale
/// value — mirroring how `CredentialStore` resolves the secret per request.
nonisolated protocol ProviderPreferenceStore: Sendable {
    /// The current stored preference.
    func preference() -> ProviderPreference
    /// Persists the selected provider id.
    func setProviderID(_ providerID: String?)
    /// Persists the selected model id.
    func setModelID(_ modelID: String?)
}

// MARK: - UserDefaults adapter

/// Live `ProviderPreferenceStore` backed by `UserDefaults`.
///
/// State is keyed by stable string keys under a shared suite, so every instance
/// configured with the same suite observes the same values. That is how the
/// composer (which writes the selection) and the chat reducer (which reads it
/// at send time) stay in sync without sharing an object: they address the same
/// defaults keys.
nonisolated struct UserDefaultsProviderPreferenceStore: ProviderPreferenceStore {
    /// Suite name for the backing `UserDefaults`, or `nil` for `.standard`.
    /// Storing the name (a `Sendable` `String`) rather than the `UserDefaults`
    /// instance keeps this struct `Sendable` with no unsafe opt-out: the
    /// thread-safe defaults object is resolved fresh on each access.
    let suiteName: String?

    private enum Key {
        static let providerID = "openzone.provider.selectedProviderID"
        static let modelID = "openzone.provider.selectedModelID"
    }

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    func preference() -> ProviderPreference {
        ProviderPreference(
            providerID: nonEmpty(defaults.string(forKey: Key.providerID)),
            modelID: nonEmpty(defaults.string(forKey: Key.modelID))
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

    /// Normalizes empty/whitespace strings to `nil` so a blank stored value is
    /// never treated as a real selection.
    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - In-memory test double

/// Thread-safe in-memory `ProviderPreferenceStore` for tests and previews.
/// Never touches `UserDefaults`, so test runs are hermetic and leave no state
/// behind.
nonisolated final class InMemoryProviderPreferenceStore: ProviderPreferenceStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: ProviderPreference

    init(preference: ProviderPreference = ProviderPreference()) {
        self.stored = preference
    }

    func preference() -> ProviderPreference {
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
}

// MARK: - TCA dependency

/// Value-typed dependency surface over a `ProviderPreferenceStore`, mirroring
/// the struct-of-closures style used by `CredentialStoreClient`. The reducer
/// talks to this; the concrete adapter behind it is chosen by the dependency
/// environment.
nonisolated struct ProviderPreferenceClient: Sendable {
    var preference: @Sendable () -> ProviderPreference
    var setProviderID: @Sendable (String?) -> Void
    var setModelID: @Sendable (String?) -> Void
}

extension ProviderPreferenceClient {
    static func wrap(_ store: some ProviderPreferenceStore) -> ProviderPreferenceClient {
        ProviderPreferenceClient(
            preference: { store.preference() },
            setProviderID: { store.setProviderID($0) },
            setModelID: { store.setModelID($0) }
        )
    }
}

extension ProviderPreferenceClient: DependencyKey {
    /// Live path persists the selection to `UserDefaults`.
    static let liveValue = ProviderPreferenceClient.wrap(UserDefaultsProviderPreferenceStore())
    /// Test/preview paths keep everything in memory so they never touch defaults.
    static let testValue = ProviderPreferenceClient.wrap(InMemoryProviderPreferenceStore())
    static let previewValue = ProviderPreferenceClient.wrap(InMemoryProviderPreferenceStore())
}

extension DependencyValues {
    var providerPreference: ProviderPreferenceClient {
        get { self[ProviderPreferenceClient.self] }
        set { self[ProviderPreferenceClient.self] = newValue }
    }
}
