// The lower half of Account: two tabs (Hearted, Saved) over a three-column grid of threads, the
// way Instagram shows posts under a profile. Tapping a tile opens that thread.
import SwiftUI

// Icon tabs with a sliding underline under the chosen one, on a full-width hairline. The word is
// for VoiceOver only.
struct ProfileShelfPicker: View {
    @Binding var selection: ProfileShelf
    @Namespace private var underline

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ProfileShelf.allCases) { shelf in
                let chosen = shelf == selection
                Button {
                    withAnimation(Motion.layout) { selection = shelf }
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: chosen ? "\(shelf.symbol).fill" : shelf.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(chosen ? Palette.textPrimary : Palette.textTertiary)
                        ZStack {
                            if chosen {
                                Capsule()
                                    .fill(Palette.textPrimary)
                                    .matchedGeometryEffect(id: "underline", in: underline)
                            }
                        }
                        .frame(height: 1.5)
                    }
                    .frame(maxWidth: .infinity, minHeight: ControlHeight.minTouch, alignment: .bottom)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(shelf.title)
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
        .overlay(alignment: .bottom) { Hairline() }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// Three square tiles per row; nothing when the shelf is empty.
struct ProfileGrid: View {
    let threads: [ShoppingThread]
    let shelf: ProfileShelf
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
        .id(shelf)
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
