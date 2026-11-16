// The Threads tab, titled "Library" (owner, 2026-11-15): the title scrolls with the content, then a
// Watchlist row, then "Recents": every thread newest first, Shazam-style (picture, name, retailer,
// save button). Tapping Watchlist filters the list in place to saved threads and tapping again
// shows all; the orange filled bookmark marks it on. Tapping a thread opens ThreadDetailView.
// There is no search (the owner leaves that to a general agent). It is a List because swipe
// actions only exist on List rows.
import SwiftUI

struct ThreadsView: View {
    @Environment(ThreadStore.self) private var store
    @State private var path: [UUID] = []
    @State private var watchlistOnly = false

    private var threads: [ShoppingThread] {
        watchlistOnly ? store.saved : store.threads
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ScreenTitle("Library")
                    .padding(.horizontal, Spacing.rowHorizontal)
                    .padding(.bottom, 12)
                    .threadsPlainRow()
                watchlistRow
                recentsLabel
                ForEach(threads) { thread in
                    ThreadsListRow(thread: thread) { path.append(thread.id) }
                }
            }
            .threadsPlainList()
            // ContentView draws the canvas behind every tab; keep the stack see-through.
            .containerBackground(.clear, for: .navigation)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { ThreadDetailView(threadID: $0) }
        }
    }

    // A thin outline bookmark and "Watchlist" in large regular text; on, the bookmark fills orange.
    private var watchlistRow: some View {
        Button {
            withAnimation(Motion.rise) { watchlistOnly.toggle() }
        } label: {
            HStack(spacing: Spacing.rowIconToText) {
                Image(systemName: watchlistOnly ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 19, weight: .light))
                    .foregroundStyle(watchlistOnly ? Palette.accent : Palette.textPrimary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text("Watchlist")
                    .textStyle(.statement(size: 18))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .threadsRowPadding()
        }
        .buttonStyle(ListRowButtonStyle())
        .sensoryFeedback(.selection, trigger: watchlistOnly)
        .accessibilityAddTraits(watchlistOnly ? .isSelected : [])
        .threadsPlainRow()
    }

    private var recentsLabel: some View {
        Text("Recents")
            .textStyle(.label)
            .foregroundStyle(Palette.textSecondary)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, Spacing.rowHorizontal)
            .padding(.top, 24)
            .padding(.bottom, 4)
            .threadsPlainRow()
    }
}
