// The lower half of Account: the saved threads as a three-column grid, the way Instagram shows
// posts under a profile. Tapping a tile opens that thread.
import SwiftUI

// Three square tiles per row; nothing when there are no saved threads.
struct ProfileGrid: View {
    let threads: [ShoppingThread]
    @Environment(ThreadStore.self) private var store

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ZStack(alignment: .top) {
            if !threads.isEmpty {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(threads) { thread in
                        Button {
                            store.openThreadID = thread.id
                        } label: {
                            ThreadTile(thread: thread)
                        }
                        .buttonStyle(GlassCardButtonStyle(cornerRadius: Radius.listCard))
                        .transition(.rise)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(Motion.emptyStateSwap, value: threads.isEmpty)
        .animation(Motion.rise, value: threads.map(\.id))
    }
}

// One thread as a square: the product's symbol on glass tinted with its verdict colour, and the
// price in the corner.
private struct ThreadTile: View {
    let thread: ShoppingThread

    var body: some View {
        let product = thread.product
        let tint = product.verdict.color
        let shape = RoundedRectangle(cornerRadius: Radius.listCard, style: .continuous)
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(systemName: product.icon)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(Palette.textPrimary)
            }
            .overlay(alignment: .bottomLeading) {
                Text(product.price)
                    .textStyle(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.leading, 10)
                    .padding(.bottom, 8)
            }
            .background {
                shape.fill(
                    LinearGradient(colors: [tint.opacity(0.30), tint.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(product.name), \(product.price), \(product.verdict.word)")
            .accessibilityHint("Opens the thread")
    }
}
