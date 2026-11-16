// One thread in the Library, Shazam-style: a square picture on the left, the product name over
// the retailer, and a save button on the right (orange filled bookmark when saved). No fill or
// separator. The picture is `ProductPicture`: the demo products' images, a symbol tile otherwise,
// with a small round verdict badge on its bottom-right corner.
// Tapping the row opens the thread; swipe left or long-press also saves. Also the plain List row
// and List styling the Threads screen shares.
import SwiftUI

struct ThreadsListRow: View {
    let thread: ShoppingThread
    let open: () -> Void
    @Environment(ThreadStore.self) private var store

    static let pictureSize: CGFloat = 56

    var body: some View {
        let product = thread.product
        Button(action: open) {
            HStack(spacing: Spacing.rowIconToText) {
                ProductPicture(product: product, size: Self.pictureSize)
                    .overlay(alignment: .bottomTrailing) { VerdictBadge(verdict: product.verdict) }
                VStack(alignment: .leading, spacing: 5) {
                    Text(product.name)
                        .textStyle(.body)
                        .foregroundStyle(Palette.textPrimary)
                    Text(product.retailer)
                        .textStyle(.label)
                        .foregroundStyle(Palette.textSecondary)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                // Room for the save button laid over this end of the row (it also covers the
                // row's trailing padding, so its symbol sits near the screen margin).
                Color.clear.frame(width: ControlHeight.minTouch - Spacing.rowHorizontal, height: 1)
            }
            .threadsRowPadding(vertical: 6)
            .accessibilityElement(children: .combine)
            .accessibilityValue(thread.isSaved ? "\(product.verdict.word), Saved" : product.verdict.word)
        }
        .buttonStyle(ListRowButtonStyle())
        .overlay(alignment: .trailing) { saveButton }
        .threadsPlainRow()
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: toggleSave) { saveLabel }
                .tint(Palette.accent)
        }
        .contextMenu {
            Button(action: open) { Label("Open", systemImage: "arrow.up.right") }
            Button(action: toggleSave) { saveLabel }
        }
    }

    // Its own 44pt target, laid over the row so a tap here saves rather than opens.
    private var saveButton: some View {
        Button(action: toggleSave) {
            Image(systemName: thread.isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(thread.isSaved ? Palette.accent : Palette.textSecondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: ControlHeight.minTouch, height: ControlHeight.minTouch)
                .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .sensoryFeedback(.selection, trigger: thread.isSaved)
        .accessibilityLabel(thread.isSaved ? "Unsave" : "Save")
    }

    private var saveLabel: some View {
        Label(thread.isSaved ? "Unsave" : "Save", systemImage: thread.isSaved ? "bookmark.slash" : "bookmark")
    }

    // With the Watchlist filter on, an unsaved row leaves the list, so the change animates.
    private func toggleSave() {
        withAnimation(Motion.rise) { store.toggleSave(thread.id) }
    }
}

// The verdict's symbol on a disc of its colour, ringed in the canvas colour so it stands apart
// from the picture, and set a few points past the picture's corner. Every verdict symbol is a
// filled circle with the glyph cut out, so the canvas disc behind shows through as the glyph.
private struct VerdictBadge: View {
    let verdict: Verdict

    private static let size: CGFloat = 19
    private static let ring: CGFloat = 2
    private static let overhang: CGFloat = 5

    var body: some View {
        Image(systemName: verdict.symbol)
            .resizable()
            .scaledToFit()
            .foregroundStyle(verdict.color)
            .frame(width: Self.size, height: Self.size)
            .padding(Self.ring)
            .background(Circle().fill(Palette.canvas))
            .offset(x: Self.overhang, y: Self.overhang)
            .accessibilityHidden(true)
    }
}

extension View {
    // Inside a Threads row: room for the pressed fill, and at least a 44pt touch height.
    func threadsRowPadding(vertical: CGFloat = 12) -> some View {
        padding(.horizontal, Spacing.rowHorizontal)
            .padding(.vertical, vertical)
            .frame(minHeight: ControlHeight.minTouch)
    }

    // A List row with nothing drawn around it. The inset puts row content on the screen margin.
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
