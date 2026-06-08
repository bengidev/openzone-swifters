import ComposableArchitecture
import Foundation

/// A provider model catalog cached with the moment it was fetched, so the
/// catalog client can decide whether the cache is fresh or stale on read.
nonisolated struct ModelCatalogCachePreference: Equatable, Sendable, Codable {
    /// Provider the cached models belong to.
    var providerID: String
    /// The models returned by the provider at `fetchedAt`.
    var models: [ChatModel]
    /// When the catalog was fetched, used for staleness checks.
    var fetchedAt: Date

    init(providerID: String, models: [ChatModel], fetchedAt: Date) {
        self.providerID = providerID
        self.models = models
        self.fetchedAt = fetchedAt
    }

    /// Whether the cache is older than `maxAge` relative to `now`.
    func isStale(maxAge: TimeInterval, now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) > maxAge
    }
}

// MARK: - Store abstraction

nonisolated protocol ModelCatalogCachePreferenceStore: Sendable {
    func cachedCatalog() -> ModelCatalogCachePreference?
    func setCachedCatalog(_ catalog: ModelCatalogCachePreference?)
}

// MARK: - UserDefaults adapter

nonisolated struct UserDefaultsModelCatalogCachePreferenceStore: ModelCatalogCachePreferenceStore {
    let suiteName: String?

    private enum Key {
        static let cachedCatalog = "openzone.provider.cachedModelCatalog"
    }

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    func cachedCatalog() -> ModelCatalogCachePreference? {
        guard let data = defaults.data(forKey: Key.cachedCatalog) else { return nil }
        return try? JSONDecoder().decode(ModelCatalogCachePreference.self, from: data)
    }

    func setCachedCatalog(_ catalog: ModelCatalogCachePreference?) {
        guard let catalog, let data = try? JSONEncoder().encode(catalog) else {
            defaults.removeObject(forKey: Key.cachedCatalog)
            return
        }
        defaults.set(data, forKey: Key.cachedCatalog)
    }
}

// MARK: - In-memory test double

nonisolated final class InMemoryModelCatalogCachePreferenceStore: ModelCatalogCachePreferenceStore,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var storedCatalog: ModelCatalogCachePreference?

    init(cachedCatalog: ModelCatalogCachePreference? = nil) {
        self.storedCatalog = cachedCatalog
    }

    func cachedCatalog() -> ModelCatalogCachePreference? {
        lock.lock()
        defer { lock.unlock() }
        return storedCatalog
    }

    func setCachedCatalog(_ catalog: ModelCatalogCachePreference?) {
        lock.lock()
        defer { lock.unlock() }
        storedCatalog = catalog
    }
}

// MARK: - TCA dependency

nonisolated struct ModelCatalogCachePreferenceClient: Sendable {
    var cachedCatalog: @Sendable () -> ModelCatalogCachePreference?
    var setCachedCatalog: @Sendable (ModelCatalogCachePreference?) -> Void
}

extension ModelCatalogCachePreferenceClient {
    static func wrap(_ store: some ModelCatalogCachePreferenceStore) -> ModelCatalogCachePreferenceClient {
        ModelCatalogCachePreferenceClient(
            cachedCatalog: { store.cachedCatalog() },
            setCachedCatalog: { store.setCachedCatalog($0) }
        )
    }
}

extension ModelCatalogCachePreferenceClient: DependencyKey {
    static let liveValue = ModelCatalogCachePreferenceClient.wrap(
        UserDefaultsModelCatalogCachePreferenceStore()
    )
    static let testValue = ModelCatalogCachePreferenceClient.wrap(
        InMemoryModelCatalogCachePreferenceStore()
    )
    static let previewValue = ModelCatalogCachePreferenceClient.wrap(
        InMemoryModelCatalogCachePreferenceStore()
    )
}

extension DependencyValues {
    var modelCatalogCachePreference: ModelCatalogCachePreferenceClient {
        get { self[ModelCatalogCachePreferenceClient.self] }
        set { self[ModelCatalogCachePreferenceClient.self] = newValue }
    }
}
