// A product as a tappable row on its own flat card: icon, name, the verdict's one-line summary,
// and an optional note on the right (for example "1 hour ago").
import SwiftUI

struct SignalRow: View {
    let product: Product
    var note: String?
    let action: () -> Void

    init(product: Product, note: String? = nil, action: @escaping () -> Void) {
        self.product = product
        self.note = note
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.rowIconToText) {
                Image(systemName: product.verdict.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(product.verdict.color)
                    .frame(width: ControlHeight.avatar, height: ControlHeight.avatar)
                    .background { Circle().fill(Palette.fillChip) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .textStyle(.item)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    Text(product.summary)
                        .textStyle(.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let note {
                    Text(note)
                        .textStyle(.footnote)
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, Spacing.rowHorizontal)
            .frame(minHeight: ControlHeight.row + 8)
        }
        .buttonStyle(ListRowButtonStyle())
        .background { FlatCard { Color.clear } }
    }
}
