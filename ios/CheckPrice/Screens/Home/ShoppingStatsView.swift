// Shopping stats, pushed from Home's "Back to Shopping" tile (owner, 2026-11-15: "stats on which
// places you shop the most, such as Amazon, Lewkin, etc. Basically more stats"). A small centred
// title, then cards in Home's style over the backdrop: where you shop, a summary strip, the verdict
// split, checks by month, and categories. Every number is `ShoppingStatsSample`, invented.
import Charts
import SwiftUI

// Marks the stats screen on Home's navigation stack.
struct ShoppingStatsRoute: Hashable {}

private typealias Stats = ShoppingStatsSample

struct ShoppingStatsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HomeCard(title: "Where you shop") { StoresChart(stores: Stats.stores).statsCardContent() }
                StatStrip(items: [
                    StatStripItem(value: "$\(Stats.savedThisYear)", number: Double(Stats.savedThisYear), label: "Saved this year"),
                    StatStripItem(value: "\(Stats.checks)", number: Double(Stats.checks), label: "Checks"),
                    StatStripItem(value: "\(Stats.bought)", number: Double(Stats.bought), label: "Bought"),
                ])
                HomeCard(title: "Verdicts") { VerdictSplit(shares: Stats.verdicts).statsCardContent() }
                HomeCard(title: "Checks by month") { MonthsChart(months: Stats.months).statsCardContent() }
                HomeCard(title: "Categories") { CategoryList(categories: Stats.categories).statsCardContent() }
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollContentBackground(.hidden)
        .background { AppBackdrop() }
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Shopping stats")
                    .font(.hiragino(.w7, size: 16, relativeTo: .headline))
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Checks per store, most first, as horizontal bars with the count at the end. The top store's bar
// is the accent; the rest are neutral.
private struct StoresChart: View {
    let stores: [ShoppingStatsSample.Store]

    var body: some View {
        let top = stores.map(\.checks).max() ?? 0
        Chart(stores) { store in
            BarMark(x: .value("Checks", store.checks), y: .value("Store", store.name), height: .fixed(18))
                .foregroundStyle(store.checks == top ? Palette.accent : Palette.stone)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .annotation(position: .trailing, spacing: 6) {
                    Text("\(store.checks)")
                        .textStyle(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                }
        }
        // Headroom past the longest bar for its count.
        .chartXScale(domain: 0...Double(top) * 1.15)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let name = value.as(String.self) {
                        Text(name)
                            .textStyle(.label)
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
            }
        }
        .frame(height: CGFloat(stores.count) * 32)
        .accessibilityElement(children: .combine)
    }
}

// How the checks split across the four verdicts: one stacked bar in the verdict colours, then a
// two-column legend with each verdict's count.
private struct VerdictSplit: View {
    let shares: [ShoppingStatsSample.VerdictShare]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Chart(shares) { share in
                BarMark(x: .value("Checks", share.checks))
                    .foregroundStyle(share.verdict.color)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 14)
            .clipShape(Capsule())
            .accessibilityHidden(true)
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                ForEach(0..<(shares.count + 1) / 2, id: \.self) { row in
                    GridRow {
                        ForEach(shares[(row * 2)..<min(row * 2 + 2, shares.count)]) { share in
                            HStack(spacing: 8) {
                                Circle().fill(share.verdict.color).frame(width: 8, height: 8)
                                Text(share.verdict.word)
                                    .foregroundStyle(Palette.textPrimary)
                                Text("\(share.checks)")
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            .textStyle(.label)
                            .lineLimit(1)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }
}

// Checks in each of the last six months, a smooth line with a dot per month.
private struct MonthsChart: View {
    let months: [ShoppingStatsSample.Month]

    var body: some View {
        Chart(months) { month in
            LineMark(x: .value("Month", month.label), y: .value("Checks", month.checks))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .foregroundStyle(Palette.muted)
            PointMark(x: .value("Month", month.label), y: .value("Checks", month.checks))
                .symbolSize(28)
                .foregroundStyle(Palette.muted)
                .annotation(position: .top, spacing: 4) {
                    Text("\(month.checks)")
                        .textStyle(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                }
        }
        .chartYScale(domain: 0...Double((months.map(\.checks).max() ?? 0) + 3))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .textStyle(.footnote)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
        }
        .frame(height: 130)
        .accessibilityElement(children: .combine)
    }
}

// Each category's check count, one row per category with hairlines between.
private struct CategoryList: View {
    let categories: [ShoppingStatsSample.Category]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                if index > 0 { Hairline() }
                HStack {
                    Text(category.name)
                        .textStyle(.item)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text("\(category.checks)")
                        .textStyle(.label)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(minHeight: ControlHeight.minTouch)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private extension View {
    // `HomeCard` insets rows 6pt for their pressed fill; charts and lists line up with the title.
    func statsCardContent() -> some View {
        padding(.horizontal, Spacing.cardLeading - 6)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }
}

// Sample data (`isSampleData` in spirit): invented, not from the backend. The parts agree with each
// other: 38 checks split by store, verdict, month and category, and the stores include the demo
// threads' Amazon, Best Buy and Target.
enum ShoppingStatsSample {
    static let isSampleData = true

    struct Store: Identifiable {
        let name: String
        let checks: Int
        var id: String { name }
    }

    struct VerdictShare: Identifiable {
        let verdict: Verdict
        let checks: Int
        var id: String { verdict.rawValue }
    }

    struct Month: Identifiable {
        let label: String
        let checks: Int
        var id: String { label }
    }

    struct Category: Identifiable {
        let name: String
        let checks: Int
        var id: String { name }
    }

    static let savedThisYear = 412
    static let checks = 38
    static let bought = 9

    static let stores = [
        Store(name: "Amazon", checks: 14),
        Store(name: "Best Buy", checks: 9),
        Store(name: "Lewkin", checks: 6),
        Store(name: "Target", checks: 5),
        Store(name: "Apple", checks: 3),
        Store(name: "Nespresso", checks: 1),
    ]

    // Stores with the most checks first, for Home's entry tile.
    static var storesByChecks: [Store] { stores.sorted { $0.checks > $1.checks } }

    static let verdicts = [
        VerdictShare(verdict: .buyNow, checks: 12),
        VerdictShare(verdict: .wait, checks: 14),
        VerdictShare(verdict: .alternative, checks: 7),
        VerdictShare(verdict: .investigate, checks: 5),
    ]

    // Oldest first, ending with this month.
    static let months: [Month] = {
        let counts = [3, 5, 4, 7, 8, 11]
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return counts.enumerated().map { index, count in
            let date = calendar.date(byAdding: .month, value: index - (counts.count - 1), to: .now) ?? .now
            return Month(label: formatter.string(from: date), checks: count)
        }
    }()

    static let categories = [
        Category(name: "Audio", checks: 14),
        Category(name: "Kitchen", checks: 9),
        Category(name: "Fashion", checks: 8),
        Category(name: "Home", checks: 7),
    ]
}
