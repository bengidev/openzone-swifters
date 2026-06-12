import Foundation

/// Prompt option chip shown in the Idea Studio page.
struct OnboardingPromptOption: Equatable, Sendable, Identifiable {
    public var id: String { prompt }
    public let label: String
    public let prompt: String

    public init(label: String, prompt: String) {
        self.label = label
        self.prompt = prompt
    }

    public static let samples: [OnboardingPromptOption] = [
        OnboardingPromptOption(label: "ASK", prompt: "How should I structure the memory model for this workflow?"),
        OnboardingPromptOption(label: "WRITE", prompt: "Draft a concise interface view for the secure pairing step."),
        OnboardingPromptOption(label: "EXPLORE", prompt: "Compare state actions for queued prompts and reasoning controls.")
    ]
}
