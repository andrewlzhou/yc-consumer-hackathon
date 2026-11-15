// A thread's report: the prototype's report content in Not Yet's report style
// (notyet/ios/Views/ProductReportView.swift). Top to bottom: the verdict on glass over blue light,
// today's price against the predicted low, the last 12 months of prices, and the signal (what to do
// and why). The price history is demo data (ThreadDetailHistory.swift).
import SwiftUI

struct ThreadDetailReport: View {
    let product: Product
    // Sections rise in one after another once this turns true.
    var revealed: Bool
    private let figures: ThreadDetailFigures
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(product: Product, revealed: Bool) {
        self.product = product
        self.revealed = revealed
        self.figures = ThreadDetailDemoHistory.figures(for: product)
    }

    private var verdict: Verdict { product.verdict }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ThreadDetailHero(product: product)
                .modifier(ThreadDetailArrive(index: 1, revealed: revealed, reduceMotion: reduceMotion))
            priceSection
                .modifier(ThreadDetailArrive(index: 2, revealed: revealed, reduceMotion: reduceMotion))
            chartSection
                .modifier(ThreadDetailArrive(index: 3, revealed: revealed, reduceMotion: reduceMotion))
            signalSection
                .modifier(ThreadDetailArrive(index: 4, revealed: revealed, reduceMotion: reduceMotion))
        }
    }

    // MARK: Today against the predicted low

    private var priceSection: some View {
        ThreadDetailSection(title: "Price") {
            FlatCard {
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today at \(product.retailer)")
                                .textStyle(.item)
                                .foregroundStyle(Palette.textSecondary)
                            Text(usualDetail)
                                .textStyle(.footnote)
                                .foregroundStyle(Palette.textTertiary)
                        }
                        Spacer(minLength: 12)
                        Text(product.price)
                            .textStyle(.wordmark(size: 34))
                            .monospacedDigit()
                            .foregroundStyle(Palette.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .accessibilityElement(children: .combine)
                    Hairline()
                    PriceRow(label: "Predicted low", detail: predictedDetail, value: product.projectedLow, valueColor: verdict.color)
                }
            }
        }
    }

    // "$30 under usual (8%)" / "The usual price" / "$10 above usual (3%)".
    private var usualDetail: String {
        let diff = figures.current - figures.typical
        let percent = Int((abs(diff) / max(figures.typical, 1) * 100).rounded())
        if abs(diff) < 1 { return "The usual price" }
        return diff < 0 ? "\(money(-diff)) under usual (\(percent)%)" : "\(money(diff)) above usual (\(percent)%)"
    }

    // "by Nov 30 · save up to $40".
    private var predictedDetail: String? {
        var parts: [String] = []
        if let date = figures.predictedDate {
            parts.append("by \(date.formatted(.dateTime.month(.abbreviated).day()))")
        }
        let save = figures.current - figures.predictedLow.lowerBound
        if save >= 1 { parts.append("save up to \(money(save))") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: Chart

    private var chartSection: some View {
        ThreadDetailSection(title: "Last 12 months") {
            PriceChartView(
                history: figures.history,
                current: figures.current,
                // A Buy needs no line pointing lower.
                projected: verdict == .buyNow ? nil : figures.predictedMid,
                projectedDate: figures.predictedDate,
                accent: verdict.color,
                typicalPrice: figures.typical,
                lowest: figures.lowest,
                saleEvents: figures.sales
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

    // MARK: The signal

    private var signalSection: some View {
        ThreadDetailSection(title: "The signal") {
            VStack(alignment: .leading, spacing: 12) {
                Text(signalHeadline)
                    .textStyle(.statement(size: 24))
                    .lineSpacing(6)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(signalReason)
                    .textStyle(.body)
                    .lineSpacing(6)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Price history here is sample data. Saving is a prototype for now: no alerts are sent yet.")
                    .textStyle(.footnote)
                    .lineSpacing(3)
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    private var signalHeadline: String {
        switch verdict {
        case .buyNow: "Buy at \(product.price)."
        case .wait: "Wait for \(product.projectedLow)."
        case .alternative: "Compare before you buy."
        case .investigate: "Check the listing first."
        }
    }

    private var signalReason: String {
        let lowWhen = figures.lowSaleName.map { " during \($0)" } ?? ""
        switch verdict {
        case .buyNow:
            return "Today’s price is within \(money(figures.current - figures.low)) of its lowest this year (\(money(figures.low))\(lowWhen)) and under its usual \(money(figures.typical)). A much better price is unlikely soon."
        case .wait:
            return "It fell to \(money(figures.low))\(lowWhen) and usually sells for about \(money(figures.typical)). Today’s price is not close to its usual low."
        case .alternative:
            return "Similar products often sell for less than this one. Its lowest this year was \(money(figures.low)); compare a few options before paying \(product.price)."
        case .investigate:
            return "There isn’t enough clean price history to call this one. Check the seller, the model number and the return policy before buying."
        }
    }

    private func money(_ value: Double) -> String { ChartFormat.money(value) }
}

// MARK: - Verdict hero

// The verdict on glass over the blue light: the product, the verdict word and symbol in the verdict
// colour, and the product summary as the reason. Adapted from Not Yet's `VerdictHero`.
private struct ThreadDetailHero: View {
    let product: Product
    @State private var popped = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: product.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityHidden(true)
                Text(product.name)
                    .textStyle(.caption)
                    .lineLimit(2)
                Spacer(minLength: 8)
                SampleDataTag()
            }
            .foregroundStyle(Color.white.opacity(0.82))

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: product.verdict.symbol)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(product.verdict.color)
                        .symbolEffect(.bounce, value: popped)
                        .accessibilityHidden(true)
                    Text(product.verdict.word)
                        .textStyle(.wordmark(size: 46))
                        .foregroundStyle(product.verdict.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .dropShadow(Shadows.labelOnBlue)
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
                    LinearGradient(colors: [Color(hex: 0x6B88FF, opacity: 0.6), Color.white.opacity(0.06)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.75
                )
        }
        .dropShadow(Shadows.heroPanel)
        .onAppear { popped = true }
    }
}

// The hero's blue light: dark navy at the top pooling into the blue family below, kept inside the panel.
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
                Color(hex: 0x060A2A), Color(hex: 0x080D36), Color(hex: 0x05082A),
                Color(hex: 0x10149E), Palette.ultramarine, Color(hex: 0x0A1BA8),
                Palette.electric, Palette.glow, Palette.iris,
            ]
        )
    }
}

// MARK: - Pieces

// A small heading over one part of the report.
struct ThreadDetailSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .textStyle(.section)
                .foregroundStyle(Palette.textTertiary)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
