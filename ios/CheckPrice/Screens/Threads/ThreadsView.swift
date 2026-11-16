// The Threads tab, laid out like the Claude app's sidebar: nav rows for Watchlist and Hearted on
// top, then "Recents": every thread, newest first, as one line of product name. A nav row pushes
// ThreadsFilteredView, the same rows limited to that list. Tapping a thread opens
// ThreadDetailView. There is no search (the owner leaves that to a general agent). It is a List
// because swipe actions (heart, save) only exist on List rows.
import SwiftUI

enum ThreadsRoute: Hashable {
    case filtered(ThreadsListFilter)
    case thread(UUID)
}

struct ThreadsView: View {
    @Environment(ThreadStore.self) private var store
    @State private var path: [ThreadsRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(ThreadsListFilter.allCases) { filter in
                    ThreadsNavRow(filter: filter) { path.append(.filtered(filter)) }
                }
                recentsLabel
                ForEach(store.threads) { thread in
                    ThreadsListRow(thread: thread) { path.append(.thread(thread.id)) }
                }
            }
            .threadsPlainList()
            // ContentView draws the backdrop behind every tab; keep the stack see-through.
            .containerBackground(.clear, for: .navigation)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ThreadsRoute.self) { route in
                switch route {
                case .filtered(let filter):
                    ThreadsFilteredView(filter: filter) { path.append(.thread($0)) }
                case .thread(let id):
                    ThreadDetailView(threadID: id)
                }
            }
        }
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

// A nav row: a thin outline symbol and the list's name in large regular text.
private struct ThreadsNavRow: View {
    let filter: ThreadsListFilter
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: Spacing.rowIconToText) {
                Image(systemName: filter.symbol)
                    .font(.system(size: 19, weight: .light))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(filter.title)
                    .textStyle(.statement(size: 18))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.textPrimary)
            .threadsRowPadding()
        }
        .buttonStyle(ListRowButtonStyle())
        .threadsPlainRow()
    }
}

// Watchlist or Hearted, pushed from its nav row: the matching threads, newest first, in the same
// plain rows, with the list's name in the bar.
struct ThreadsFilteredView: View {
    let filter: ThreadsListFilter
    let open: (UUID) -> Void
    @Environment(ThreadStore.self) private var store

    var body: some View {
        let threads = store.threads.filter(filter.includes)
        List {
            if threads.isEmpty {
                emptyState
            } else {
                ForEach(threads) { thread in
                    ThreadsListRow(thread: thread) { open(thread.id) }
                }
            }
        }
        .threadsPlainList()
        .background(Palette.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(filter.title)
                    .textStyle(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    // Worldscape's empty list: the list's symbol, light and tertiary, 72pt down.
    private var emptyState: some View {
        Image(systemName: filter.symbol)
            .font(.hiragino(.w3, size: 22))
            .foregroundStyle(Palette.textTertiary)
            .accessibilityLabel("None")
            .frame(maxWidth: .infinity)
            .padding(.top, 72)
            .threadsPlainRow()
            .transition(.opacity)
    }
}
