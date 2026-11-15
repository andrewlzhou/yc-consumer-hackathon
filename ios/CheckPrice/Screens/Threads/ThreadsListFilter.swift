// The Threads tab's filter chips (All / Hearted / Saved), how each sorts threads into Today /
// This week / Earlier, and the symbol each shows when it is empty. There is no search by design: the
// owner wants search left to a general agent.
import SwiftUI

enum ThreadsListFilter: CaseIterable, Identifiable {
    case all, hearted, saved

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .hearted: "Hearted"
        case .saved: "Saved"
        }
    }

    func includes(_ thread: ShoppingThread) -> Bool {
        switch self {
        case .all: true
        case .hearted: thread.isHearted
        case .saved: thread.isSaved
        }
    }

    var emptySymbol: String {
        switch self {
        case .all: "bubble.left.and.bubble.right"
        case .hearted: "heart"
        case .saved: "bookmark"
        }
    }
}

struct ThreadsListSection: Identifiable {
    let title: String
    let threads: [ShoppingThread]
    var id: String { title }

    // Threads arrive newest first; grouping keeps that order inside each section.
    static func group(_ threads: [ShoppingThread], now: Date = .now) -> [ThreadsListSection] {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: now)) ?? now
        return [
            ThreadsListSection(title: "Today", threads: threads.filter { cal.isDateInToday($0.startedAt) }),
            ThreadsListSection(title: "This week", threads: threads.filter { !cal.isDateInToday($0.startedAt) && $0.startedAt >= weekAgo }),
            ThreadsListSection(title: "Earlier", threads: threads.filter { $0.startedAt < weekAgo }),
        ].filter { !$0.threads.isEmpty }
    }
}
