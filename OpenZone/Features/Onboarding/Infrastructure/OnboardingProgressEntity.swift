import Foundation
import SwiftData

/// SwiftData model for persisting onboarding completion state.
@Model
public final class OnboardingProgressEntity {
    public var id: UUID
    public var createdAt: Date
    public var completedAt: Date?
    public var isCompleted: Bool
    public var lastPageIndex: Int

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        isCompleted: Bool = false,
        lastPageIndex: Int = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.isCompleted = isCompleted
        self.lastPageIndex = lastPageIndex
    }
}
