// A thread's report in Not Yet's report style (notyet/ios/Views/ProductReportView.swift). Top to
// bottom: the verdict and its reason on glass over warm grey light, today's price against the expected
// price, and the last 12 months of prices: the backend's history for checked products
// (Backend/ReportFigures.swift), demo history from ThreadDetailHistory.swift for demo ones.
import SwiftUI
import ShopperKit

struct ThreadDetailReport: View {
    let product: Product
    // Sections rise in one after another once this turns true.
    var revealed: Bool
    // nil while a checked product's report is still on its way, or when it has none.
    private let figures: ThreadDetailFigures?
    private let awaitingReport: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(product: Product, report: ReportResponse?, revealed: Bool) {
        self.product = product
        self.revealed = revealed
        self.figures = ThreadDetailFigures.forThread(product: product, report: report)
        self.awaitingReport = product.productId != nil && (report?.pending ?? true)
    }

    private var verdict: Verdict { product.verdict }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ThreadDetailHero(product: product)
                .modifier(ThreadDetailArrive(index: 1, revealed: revealed, reduceMotion: reduceMotion))
            if !product.price.isEmpty {
                priceSection
                    .modifier(ThreadDetailArrive(index: 2, revealed: revealed, reduceMotion: reduceMotion))
            }
            if let figures {
                chartSection(figures)
                    .modifier(ThreadDetailArrive(index: 3, revealed: revealed, reduceMotion: reduceMotion))
            } else if awaitingReport {
                ThinkingLine(step: nil)
                    .padding(.horizontal, 4)
            }
        }
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
}

// MARK: - Verdict hero

// The verdict on glass over the hero's grey light: the product, the verdict word and symbol in the verdict
// colour, and the product summary as the reason. Adapted from Not Yet's `VerdictHero`.
private struct ThreadDetailHero: View {
    let product: Product
    @State private var popped = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: product.icon)
                    .font(.hiragino(.w6, size: 13, relativeTo: .caption))
                    .accessibilityHidden(true)
                Text(product.name)
                    .textStyle(.caption)
                    .lineLimit(2)
            }
            .foregroundStyle(Color.white.opacity(0.82))

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: product.verdict.symbol)
                        .font(.hiragino(.w6, size: 34, relativeTo: .largeTitle))
                        .foregroundStyle(product.verdict.color)
                        .symbolEffect(.bounce, value: popped)
                        .accessibilityHidden(true)
                    Text(product.verdict.word)
                        .textStyle(.wordmark(size: 46))
                        .foregroundStyle(product.verdict.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .dropShadow(Shadows.labelOnColor)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Verdict: \(product.verdict.word)")

                Text(product.summary)
                    .textStyle(.statement(size: 20))
                    .lineSpacing(6)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.cardLeading)
            .padding(.top, 16)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface()
        }
        .padding(16)
        .background { HeroLight() }
        .clipShape(RoundedRectangle(cornerRadius: Radius.heroPanel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.heroPanel, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [Color(hex: 0xB0AEA5, opacity: 0.5), Color.white.opacity(0.06)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.75
                )
        }
        .dropShadow(Shadows.heroPanel)
        .onAppear { popped = true }
    }
}

// The hero's light: warm near-black at the top pooling into lighter warm greys below, kept inside the panel.
private struct HeroLight: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.55, 0.45], [1, 0.55],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                Color(hex: 0x1A1917), Color(hex: 0x1C1B19), Color(hex: 0x191816),
                Color(hex: 0x2A2926), Color(hex: 0x34332F), Color(hex: 0x2C2B28),
                Color(hex: 0x45433E), Color(hex: 0x5A5852), Color(hex: 0x3E3D39),
            ]
        )
    }
}

// MARK: - Pieces

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
