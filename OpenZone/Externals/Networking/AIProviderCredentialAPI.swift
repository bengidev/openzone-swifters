import Foundation

/// Resolves the provider API secret at request time.
///
/// The secret is resolved lazily per request via the `resolve` closure and never
/// captured at construction, so the streaming client always sees the current
/// stored value — editing the key takes effect on the next send with no stale
/// value, and the secret never lives in the request value itself.
///
/// Externals networking primitive; it names no chat domain types.
nonisolated struct AIProviderCredentialAPI: Sendable {
    /// Returns the current secret, or `nil` when none is available.
    var resolve: @Sendable () -> String?

    init(resolve: @escaping @Sendable () -> String?) {
        self.resolve = resolve
    }
}

extension AIProviderCredentialAPI {
    /// Resolves the secret from a `CredentialStore` at request time.
    ///
    /// The store is read on every `resolve()` call, so a key entered or updated
    /// through Settings is picked up on the next send without reconstructing the
    /// client. When no key is stored, `resolve()` returns `nil` and the send path
    /// reports a missing-credential error rather than calling out with no auth.
    static func keychain(_ store: some CredentialStore) -> AIProviderCredentialAPI {
        AIProviderCredentialAPI { store.secret() }
    }
}
