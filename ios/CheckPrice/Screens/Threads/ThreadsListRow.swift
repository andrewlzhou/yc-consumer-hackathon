// One thread in the Threads list: product name, verdict word and price, and on the right the time
// plus heart and save marks. Layout follows Worldscape's list row (design catalog I).
import SwiftUI

struct ThreadsListRow: View {
    let thread: ShoppingThread
    let open: () -> Void

    // Marks pop in with an overshoot and leave with a plain fade (springy arrival, quiet exit).
    static let markSpring = Animation.spring(response: 0.34, dampingFraction: 0.5)

    // Where the row text starts, so the list's separators line up with it.
    static let textLeading = Spacing.rowHorizontal

    var body: some View {
        let product = thread.product
        Button(action: open) {
            HStack(spacing: Spacing.rowIconToText) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .textStyle(.item)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(product.verdict.word)
                            .font(.hiragino(.w6, size: TextStyle.caption.size, relativeTo: .caption))
                            .foregroundStyle(product.verdict.color)
                        Text("·").foregroundStyle(Palette.textTertiary)
                        Text(product.price)
                            .textStyle(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(timeLabel)
                        .textStyle(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textTertiary)
                    marks
                }
            }
            .padding(.horizontal, Spacing.rowHorizontal)
            .padding(.vertical, 12)
            .frame(minHeight: ControlHeight.row)
            .accessibilityElement(children: .combine)
            .accessibilityValue(accessibilityState)
        }
        .buttonStyle(ListRowButtonStyle())
        .alignmentGuide(.listRowSeparatorLeading) { _ in Self.textLeading }
    }

    private var marks: some View {
        HStack(spacing: 6) {
            if thread.isSaved {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(Palette.textSecondary)
                    .transition(.asymmetric(insertion: .scale(scale: 0.3).combined(with: .opacity), removal: .opacity))
            }
            if thread.isHearted {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Palette.textPrimary)
                    .transition(.asymmetric(insertion: .scale(scale: 0.3).combined(with: .opacity), removal: .opacity))
            }
        }
        .font(.hiragino(.w6, size: 11))
        .frame(height: 12)
        .animation(Self.markSpring, value: thread.isHearted)
        .animation(Self.markSpring, value: thread.isSaved)
        .accessibilityHidden(true)
    }

    private var accessibilityState: String {
        [thread.isHearted ? "Hearted" : nil, thread.isSaved ? "Saved" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    // Rows are already grouped by day: today shows the time, this week the weekday, older the date.
    private var timeLabel: String {
        let date = thread.startedAt
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if let weekAgo = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: .now)), date >= weekAgo {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        if cal.isDate(date, equalTo: .now, toGranularity: .year) {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
