// One thread in the Threads list: product tile tinted by verdict, name, verdict word, retailer and
// price, the latest chat line if there is one, and on the right the time plus heart and save marks.
// Heart = favourite; save = watch the price and alert. Layout follows Not Yet's HistoryRow
// (notyet/ios/Views/HistoryView.swift) and Worldscape's list row (design catalog I).
import SwiftUI

struct ThreadsListRow: View {
    let thread: ShoppingThread
    let open: () -> Void

    // Marks pop in with an overshoot and leave with a plain fade (springy arrival, quiet exit).
    static let markSpring = Animation.spring(response: 0.34, dampingFraction: 0.5)

    // Where the row text starts, so the list's separators line up with it.
    static let textLeading = Spacing.rowHorizontal + ControlHeight.avatar + Spacing.rowIconToText

    var body: some View {
        let product = thread.product
        Button(action: open) {
            HStack(spacing: Spacing.rowIconToText) {
                ThreadsListTile(symbol: product.icon, color: product.verdict.color)
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
                        Text("\(product.retailer) · \(product.price)")
                            .textStyle(.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .lineLimit(1)
                    if let last = thread.messages.last {
                        chatLine(count: thread.messages.count, last: last)
                    }
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

    // Message count and the latest line, so a thread with a conversation reads as one.
    private func chatLine(count: Int, last: ChatMessage) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 9, weight: .semibold))
            Text("\(count)")
                .monospacedDigit()
            Text("·")
            Text(last.text)
        }
        .textStyle(.footnote)
        .foregroundStyle(Palette.textTertiary)
        .lineLimit(1)
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
        .font(.system(size: 11, weight: .semibold))
        .frame(height: 12)
        .animation(Self.markSpring, value: thread.isHearted)
        .animation(Self.markSpring, value: thread.isSaved)
        .accessibilityHidden(true)
    }

    private var accessibilityState: String {
        [thread.isHearted ? "Hearted" : nil, thread.isSaved ? "Saved, watching price" : nil]
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

// The product symbol on a tile tinted with the verdict colour (Not Yet's VerdictTile).
struct ThreadsListTile: View {
    let symbol: String
    let color: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.key, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: ControlHeight.avatar, height: ControlHeight.avatar)
            .background { shape.fill(color.opacity(0.14)) }
            .overlay { shape.strokeBorder(color.opacity(0.28), lineWidth: 0.5) }
            .accessibilityHidden(true)
    }
}
