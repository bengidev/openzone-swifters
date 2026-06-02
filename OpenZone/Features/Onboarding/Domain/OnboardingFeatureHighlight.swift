import Foundation

/// A feature highlight badge shown at the bottom of onboarding pages.
public struct OnboardingFeatureHighlight: Equatable, Sendable, Identifiable {
    public var id: String { title }
    public let title: String
    public let detail: String
    public let symbol: String

    public init(title: String, detail: String, symbol: String) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
    }
}
