import Foundation
import Testing

@testable import OpenZone

/// Tests for the history sidebar's recency grouping and compact relative
/// labels. Pure value logic — no SwiftData, no store.
@Suite("Chat History Section Grouping")
struct ChatHistorySectionTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func convo(
        title: String,
        updatedDaysAgo days: Double,
        isPinned: Bool = false
    ) -> ChatConversation {
        ChatConversation(
            id: UUID(),
            title: title,
            createdAt: now.addingTimeInterval(-days * 86_400 - 10),
            updatedAt: now.addingTimeInterval(-days * 86_400),
            isPinned: isPinned
        )
    }

    @Test("Pinned conversations collapse into a leading Pinned section")
    func pinnedSectionLeadsAndExcludesFromBuckets() {
        let conversations = [
            convo(title: "Pinned chat", updatedDaysAgo: 3, isPinned: true),
            convo(title: "Today chat", updatedDaysAgo: 0)
        ]
        let sections = ChatHistorySection.grouped(conversations, now: now)

        #expect(sections.first?.title == "Pinned")
        #expect(sections.first?.conversations.count == 1)
        // The pinned chat must not also appear in a recency bucket.
        let nonPinned = sections.dropFirst().flatMap(\.conversations)
        #expect(nonPinned.allSatisfy { !$0.isPinned })
    }

    @Test("Conversations bucket into canonical recency sections in order")
    func recencyBucketsInCanonicalOrder() {
        let conversations = [
            convo(title: "older", updatedDaysAgo: 60),
            convo(title: "today", updatedDaysAgo: 0),
            convo(title: "last week", updatedDaysAgo: 5),
            convo(title: "yesterday", updatedDaysAgo: 1),
            convo(title: "last month", updatedDaysAgo: 20)
        ]
        let titles = ChatHistorySection.grouped(conversations, now: now).map(\.title)
        #expect(titles == ["Today", "Yesterday", "Previous 7 Days", "Previous 30 Days", "Older"])
    }

    @Test("Empty buckets are dropped")
    func emptyBucketsDropped() {
        let conversations = [convo(title: "today", updatedDaysAgo: 0)]
        let titles = ChatHistorySection.grouped(conversations, now: now).map(\.title)
        #expect(titles == ["Today"])
    }

    @Test("Relative label is compact")
    func relativeLabelCompact() {
        #expect(ChatHistorySection.relativeLabel(for: now, now: now) == "now")
        #expect(ChatHistorySection.relativeLabel(for: now.addingTimeInterval(-90), now: now) == "1m")
        #expect(ChatHistorySection.relativeLabel(for: now.addingTimeInterval(-3 * 3600), now: now) == "3h")
        #expect(ChatHistorySection.relativeLabel(for: now.addingTimeInterval(-2 * 86_400), now: now) == "2d")
        #expect(ChatHistorySection.relativeLabel(for: now.addingTimeInterval(-14 * 86_400), now: now) == "2w")
        #expect(ChatHistorySection.relativeLabel(for: now.addingTimeInterval(-400 * 86_400), now: now) == "1y")
    }
}
