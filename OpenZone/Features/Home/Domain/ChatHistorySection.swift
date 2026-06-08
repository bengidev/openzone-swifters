import Foundation

/// Recency-bucketed grouping for the history sidebar. Pinned conversations
/// collapse into a single leading "Pinned" section; the rest fall into
/// recency buckets (Today, Yesterday, Previous 7 Days, Previous 30 Days,
/// Older) keyed off `updatedAt`. Also provides the compact relative-time
/// label shown on each row.
struct ChatHistorySection: Identifiable, Equatable {
    let id: String
    let title: String
    let conversations: [ChatConversation]

    /// Group conversations into the pinned section + recency buckets. Input is
    /// assumed pinned-first / most-recent-first (the client guarantees this);
    /// ordering within each bucket is preserved. Empty buckets are dropped.
    static func grouped(
        _ conversations: [ChatConversation],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ChatHistorySection] {
        var sections: [ChatHistorySection] = []

        let pinned = conversations.filter(\.isPinned)
        if !pinned.isEmpty {
            sections.append(ChatHistorySection(id: "pinned", title: "Pinned", conversations: pinned))
        }

        // Unpinned conversations bucket by recency. Preserve encounter order so
        // the most-recent-first input stays intact within each bucket.
        var buckets: [RecencyBucket: [ChatConversation]] = [:]
        var order: [RecencyBucket] = []
        for conversation in conversations where !conversation.isPinned {
            let bucket = RecencyBucket.classify(conversation.updatedAt, now: now, calendar: calendar)
            if buckets[bucket] == nil { order.append(bucket) }
            buckets[bucket, default: []].append(conversation)
        }

        // Emit buckets in canonical recency order rather than encounter order.
        for bucket in RecencyBucket.allCases where buckets[bucket] != nil {
            sections.append(
                ChatHistorySection(
                    id: bucket.rawValue,
                    title: bucket.title,
                    conversations: buckets[bucket] ?? []
                )
            )
        }

        return sections
    }

    /// Compact relative label: "now", "5m", "3h", "2d", "1w", "4mo", "1y".
    static func relativeLabel(for date: Date, now: Date = Date()) -> String {
        let interval = max(0, now.timeIntervalSince(date))
        let minute: TimeInterval = 60
        let hour = 60 * minute
        let day = 24 * hour
        let week = 7 * day
        let month = 30 * day
        let year = 365 * day

        if interval >= year { return "\(Int(interval / year))y" }
        if interval >= month { return "\(Int(interval / month))mo" }
        if interval >= week { return "\(Int(interval / week))w" }
        if interval >= day { return "\(Int(interval / day))d" }
        if interval >= hour { return "\(Int(interval / hour))h" }
        if interval >= minute { return "\(Int(interval / minute))m" }
        return "now"
    }
}

/// Recency buckets in canonical display order.
private enum RecencyBucket: String, CaseIterable {
    case today
    case yesterday
    case previous7Days
    case previous30Days
    case older

    var title: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .previous7Days: return "Previous 7 Days"
        case .previous30Days: return "Previous 30 Days"
        case .older: return "Older"
        }
    }

    static func classify(_ date: Date, now: Date, calendar: Calendar) -> RecencyBucket {
        // Fully `now`-relative so the bucketing is deterministic and testable.
        // (Foundation's isDateInToday/isDateInYesterday compare against the real
        // current date, which would ignore an injected reference date.)
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        guard let daysAgo = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day else {
            return .older
        }
        if daysAgo <= 0 { return .today }
        if daysAgo == 1 { return .yesterday }
        if daysAgo <= 7 { return .previous7Days }
        if daysAgo <= 30 { return .previous30Days }
        return .older
    }
}
