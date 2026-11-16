// The Threads tab, titled "Library" (owner, 2026-11-15): the title scrolls with the content, with
// an icon-only Watchlist toggle at its right end, then "Recents": every thread newest first,
// Shazam-style (picture, name, retailer, save button). The toggle filters the list in place to
// saved threads and tapping again shows all; the orange filled bookmark marks it on. Tapping a
// thread opens ThreadDetailView.
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
                titleLine
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

    // The trailing inset matches the rows' save buttons, so the bookmarks line up in one column.
    private var titleLine: some View {
        HStack(spacing: 0) {
            ScreenTitle("Library")
            Spacer(minLength: 0)
            watchlistToggle
        }
        .padding(.leading, Spacing.rowHorizontal)
        .padding(.bottom, 12)
        .threadsPlainRow()
    }

    // A thin outline bookmark; on, it fills orange and the list shows only saved threads.
    private var watchlistToggle: some View {
        Button {
            withAnimation(Motion.rise) { watchlistOnly.toggle() }
        } label: {
            Image(systemName: watchlistOnly ? "bookmark.fill" : "bookmark")
                .font(.system(size: 19, weight: .light))
                .foregroundStyle(watchlistOnly ? Palette.accent : Palette.textPrimary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: ControlHeight.minTouch, height: ControlHeight.minTouch)
                .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .sensoryFeedback(.selection, trigger: watchlistOnly)
        .accessibilityLabel("Watchlist")
        .accessibilityValue(watchlistOnly ? "On" : "Off")
        .accessibilityAddTraits(watchlistOnly ? .isSelected : [])
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
