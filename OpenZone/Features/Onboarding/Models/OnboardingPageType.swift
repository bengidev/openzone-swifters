import Foundation

/// Represents the distinct pages/screens in the onboarding flow.
enum OnboardingPageType: String, Equatable, Sendable, CaseIterable {
    case encryptedPairing
    case ideaStudio
    case promptQueue
    case reasoningControl
    case workspaceReady
}
