// One card split into equal segments by thin vertical hairlines, each a large number over a
// one-line label (owner, 2026-11-15: "center these and make this more proper, connect those three
// boxes"). Home's three counts and the Shopping stats summary both use it.
import SwiftUI

struct StatStripItem: Identifiable {
    let value: String
    // Drives the number roll when the value changes.
    let number: Double
    let label: String

    var id: String { label }
}

struct StatStrip: View {
    let items: [StatStripItem]

    var body: some View {
        FlatCard(cornerRadius: Radius.glassCard) {
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    StatSegment(item: item)
                        // The hairline sits on the segment's leading edge, so it takes the
                        // segment's height and every segment stays the same width.
                        .overlay(alignment: .leading) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Palette.divider)
                                    .frame(width: 1)
                                    .padding(.vertical, 14)
                            }
                        }
                }
            }
        }
    }
}

private struct StatSegment: View {
    let item: StatStripItem

    var body: some View {
        VStack(spacing: 6) {
            Text(item.value)
                .font(.hiragino(.w6, size: 24, relativeTo: .title2))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText(value: item.number))
                .animation(Motion.valueChange, value: item.number)
            Text(item.label)
                .textStyle(.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// Home's three counts: money saved by waiting on saved threads (`SavedByWaiting`, kept in
// Account/AccountView.swift), how many threads are saved, and how many checks were made this month.
struct HomeSummaryRow: View {
    let threads: [ShoppingThread]
    let saved: [ShoppingThread]

    var body: some View {
        let waited = SavedByWaiting.total(saved)
        let thisMonth = threads.filter { Calendar.current.isDate($0.startedAt, equalTo: .now, toGranularity: .month) }.count
        StatStrip(items: [
            StatStripItem(value: SavedByWaiting.format(waited), number: Double(waited), label: "Saved"),
            StatStripItem(value: "\(saved.count)", number: Double(saved.count), label: "Watching"),
            StatStripItem(value: "\(thisMonth)", number: Double(thisMonth), label: "Checks"),
        ])
    }
}
