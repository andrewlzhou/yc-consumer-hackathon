// A thread's report, top to bottom: the hero (the product's picture, its name large, and the
// verdict word and symbol in the verdict colour), "Why" (a paragraph giving the reason, from
// `Product.reasoning`, or the short summary when there is none), "Prediction" (today against the
// expected price, then the last 12 months of prices with the projection: the backend's history for
// checked products (Backend/ReportFigures.swift), demo history from ThreadDetailHistory.swift),
// and "Sources" (where the numbers came from, and the period they cover).
import SwiftUI
import ShopperKit

struct ThreadDetailReport: View {
    let product: Product
    // Sections rise in one after another once this turns true.
    var revealed: Bool
    // nil while a checked product's report is still on its way.
    private let figures: ThreadDetailFigures?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(product: Product, report: ReportResponse?, revealed: Bool) {
        self.product = product
        self.revealed = revealed
        if product.productId == nil {
            self.figures = ThreadDetailDemoHistory.figures(for: product)
        } else {
            self.figures = report.flatMap { ThreadDetailFigures(report: $0, product: product) }
        }
    }

    private var verdict: Verdict { product.verdict }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            ThreadDetailHero(product: product)
                .modifier(ThreadDetailArrive(index: 1, revealed: revealed, reduceMotion: reduceMotion))
            if !reason.isEmpty {
                ReportSection(title: "Why") {
                    Text(reason)
                        .textStyle(.body)
                        .lineSpacing(7)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .modifier(ThreadDetailArrive(index: 2, revealed: revealed, reduceMotion: reduceMotion))
            }
            ReportSection(title: "Prediction") {
                VStack(alignment: .leading, spacing: 16) {
                    if !product.price.isEmpty { priceSection }
                    if let figures {
                        chartSection(figures)
                    } else {
                        ThinkingLine(step: nil)
                            .padding(.horizontal, 4)
                    }
                }
            }
            .modifier(ThreadDetailArrive(index: 3, revealed: revealed, reduceMotion: reduceMotion))
            if let figures, !figures.sources.isEmpty {
                ReportSection(title: "Sources") { sourcesCard(figures) }
                    .modifier(ThreadDetailArrive(index: 4, revealed: revealed, reduceMotion: reduceMotion))
            }
        }
    }

    // The long reasoning when there is one, otherwise the one-line summary.
    private var reason: String {
        product.reasoning.isEmpty ? product.summary : product.reasoning
    }

    // MARK: Today against the expected price

    private var priceSection: some View {
        FlatCard {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today at \(product.retailer)")
                        .textStyle(.item)
                        .foregroundStyle(Palette.textSecondary)
                    Spacer(minLength: 12)
                    Text(product.price)
                        .textStyle(.wordmark(size: 34))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .accessibilityElement(children: .combine)
                if !product.projectedLow.isEmpty {
                    Hairline()
                    PriceRow(label: "Expected", detail: expectedDate, value: product.projectedLow, valueColor: verdict.color)
                }
            }
        }
    }

    // "Nov 30", when the summary names a time.
    private var expectedDate: String? {
        figures?.predictedDate?.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: Chart

    private func chartSection(_ figures: ThreadDetailFigures) -> some View {
        PriceChartView(
            history: figures.history,
            current: figures.current,
            // A Buy needs no line pointing lower.
            projected: verdict == .buyNow || !figures.hasForecast ? nil : figures.predictedMid,
            projectedDate: figures.predictedDate,
            accent: verdict.color,
            typicalPrice: figures.typical,
            lowest: figures.lowest,
            saleEvents: figures.sales,
            isSampleData: figures.isSampleData
        )
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background {
            RoundedRectangle(cornerRadius: Radius.listCard, style: .continuous)
                .fill(Palette.fillCard)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.listCard, style: .continuous)
                        .strokeBorder(Palette.divider, lineWidth: 1)
                }
        }
    }

    // MARK: Sources

    private func sourcesCard(_ figures: ThreadDetailFigures) -> some View {
        FlatCard {
            VStack(spacing: 0) {
                ForEach(Array(figures.sources.enumerated()), id: \.offset) { index, source in
                    if index > 0 { Hairline() }
                    SourceRow(label: source.name, value: source.detail)
                }
                if let period = figures.period {
                    Hairline()
                    SourceRow(label: "Period", value: period)
                }
            }
        }
    }
}

// MARK: - Hero

// The product's picture, its name in large type, and the verdict word and symbol in the verdict
// colour. Plain on the canvas.
private struct ThreadDetailHero: View {
    let product: Product
    @State private var popped = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ProductPicture(product: product, size: 168, cornerRadius: Radius.glassCard)
            Text(product.name)
                .textStyle(.wordmark(size: 30))
                .lineSpacing(4)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: product.verdict.symbol)
                    .font(.hiragino(.w6, size: 24, relativeTo: .title))
                    .symbolEffect(.bounce, value: popped)
                    .accessibilityHidden(true)
                Text(product.verdict.word)
                    .textStyle(.wordmark(size: 28))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(product.verdict.color)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Verdict: \(product.verdict.word)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { popped = true }
    }
}

// MARK: - Pieces

// A muted label over a block of the report.
private struct ReportSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .textStyle(.label)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

// "Name ............ what it supplied" inside the sources card.
private struct SourceRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .textStyle(.item)
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 8)
            Text(value)
                .textStyle(.caption)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }
}

// "Label / detail ............ value" inside a flat card.
private struct PriceRow: View {
    let label: String
    var detail: String?
    let value: String
    var valueColor: Color = Palette.textPrimary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .textStyle(.item)
                    .foregroundStyle(Palette.textSecondary)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .textStyle(.footnote)
                        .lineSpacing(3)
                        .foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Text(value)
                .textStyle(.cardTitle)
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

// Parts of the detail rise in one after another; under Reduce Motion they only fade.
struct ThreadDetailArrive: ViewModifier {
    let index: Int
    let revealed: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        Group {
            if reduceMotion {
                content.opacity(revealed ? 1 : 0)
            } else {
                content.modifier(RiseEffect(progress: revealed ? 1 : 0))
            }
        }
        .animation(Motion.cardArrive.delay(Double(index) * 0.08), value: revealed)
    }
}
