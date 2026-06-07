import Foundation

/// Resolves the provider API secret at request time.
///
/// Slice 1 scope (issue #3): a DEBUG-only environment-supplied key is acceptable
/// to prove the wire. Secure Keychain entry and a settings surface arrive in a
/// later slice. The secret is resolved lazily per request and never captured at
/// construction, so swapping the source later does not change the client.
///
/// This is a Shared primitive; it names no chat domain types.
nonisolated struct ChatCredentialProvider: Sendable {
    /// Returns the current secret, or `nil` when none is available.
    var resolve: @Sendable () -> String?

    init(resolve: @escaping @Sendable () -> String?) {
        self.resolve = resolve
    }
}

extension ChatCredentialProvider {
    /// Reads the key from the `OPENROUTER_API_KEY` environment variable.
    ///
    /// In DEBUG this lets a developer prove the live wire by exporting the key
    /// in the scheme's run environment. In release builds the env var is
    /// normally absent, so `resolve()` returns `nil` and the send path reports a
    /// missing-credential error rather than calling out with no auth.
    static let environment = ChatCredentialProvider {
        guard let key = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"],
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return key
    }
}
