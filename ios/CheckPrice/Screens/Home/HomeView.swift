// Home: a dashboard (owner, 2026-11-15: "only a dashboard, without the animation"). No screen title
// and no in-app check (the round "plus" button was removed, owner 2026-11-15). The content starts
// about a third of the way down with the "Back to Shopping" tile (`ShoppingEntryButton`), which pushes
// Shopping stats (`ShoppingStatsView`), then the cards: three counts in one strip (`StatStrip`), the
// Watchlist, and Recent checks. The layout follows the Truck page of Apple's Food Truck sample
// (`TruckView`): a scrolling stack of cards at even spacing, each card with its own header, and rows
// that push the item they show. The cards are in `HomeCards.swift`.
import SwiftUI

struct HomeView: View {
    // Switches to the Threads tab, for Recent checks' "See all".
    let showLibrary: () -> Void
    @Environment(ThreadStore.self) private var store
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Free space above everything (owner, 2026-11-15: "push all these elements down").
                    Color.clear
                        .containerRelativeFrame(.vertical) { height, _ in height * 0.28 }
                    ShoppingEntryButton { path.append(ShoppingStatsRoute()) }
                    HomeSummaryRow(threads: store.threads, saved: store.saved)
                    if !store.saved.isEmpty {
                        HomeWatchlistCard(threads: store.saved, open: open)
                    }
                    if !store.threads.isEmpty {
                        HomeRecentChecksCard(threads: Array(store.threads.prefix(3)), open: open, seeAll: showLibrary)
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, 32)
            }
            // ContentView draws the backdrop behind every tab; keep the stack see-through.
            .containerBackground(.clear, for: .navigation)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { ThreadDetailView(threadID: $0) }
            .navigationDestination(for: ShoppingStatsRoute.self) { _ in ShoppingStatsView() }
        }
    }

    private func open(_ id: UUID) { path.append(id) }
}
