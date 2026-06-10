import Foundation
import Testing

@testable import OpenZone

/// Tests for the credential store abstraction. These exercise the in-memory
/// double and the `CredentialStoreClient` value wrapper, which are hermetic.
/// The live `KeychainCredentialStore` is intentionally not exercised here — it
/// touches the system Keychain, which is unavailable/unreliable under unit
/// tests; its behavior is covered by the abstraction it conforms to.
struct CredentialStoreTests {
    @Test("In-memory store returns nil when empty")
    func emptyReturnsNil() {
        let store = InMemoryCredentialStore()
        #expect(store.secret() == nil)
    }

    @Test("In-memory store round-trips a saved secret")
    func saveRoundTrips() throws {
        let store = InMemoryCredentialStore()
        try store.save(secret: "sk-abc123")
        #expect(store.secret() == "sk-abc123")
    }

    @Test("Saving replaces the previous secret")
    func saveReplaces() throws {
        let store = InMemoryCredentialStore(secret: "old")
        try store.save(secret: "new")
        #expect(store.secret() == "new")
    }

    @Test("Clearing removes the stored secret")
    func clearRemoves() throws {
        let store = InMemoryCredentialStore(secret: "sk-abc123")
        try store.clear()
        #expect(store.secret() == nil)
    }

    @Test("An empty stored string reads back as nil")
    func emptyStringReadsAsNil() throws {
        let store = InMemoryCredentialStore()
        try store.save(secret: "")
        #expect(store.secret() == nil)
    }

    @Test("CredentialStoreClient with per-provider factory forwards reads, saves, and clears")
    func clientForwards() throws {
        let backing = InMemoryCredentialStore()
        let client = CredentialStoreClient(
            secret: { _ in backing.secret() },
            save: { _, secret in try backing.save(secret: secret) },
            clear: { _ in try backing.clear() }
        )

        #expect(client.secret("openrouter") == nil)
        try client.save("openrouter", "sk-xyz")
        #expect(client.secret("openrouter") == "sk-xyz")
        #expect(backing.secret() == "sk-xyz")
        try client.clear("openrouter")
        #expect(client.secret("openrouter") == nil)
        #expect(backing.secret() == nil)
    }

    @Test("AIProviderCredentialAPI resolves the store at call time via providerID")
    func providerResolvesLazily() throws {
        let store = InMemoryCredentialStore()
        let provider = AIProviderCredentialAPI { _ in store.secret() }

        // No key yet -> resolves to nil.
        #expect(provider.resolve("openrouter") == nil)

        // Key entered after the provider was built -> next resolve sees it,
        // proving the secret is read at request time, never captured at
        // construction.
        try store.save(secret: "sk-late")
        #expect(provider.resolve("openrouter") == "sk-late")

        // Updating again is reflected on the next resolve with no stale value.
        try store.save(secret: "sk-updated")
        #expect(provider.resolve("openrouter") == "sk-updated")
    }
}
