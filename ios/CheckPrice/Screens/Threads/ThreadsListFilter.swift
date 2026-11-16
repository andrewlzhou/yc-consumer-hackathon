// The two lists the Threads tab links to above Recents: Watchlist (saved threads; saving means
// watching the price) and Hearted. Each has a title, an outline symbol for its nav row and empty
// state, and the test for which threads it holds.
import SwiftUI

enum ThreadsListFilter: CaseIterable, Identifiable {
    case watchlist, hearted

    var id: Self { self }

    var title: String {
        switch self {
        case .watchlist: "Watchlist"
        case .hearted: "Hearted"
        }
    }

    var symbol: String {
        switch self {
        case .watchlist: "bookmark"
        case .hearted: "heart"
        }
    }

    func includes(_ thread: ShoppingThread) -> Bool {
        switch self {
        case .watchlist: thread.isSaved
        case .hearted: thread.isHearted
        }
    }
}
