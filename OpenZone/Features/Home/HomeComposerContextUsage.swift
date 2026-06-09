import Foundation

/// Context window usage surfaced in the composer rail.
struct HomeComposerContextUsage: Equatable, Sendable {
    var usedTokens: Int
    var tokenLimit: Int

    var usedFraction: Double {
        guard tokenLimit > 0 else {
            return 0
        }
        return min(max(Double(usedTokens) / Double(tokenLimit), 0), 1)
    }

    var usedPercent: Int {
        Int((usedFraction * 100).rounded())
    }

    var remainingPercent: Int {
        max(100 - usedPercent, 0)
    }

    var usedTokensLabel: String {
        Self.compactTokenLabel(usedTokens)
    }

    var tokenLimitLabel: String {
        Self.compactTokenLabel(tokenLimit)
    }

    private static func compactTokenLabel(_ tokens: Int) -> String {
        if tokens >= 1_000 {
            return "\(tokens / 1_000)k"
        }
        return "\(tokens)"
    }
}
