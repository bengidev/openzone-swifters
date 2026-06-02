import Foundation

/// Queue item shown in the Prompt Queue page demo.
public struct OnboardingQueueItem: Equatable, Sendable, Identifiable {
    public enum Status: String, Equatable, Sendable {
        case running = "RUNNING"
        case next = "NEXT"
        case queued = "QUEUED"
        case ready = "READY"
    }

    public var id: String { title }
    public let title: String
    public let detail: String
    public let status: Status

    public init(title: String, detail: String, status: Status) {
        self.title = title
        self.detail = detail
        self.status = status
    }

    public static let samples: [OnboardingQueueItem] = [
        OnboardingQueueItem(title: "Map onboarding state", detail: "Engine already owns current page", status: .running),
        OnboardingQueueItem(title: "Generate interface cards", detail: "No vertical scroll, compact content", status: .next),
        OnboardingQueueItem(title: "Persist completion", detail: "Storage writes local progress", status: .queued),
        OnboardingQueueItem(title: "Review model budget", detail: "Reasoning slider updates the run", status: .ready),
    ]
}
