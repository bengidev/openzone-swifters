import Foundation
import SwiftData

/// Client for persisting onboarding progress.
struct OnboardingPersistenceClient: Sendable {
    public let isCompleted: @Sendable () async throws -> Bool
    public let complete: @Sendable () async throws -> Void

    public init(
        isCompleted: @escaping @Sendable () async throws -> Bool,
        complete: @escaping @Sendable () async throws -> Void
    ) {
        self.isCompleted = isCompleted
        self.complete = complete
    }

    /// Create a live client backed by SwiftData.
    @MainActor
    public static func live(modelContainer: ModelContainer) -> Self {
        Self(
            isCompleted: { @MainActor in
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<OnboardingProgressEntity>(
                    sortBy: [SortDescriptor(\.createdAt)]
                )
                let records = try context.fetch(descriptor)
                return records.first?.isCompleted ?? false
            },
            complete: { @MainActor in
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<OnboardingProgressEntity>(
                    sortBy: [SortDescriptor(\.createdAt)]
                )
                let records = try context.fetch(descriptor)

                let progress: OnboardingProgressEntity
                if let first = records.first {
                    progress = first
                } else {
                    progress = OnboardingProgressEntity()
                    context.insert(progress)
                }

                progress.isCompleted = true
                progress.completedAt = Date()
                progress.lastPageIndex = OnboardingPage.all.count - 1

                try context.save()
            }
        )
    }

    /// Preview/test client that always returns incomplete.
    public static let preview = Self(
        isCompleted: { false },
        complete: {}
    )
}
