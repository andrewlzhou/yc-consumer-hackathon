// One thread in a Threads list: the product name on one line, nothing else, with no fill or
// separator (like a Recents row in the Claude app's sidebar). Swipe right to heart, left to save
// (watch the price), or long-press for both; tapping opens the thread. Also the plain List row and
// List styling the Threads screens share.
import SwiftUI

struct ThreadsListRow: View {
    let thread: ShoppingThread
    let open: () -> Void
    @Environment(ThreadStore.self) private var store

    var body: some View {
        Button(action: open) {
            Text(thread.product.name)
                .textStyle(.body)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .threadsRowPadding()
                .accessibilityValue(accessibilityState)
        }
        .buttonStyle(ListRowButtonStyle())
        .threadsPlainRow()
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: toggleHeart) { heartLabel }
                .tint(Palette.stone)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: toggleSave) { saveLabel }
                .tint(Palette.accent)
        }
        .contextMenu {
            Button(action: open) { Label("Open", systemImage: "arrow.up.right") }
            Button(action: toggleHeart) { heartLabel }
            Button(action: toggleSave) { saveLabel }
        }
    }

    private var heartLabel: some View {
        Label(thread.isHearted ? "Unheart" : "Heart", systemImage: thread.isHearted ? "heart.slash" : "heart")
    }

    private var saveLabel: some View {
        Label(thread.isSaved ? "Unsave" : "Save", systemImage: thread.isSaved ? "bookmark.slash" : "bookmark")
    }

    // On the Watchlist or Hearted screen the row leaves the list, so the change animates.
    private func toggleHeart() {
        withAnimation(Motion.rise) { store.toggleHeart(thread.id) }
    }

    private func toggleSave() {
        withAnimation(Motion.rise) { store.toggleSave(thread.id) }
    }

    // The row shows no marks, so VoiceOver still says which lists the thread is in.
    private var accessibilityState: String {
        [thread.isHearted ? "Hearted" : nil, thread.isSaved ? "Saved" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

extension View {
    // Inside a Threads row: room for the pressed fill, and a generous touch height.
    func threadsRowPadding() -> some View {
        padding(.horizontal, Spacing.rowHorizontal)
            .padding(.vertical, 12)
            .frame(minHeight: ControlHeight.minTouch)
    }

    // A List row with nothing drawn around it. The inset puts row text on the screen margin.
    func threadsPlainRow() -> some View {
        let inset = Spacing.screenMargin - Spacing.rowHorizontal
        return listRowInsets(EdgeInsets(top: 0, leading: inset, bottom: 0, trailing: inset))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    // A plain, see-through List whose rows set their own height.
    func threadsPlainList() -> some View {
        listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 8, for: .scrollContent)
    }
}
