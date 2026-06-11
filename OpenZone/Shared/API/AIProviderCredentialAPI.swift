import Foundation

/// Resolves the provider API secret at request time.
///
/// The secret is resolved lazily per request via the `resolve` closure and never
/// captured at construction, so the streaming client always sees the current
/// stored value — editing the key takes effect on the next send with no stale
/// value, and the secret never lives in the request value itself.
///
/// Shared API primitive; it names no chat domain types.
nonisolated struct AIProviderCredentialAPI: Sendable {
    /// Returns the current secret for the given provider id, or `nil` when none
    /// is available.
    var resolve: @Sendable (_ providerID: String) -> String?

    init(resolve: @escaping @Sendable (_ providerID: String) -> String?) {
        self.resolve = resolve
    }
}
