// Home's cards, after the cards on the Truck page of Apple's Food Truck sample (`TruckOrdersCard`,
// `TruckWeatherCard`, `CardNavigationHeader`; MIT-style Apple sample licence): a header row over
// the card's content, a `Grid` row of equal-height tiles fixed to their natural height, and Swift
// Charts with the axes hidden for small trend lines. Ours are flat `FlatCard`s on the backdrop, in
// Hiragino, with no icons in the headers.
import Charts
import ShopperKit
import SwiftUI

// Three counts in equal tiles: money saved by waiting on saved threads (`SavedByWaiting`, as on
// Account), how many threads are saved, and how many checks were made this month.
struct HomeSummaryRow: View {
    let threads: [ShoppingThread]
    let saved: [ShoppingThread]

    var body: some View {
        let waited = SavedByWaiting.total(saved)
        let thisMonth = threads.filter { Calendar.current.isDate($0.startedAt, equalTo: .now, toGranularity: .month) }.count
        Grid(horizontalSpacing: 12) {
            GridRow {
                HomeSummaryTile(value: SavedByWaiting.format(waited), number: Double(waited), label: "Saved by waiting")
                HomeSummaryTile(value: "\(saved.count)", number: Double(saved.count), label: "Watching")
                HomeSummaryTile(value: "\(thisMonth)", number: Double(thisMonth), label: "Checks")
            }
        }
        // Food Truck's trick: the grid takes its natural height, so the tiles share the tallest one's.
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct HomeSummaryTile: View {
    let value: String
    let number: Double
    let label: String

    var body: some View {
        FlatCard(cornerRadius: Radius.listCard) {
            VStack(alignment: .leading, spacing: 6) {
                Text(value)
                    .font(.hiragino(.w6, size: 22, relativeTo: .title2))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText(value: number))
                    .animation(Motion.valueChange, value: number)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .textStyle(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
    }
}

// Every saved thread: picture, name, today's price and the predicted low, and a small line of the
// last three months' prices. An orange dot ends the line when the price dropped recently. Tapping a
// row opens the thread.
struct HomeWatchlistCard: View {
    let threads: [ShoppingThread]
    let open: (UUID) -> Void

    var body: some View {
        HomeCard(title: "Watchlist") {
            ForEach(threads) { thread in
                HomeWatchRow(thread: thread, trend: HomeTrend(thread: thread)) { open(thread.id) }
            }
        }
    }
}

private struct HomeWatchRow: View {
    let thread: ShoppingThread
    let trend: HomeTrend?
    let open: () -> Void

    var body: some View {
        let product = thread.product
        Button(action: open) {
            HStack(spacing: 12) {
                ProductPicture(product: product, size: HomeLayout.pictureSize)
                VStack(alignment: .leading, spacing: 5) {
                    Text(product.name)
                        .textStyle(.item)
                        .foregroundStyle(Palette.textPrimary)
                    HStack(spacing: 6) {
                        Text(product.price)
                            .foregroundStyle(Palette.textPrimary)
                        if !product.projectedLow.isEmpty {
                            Text("low \(product.projectedLow)")
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                    .textStyle(.label)
                    .monospacedDigit()
                }
                .lineLimit(1)
                Spacer(minLength: 8)
                if let trend {
                    HomeSparkline(trend: trend)
                        .frame(width: 64, height: 28)
                }
            }
            .homeRowPadding()
            .accessibilityElement(children: .combine)
            .accessibilityValue(trend?.dropped == true ? "Price dropped" : "")
        }
        .buttonStyle(ListRowButtonStyle())
    }
}

// The last three threads, newest first, with the verdict badge from the Library rows, and
// "See all", which switches to the Threads tab.
struct HomeRecentChecksCard: View {
    let threads: [ShoppingThread]
    let open: (UUID) -> Void
    let seeAll: () -> Void

    var body: some View {
        HomeCard(title: "Recent checks", seeAll: seeAll) {
            ForEach(threads) { thread in
                let product = thread.product
                Button { open(thread.id) } label: {
                    HStack(spacing: 12) {
                        ProductPicture(product: product, size: HomeLayout.pictureSize)
                            .overlay(alignment: .bottomTrailing) { VerdictBadge(verdict: product.verdict) }
                        VStack(alignment: .leading, spacing: 5) {
                            Text(product.name)
                                .textStyle(.item)
                                .foregroundStyle(Palette.textPrimary)
                            Text(product.retailer)
                                .textStyle(.label)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .homeRowPadding()
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(product.verdict.word)
                }
                .buttonStyle(ListRowButtonStyle())
            }
        }
    }
}

// A card: its title (and "See all" when given) over rows. Rows reach to 6pt inside the card's
// edge so their pressed fill has room; their own padding puts content on the header's margin.
private struct HomeCard<Content: View>: View {
    let title: String
    var seeAll: (() -> Void)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        FlatCard(cornerRadius: Radius.glassCard) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .textStyle(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if let seeAll {
                        Button("See all", action: seeAll)
                            .textStyle(.label)
                            .foregroundStyle(Palette.textSecondary)
                            .frame(minHeight: ControlHeight.minTouch)
                            .contentShape(Rectangle())
                    }
                }
                .frame(minHeight: ControlHeight.minTouch)
                .padding(.horizontal, Spacing.cardLeading)
                VStack(spacing: 0) { content }
                    .padding(.horizontal, HomeLayout.rowInset)
            }
            .padding(.top, 6)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private enum HomeLayout {
    static let pictureSize: CGFloat = 44
    static let rowInset: CGFloat = 6
}

private extension View {
    func homeRowPadding() -> some View {
        padding(.horizontal, Spacing.cardLeading - HomeLayout.rowInset)
            .padding(.vertical, 8)
            .frame(minHeight: ControlHeight.minTouch)
    }
}

// A thread's recent prices for the sparkline: one point a day (the lowest, when several stores
// report), the last 90 days and today, and whether the price dropped recently: today at least 5%
// under the highest price of the past 30 days. Demo threads use their sample history; checked ones
// the backend's, once the report is in.
struct HomeTrend {
    let points: [(day: Date, price: Double)]
    let dropped: Bool

    init?(thread: ShoppingThread, today: Date = .now) {
        let product = thread.product
        let figures = product.productId == nil
            ? ThreadDetailDemoHistory.figures(for: product, today: today)
            : thread.report.flatMap { ThreadDetailFigures(report: $0, product: product) }
        guard let figures, figures.current > 0 else { return nil }

        var lowest: [Date: Double] = [:]
        for point in figures.history {
            guard let day = ChartFormat.day(point.date), day >= today.addingTimeInterval(-90 * 86_400) else { continue }
            lowest[day] = min(lowest[day] ?? point.price, point.price)
        }
        let recent = lowest.sorted { $0.key < $1.key }.map { (day: $0.key, price: $0.value) }
        guard !recent.isEmpty else { return nil }
        points = recent + [(day: today, price: figures.current)]

        let lastMonth = recent.filter { $0.day >= today.addingTimeInterval(-30 * 86_400) }.map(\.price)
        dropped = (lastMonth.max() ?? 0) * 0.95 >= figures.current
    }
}

private struct HomeSparkline: View {
    let trend: HomeTrend

    var body: some View {
        Chart {
            ForEach(trend.points, id: \.day) { point in
                LineMark(x: .value("Day", point.day), y: .value("Price", point.price))
                    .interpolationMethod(.monotone)
            }
            .foregroundStyle(Palette.textSecondary)
            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            if trend.dropped, let last = trend.points.last {
                PointMark(x: .value("Day", last.day), y: .value("Price", last.price))
                    .symbolSize(28)
                    .foregroundStyle(Palette.accent)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .accessibilityHidden(true)
    }
}
