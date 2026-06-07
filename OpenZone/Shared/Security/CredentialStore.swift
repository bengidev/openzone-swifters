import ComposableArchitecture
import Foundation
import Security

/// A minimal secure store for a single provider secret.
///
/// This is the Shared-layer abstraction behind which the live Keychain adapter
/// and an in-memory test double both sit. It names no chat domain types and is
/// feature-neutral: it stores, reads, and clears one opaque secret string.
///
/// The secret is read lazily (`secret()`), never cached by callers, so editing
/// the key takes effect on the next read with no stale value.
///
/// Declared `nonisolated` so the live adapter can be read at request time from
/// the streaming client's `nonisolated`/`@Sendable` credential closure, even
/// though the app target's default actor isolation is `MainActor`.
nonisolated protocol CredentialStore: Sendable {
    /// The currently stored secret, or `nil` when none is stored.
    func secret() -> String?
    /// Persists `secret`, replacing any existing value.
    func save(secret: String) throws
    /// Removes any stored secret. Removing an absent secret is not an error.
    func clear() throws
}

// MARK: - Keychain adapter

/// A typed wrapper over a Keychain `OSStatus` failure.
nonisolated struct KeychainError: Error, Equatable {
    let status: OSStatus
}

/// Live `CredentialStore` backed by a Keychain generic-password item.
///
/// State is process-global and keyed by `service` + `account`, so every
/// instance configured with the same pair shares the same item. That is how the
/// Settings surface (which writes) and the streaming client's credential
/// provider (which reads at request time) stay in sync without sharing an
/// object: they address the same Keychain row.
///
/// The item is stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
/// so it is never written to iCloud Keychain or device backups.
nonisolated struct KeychainCredentialStore: CredentialStore {
    let service: String
    let account: String

    init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    func secret() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = unsafe SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }
        return value
    }

    func save(secret: String) throws {
        let data = Data(secret.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        // Try an in-place update first so we never duplicate the item.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }

        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
            return
        }

        throw KeychainError(status: updateStatus)
    }

    func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}

extension KeychainCredentialStore {
    /// The shared item holding the OpenRouter API key for this app. The Settings
    /// surface and the streaming client both address this exact row.
    static let openRouter = KeychainCredentialStore(
        service: "io.github.bengidev.OpenZone",
        account: "openrouter-api-key"
    )
}

// MARK: - In-memory test double

/// Thread-safe in-memory `CredentialStore` for tests and previews. Never touches
/// the Keychain, so test runs are hermetic and leave no device state behind.
nonisolated final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storedSecret: String?

    init(secret: String? = nil) {
        self.storedSecret = secret
    }

    func secret() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let storedSecret, !storedSecret.isEmpty else { return nil }
        return storedSecret
    }

    func save(secret: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storedSecret = secret
    }

    func clear() throws {
        lock.lock()
        defer { lock.unlock() }
        storedSecret = nil
    }
}

// MARK: - TCA dependency

/// Value-typed dependency surface over a `CredentialStore`, mirroring the
/// struct-of-closures style used by `ChatAPIClient`. The reducer talks to this;
/// the concrete adapter behind it is chosen by the dependency environment.
nonisolated struct CredentialStoreClient: Sendable {
    var secret: @Sendable () -> String?
    var save: @Sendable (String) throws -> Void
    var clear: @Sendable () throws -> Void
}

extension CredentialStoreClient {
    static func wrap(_ store: some CredentialStore) -> CredentialStoreClient {
        CredentialStoreClient(
            secret: { store.secret() },
            save: { try store.save(secret: $0) },
            clear: { try store.clear() }
        )
    }
}

extension CredentialStoreClient: DependencyKey {
    /// Live path persists to the Keychain generic-password item.
    static let liveValue = CredentialStoreClient.wrap(KeychainCredentialStore.openRouter)
    /// Test/preview paths keep everything in memory so they never touch the Keychain.
    static let testValue = CredentialStoreClient.wrap(InMemoryCredentialStore())
    static let previewValue = CredentialStoreClient.wrap(InMemoryCredentialStore())
}

extension DependencyValues {
    var credentialStore: CredentialStoreClient {
        get { self[CredentialStoreClient.self] }
        set { self[CredentialStoreClient.self] = newValue }
    }
}
