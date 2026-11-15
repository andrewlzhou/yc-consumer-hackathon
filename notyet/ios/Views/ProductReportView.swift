// Target membership: app only.
// The report, in three parts: the verdict (hero glass on the blue light), the evidence behind it
// (prices against usual and lowest, the forecast range, the discount check, the chart, key facts,
// alternatives), then the actions (track until a need-by date, the store).
import SwiftUI
import UIKit
import UserNotifications

struct ProductReportView: View {
    let result: FullResult
    let scanKey: String?          // nil when opened from Discover

    @EnvironmentObject var router: Router
    @AppStorage("defaultNeedByDays") private var needByDays = 30
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    // The need-by date this item is saved with, if it is tracked ("YYYY-MM-DD").
    @State private var trackedNeedBy: String?
    @State private var saving = false
    @State private var saveFailed = false
    @State private var remindersOff = false
    @State private var checking = false
    @State private var checkFailed = false
    // Screenshot runs start fully shown so nothing is caught mid-animation.
    @State private var revealed = ProcessInfo.processInfo.arguments.contains("-screenshots")

    private struct NeedBy: Hashable { let label: String; let days: Int }
    private let needByChoices = [NeedBy(label: "1 week", days: 7), NeedBy(label: "2 weeks", days: 14),
                                 NeedBy(label: "1 month", days: 30), NeedBy(label: "3 months", days: 90)]

    private var verdict: Verdict { result.verdictKind }
    private var isSample: Bool { result.isSampleData ?? ScanAPI.useMocks }
    private var forecastDate: Date? { Theme.day(result.waitUntil ?? result.forecast?.byDate) }
    // One number for the chart's dashed projection: the backend's projection, else the middle of a range.
    private var projected: Double? {
        if let p = result.projectedPrice { return p }
        if let low = result.forecast?.low, let high = result.forecast?.high { return (low + high) / 2 }
        if let low = result.forecast?.low ?? result.forecast?.high { return low }
        return result.expectedPrice.map { ($0.low + $0.high) / 2 }
    }
    private var needByDate: Date { Calendar.current.date(byAdding: .day, value: needByDays, to: .now) ?? .now }
    private var needByString: String { Theme.dayString(needByDate) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VerdictHero(
                    verdict: verdict,
                    productName: result.product.name,
                    oneLiner: result.oneLiner,
                    confidence: result.confidence,
                    isSample: isSample,
                    matchNote: result.matchNote
                )
                .modifier(Arrive(index: 0, revealed: revealed, reduceMotion: reduceMotion))

                evidence
                    .modifier(Arrive(index: 1, revealed: revealed, reduceMotion: reduceMotion))

                actions
                    .modifier(Arrive(index: 2, revealed: revealed, reduceMotion: reduceMotion))

                footer
                    .modifier(Arrive(index: 3, revealed: revealed, reduceMotion: reduceMotion))
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        // Screenshot runs pass -scrollBottom to capture the lower half of the report.
        .defaultScrollAnchor(ProcessInfo.processInfo.arguments.contains("-scrollBottom") ? .bottom : .top)
        .background(Palette.canvas)
        .sensoryFeedback(.success, trigger: trackedNeedBy) { _, new in new != nil }
        .onAppear {
            if let scanKey { trackedNeedBy = TrackedStore.needBy(for: scanKey) }
            revealed = true
        }
    }

    // MARK: Evidence

    // Ordered so the strongest reason for this verdict comes first.
    @ViewBuilder private var evidence: some View {
        VStack(alignment: .leading, spacing: 28) {
            if verdict == .considerAlternative {
                alternativesSection
                priceSection
            } else {
                priceSection
            }
            chartSection
            factsSection
            if verdict != .considerAlternative {
                alternativesSection
            }
        }
    }

    private var priceSection: some View {
        ReportSection(title: "Price") {
            FlatCard {
                VStack(spacing: 0) {
                    nowRow
                    expectedRow
                    discountRow
                }
            }
        }
    }

    private var nowRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.whereToBuy.map { "Now at \($0.retailer)" } ?? "Now")
                    .textStyle(.item)
                    .foregroundStyle(Palette.textSecondary)
                if let vsUsual = usualDetail {
                    Text(vsUsual)
                        .textStyle(.footnote)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            Spacer(minLength: 12)
            Text(Theme.money(result.currentPrice))
                .textStyle(.wordmark(size: 34))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // Today's price against the usual one and the 12-month low (the chart shows both as marks):
    // "$30 under usual (16%) · lowest in a year" / "$50 above usual (8%)" / "The usual price".
    private var usualDetail: String? {
        var parts: [String] = []
        if let typical = result.typicalPrice, typical > 0 {
            let diff = result.currentPrice - typical
            let percent = Int((abs(diff) / typical * 100).rounded())
            if abs(diff) / typical < 0.01 {
                parts.append("The usual price")
            } else if diff < 0 {
                parts.append("\(Theme.money(-diff)) under usual (\(percent)%)")
            } else {
                parts.append("\(Theme.money(diff)) above usual (\(percent)%)")
            }
        }
        if let low = result.lowest?.price, result.currentPrice <= low + 0.5 {
            parts.append("lowest in a year")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // The forecast as a range with its date and confidence; falls back to the single projected number.
    @ViewBuilder private var expectedRow: some View {
        if let forecast = result.forecast, let value = rangeText(forecast) {
            Hairline()
            PriceRow(label: "Expected", detail: forecastDetail(forecast), value: value)
        } else if let projected {
            Hairline()
            PriceRow(
                label: "Expected",
                detail: forecastDate.map { "by \($0.formatted(.dateTime.month(.abbreviated).day()))" },
                value: Theme.money(projected)
            )
        }
    }

    private func rangeText(_ f: FullResult.Forecast) -> String? {
        switch (f.low, f.high) {
        case let (low?, high?) where abs(high - low) >= 1:
            return "\(Theme.money(min(low, high)))–\(Theme.money(max(low, high)))"
        case let (low?, _):
            return Theme.money(low)
        case (nil, let high?):
            return Theme.money(high)
        default:
            return nil
        }
    }

    private func forecastDetail(_ f: FullResult.Forecast) -> String? {
        var parts: [String] = []
        if let date = Theme.day(f.byDate) {
            parts.append("by \(date.formatted(.dateTime.month(.abbreviated).day()))")
        }
        if let event = f.eventName, !event.isEmpty { parts.append(event) }
        switch f.outlook {
        case "better_price_likely": parts.append("likely lower")
        case "better_price_possible": parts.append("may drop")
        case "no_better_price_expected": parts.append("unlikely to drop")
        default: break
        }
        if let save = f.savingsAtLow, save >= 1 {
            let percent = f.savingsAtLowPercent.map { " (\(Int($0.rounded()))%)" } ?? ""
            parts.append("save up to \(Theme.money(save))\(percent)")
        }
        if let c = f.confidence { parts.append("\(Int((min(max(c, 0), 1) * 100).rounded()))% confidence") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // Whether the advertised discount is real. Hidden when no discount was claimed.
    @ViewBuilder private var discountRow: some View {
        if let d = result.discount, let look = discountLook(d.status) {
            Hairline()
            PriceRow(label: "Discount", detail: discountDetail(d), value: look.word, valueColor: look.color)
        }
    }

    private func discountLook(_ status: String?) -> (word: String, color: Color)? {
        switch status {
        case "genuine": return ("Real", Verdict.buyNow.color)
        case "misleading": return ("Misleading", Verdict.fakeDeal.color)
        case "unclear": return ("Unclear", Verdict.wait.color)
        default: return nil
        }
    }

    private func discountDetail(_ d: FullResult.DiscountCheck) -> String? {
        var parts: [String] = []
        if let claimed = d.claimedDiscountPercent {
            let was = d.claimedWasPrice.map { " off \(Theme.money($0))" } ?? ""
            parts.append("Claims \(Int(claimed.rounded()))%\(was)")
        }
        if let real = d.realDiscountPercent {
            let r = Int(real.rounded())
            parts.append(r > 0 ? "really \(r)% under usual" : (r < 0 ? "really \(-r)% above usual" : "really the usual price"))
        }
        if let share = d.wasPriceChargedSharePercent, d.status != "genuine" {
            parts.append("was-price charged \(Int(share.rounded()))% of days")
        }
        if parts.isEmpty { return d.explanation }
        return parts.joined(separator: " · ")
    }

    private var chartSection: some View {
        ReportSection(title: "Last 12 months") {
            PriceChartView(result: result, projected: projected, projectedDate: forecastDate, accent: verdict.color)
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

    // The written summary, then the short facts behind the verdict.
    private var factsSection: some View {
        ReportSection(title: "Why") {
            VStack(alignment: .leading, spacing: 14) {
                if !result.tldr.isEmpty {
                    Text(result.tldr)
                        .textStyle(.body)
                        .lineSpacing(5)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array((result.keyFacts ?? []).prefix(5).enumerated()), id: \.offset) { _, fact in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle()
                            .fill(verdict.color)
                            .frame(width: 5, height: 5)
                            .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 4 }
                        Text(fact)
                            .textStyle(.item)
                            .lineSpacing(4)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder private var alternativesSection: some View {
        let options = (result.alternatives ?? []).filter { ($0.title ?? "").isEmpty == false }
        if !options.isEmpty {
            ReportSection(title: verdict == .considerAlternative ? "Better options" : "Alternatives") {
                FlatCard {
                    VStack(spacing: 0) {
                        ForEach(Array(options.prefix(3).enumerated()), id: \.offset) { index, option in
                            if index > 0 { Hairline() }
                            AlternativeRow(option: option)
                        }
                    }
                }
            }
        }
    }

    // MARK: Actions

    @ViewBuilder private var actions: some View {
        VStack(alignment: .leading, spacing: 28) {
            if verdict == .buyNow {
                storeSection
                trackSection
            } else {
                trackSection
                storeSection
            }
        }
    }

    // Buy now: the store is the blue key. Every other verdict: tracking is.
    private var storeIsPrimary: Bool { verdict == .buyNow && result.whereToBuy != nil }

    @ViewBuilder private var trackSection: some View {
        if let scanKey {
            ReportSection(title: "Need it by") {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(needByChoices, id: \.self) { choice in
                                Chip(title: choice.label, selected: needByDays == choice.days) { needByDays = choice.days }
                            }
                        }
                    }
                    trackButton(scanKey)
                    trackStatus
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    Task { await checkNow() }
                } label: {
                    Text("Check this for me")
                }
                .buttonStyle(KeyButtonStyle(tone: .primary, isWorking: checking))
                .disabled(checking)
                if checkFailed {
                    InlineNote(symbol: "exclamationmark.circle", text: "Couldn't start a check. Try again.", isError: true)
                }
            }
        }
    }

    @ViewBuilder private func trackButton(_ key: String) -> some View {
        let isCurrent = trackedNeedBy == needByString
        let button = Button {
            Task { await track(key) }
        } label: {
            Text(trackLabel)
        }
        .disabled(saving || isCurrent)
        .contextMenu {
            Button("Demo: remind me in 10 seconds") {
                Reminders.demoReminder(scanKey: key, productName: result.product.name, body: result.oneLiner)
            }
        }
        if storeIsPrimary {
            button.buttonStyle(QuietButtonStyle(height: ControlHeight.mainKey, isWorking: saving))
        } else {
            button.buttonStyle(KeyButtonStyle(tone: .primary, isWorking: saving))
        }
    }

    private var trackLabel: String {
        let date = needByDate.formatted(.dateTime.month(.abbreviated).day())
        guard let tracked = trackedNeedBy else { return "Track until \(date)" }
        if tracked == needByString {
            let saved = Theme.day(tracked)?.formatted(.dateTime.month(.abbreviated).day()) ?? date
            return "Tracking until \(saved)"
        }
        return "Change to \(date)"
    }

    // What happened after pressing track: the reminder date, a failed save, or reminders turned off.
    @ViewBuilder private var trackStatus: some View {
        if saveFailed {
            InlineNote(symbol: "wifi.exclamationmark", text: "Couldn't save. Check your connection and try again.", isError: true)
        } else if trackedNeedBy != nil {
            if remindersOff {
                HStack(spacing: 10) {
                    InlineNote(symbol: "bell.slash", text: "Reminders are off for Not Yet.", isError: false)
                    Spacer(minLength: 8)
                    Button("Turn on") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(KeyButtonStyle(tone: .secondary))
                }
            } else if let remind = Theme.day(reminderDay) {
                InlineNote(
                    symbol: "bell",
                    text: "Reminder \(remind.formatted(.dateTime.month(.abbreviated).day())), 9 AM. Prices checked daily.",
                    isError: false
                )
            }
        }
    }

    // Remind on the predicted best day if it lands before the need-by date, otherwise on the need-by date.
    private var reminderDay: String {
        let needBy = trackedNeedBy ?? needByString
        return result.waitUntil.flatMap { $0 <= needBy ? $0 : nil } ?? needBy
    }

    private func track(_ key: String) async {
        saving = true
        saveFailed = false
        defer { saving = false }
        let needBy = needByString
        do {
            try await ScanAPI.saveToWishlist(key: key, needBy: needBy)
        } catch {
            saveFailed = true
            return
        }
        TrackedStore.set(needBy, for: key)
        trackedNeedBy = needBy

        // Ask for notifications if never asked; say so if they are off.
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            await Reminders.requestPermission()
            status = await center.notificationSettings().authorizationStatus
        }
        remindersOff = status == .denied
        if !remindersOff {
            Reminders.scheduleBuyReminder(scanKey: key, productName: result.product.name,
                                          buyDate: reminderDay, body: result.oneLiner)
        }
    }

    private func checkNow() async {
        checking = true
        checkFailed = false
        defer { checking = false }
        do {
            let quick = try await ScanAPI.ask(result.product.name)
            router.openKey = quick.scanKey
        } catch {
            checkFailed = true
        }
    }

    @ViewBuilder private var storeSection: some View {
        if let store = result.whereToBuy {
            ReportSection(title: "Where to buy") {
                VStack(alignment: .leading, spacing: 12) {
                    FlatCard {
                        VStack(spacing: 0) {
                            PriceRow(label: store.retailer, detail: store.reason, value: Theme.money(store.totalCost))
                            if let rating = result.avgRating {
                                Hairline()
                                ratingRow(rating)
                            }
                        }
                    }
                    if let url = URL(string: store.url) {
                        if storeIsPrimary {
                            Link(destination: url) { Text("Open on \(store.retailer)") }
                                .buttonStyle(KeyButtonStyle(tone: .primary))
                        } else {
                            Link(destination: url) { Text("Open on \(store.retailer)") }
                                .buttonStyle(QuietButtonStyle(height: ControlHeight.mainKey))
                        }
                    }
                }
            }
        }
    }

    private func ratingRow(_ rating: Double) -> some View {
        HStack(spacing: 8) {
            Text("Reviews")
                .textStyle(.item)
                .foregroundStyle(Palette.textSecondary)
            Spacer(minLength: 8)
            StarsView(rating: rating)
            Text(String(format: "%.1f", rating))
                .textStyle(.item)
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
            if let count = result.reviewCount {
                Text("(\(count.formatted(.number.notation(.compactName))))")
                    .textStyle(.footnote)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: Footer

    // How the verdict was reached, the sample-data label, and whether more is still coming.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summaryLine)
                .textStyle(.footnote)
                .foregroundStyle(Palette.textTertiary)
            if result.reportPending == true {
                HStack(spacing: 8) {
                    HoppingDots(color: Palette.textTertiary)
                    Text("A fuller analysis is still running.")
                        .textStyle(.footnote)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            if isSample {
                Text("Built from sample data, not live prices.")
                    .textStyle(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryLine: String {
        let sources = result.sourcesChecked ?? max(result.history.count, 1)
        let years = result.yearsOfData ?? 0
        let span: String
        if years < 1 {
            let months = max(1, Int((years * 12).rounded()))
            span = months == 1 ? "a month" : "\(months) months"
        } else if years < 1.5 {
            span = "a year"
        } else {
            span = "\(Int(years.rounded())) years"
        }
        return "Searched \(sources) sources and \(span) of price history."
    }
}

// MARK: - Verdict hero

// The verdict on glass over the blue light: product, the verdict word and symbol in the verdict
// colour, the one-line reason, confidence, the sample-data label, and a note when the product match
// was a guess. With `isWorking` it shows the quick state (dots beside the word) so a loading screen
// can use the same panel and the report can replace it in place.
struct VerdictHero: View {
    let verdict: Verdict
    let productName: String?
    let oneLiner: String?
    var confidence: Double?
    var isSample: Bool = false
    var matchNote: String?
    var isWorking: Bool = false

    @State private var popped = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: Theme.productSymbol(productName))
                    .font(.system(size: 13, weight: .semibold))
                Text(productName ?? "Finding the product…")
                    .textStyle(.caption)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if isSample { SampleDataTag() }
            }
            .foregroundStyle(Color.white.opacity(0.82))

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: verdict.symbol)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(verdict.color)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: popped)
                        .accessibilityHidden(true)
                    Text(verdict.word)
                        .textStyle(.wordmark(size: 46))
                        .foregroundStyle(verdict.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .dropShadow(Shadows.labelOnBlue)
                    if isWorking {
                        HoppingDots(color: Palette.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Verdict: \(verdict.word)")

                if let oneLiner, !oneLiner.isEmpty {
                    Text(oneLiner)
                        .textStyle(.statement(size: 20))
                        .lineSpacing(6)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let confidence {
                    ConfidenceMeter(value: confidence, tint: verdict.color)
                        .padding(.top, 2)
                }
                if let matchNote, !matchNote.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 11, weight: .semibold))
                        Text(matchNote)
                            .textStyle(.footnote)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(.leading, Spacing.cardLeading)
            .padding(.trailing, Spacing.cardLeading)
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
        .animation(Motion.dotsToText, value: verdict)
        .animation(Motion.dotsToText, value: oneLiner)
    }
}

// The hero's blue light: dark navy at the top pooling into the blue family below. A local still mesh
// (rather than `BackdropGradient`, which ignores safe areas) so it stays inside the panel.
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
private struct ReportSection<Content: View>: View {
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

// One similar product: name, where and how similar, why, and how much it saves. Opens its page.
private struct AlternativeRow: View {
    let option: FullResult.Alternative

    var body: some View {
        if let link = option.url.flatMap(URL.init(string:)) {
            Link(destination: link) { content(showsChevron: true) }
                .buttonStyle(RowPressStyle())
        } else {
            content(showsChevron: false)
        }
    }

    private var subtitle: String? {
        var parts: [String] = []
        if let retailer = option.retailer { parts.append(retailer) }
        if let similar = option.similarityPercent { parts.append("\(Int(similar.rounded()))% similar") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func content(showsChevron: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(option.title ?? "")
                    .textStyle(.item)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle)
                        .textStyle(.footnote)
                        .foregroundStyle(Palette.textTertiary)
                }
                if let reasoning = option.reasoning, !reasoning.isEmpty {
                    Text(reasoning)
                        .textStyle(.caption)
                        .lineSpacing(3)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                if let price = option.price {
                    Text(Theme.money(price))
                        .textStyle(.cardTitle)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary)
                }
                if let save = option.savingsVsCurrent, save >= 1 {
                    Text("Save \(Theme.money(save))")
                        .textStyle(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(Verdict.buyNow.color)
                }
            }
            .fixedSize()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.top, 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// Rows in a flat card shade slightly while pressed.
private struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Palette.fillRowPressed : Color.clear)
            .animation(Motion.hover, value: configuration.isPressed)
    }
}

// One short line with an icon under an action: what happened, or what went wrong.
private struct InlineNote: View {
    let symbol: String
    let text: String
    let isError: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .textStyle(.caption)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(isError ? Palette.danger : Palette.textSecondary)
        .transition(.opacity)
    }
}

// Sections rise in one after another; under Reduce Motion they only fade.
private struct Arrive: ViewModifier {
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

// Which scans this phone has saved, and with what need-by date, so a tracked item reopens as tracked.
private enum TrackedStore {
    private static let key = "notyet.trackedNeedBy"

    static func needBy(for scanKey: String) -> String? {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String])?[scanKey]
    }

    static func set(_ needBy: String, for scanKey: String) {
        var all = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
        all[scanKey] = needBy
        UserDefaults.standard.set(all, forKey: key)
    }
}

#Preview("Wait") {
    ProductReportView(result: SampleData.report, scanKey: "preview")
        .environmentObject(Router.shared)
        .preferredColorScheme(.dark)
}

#Preview("Look around") {
    ProductReportView(result: SampleData.considerAlternative, scanKey: "preview-d")
        .environmentObject(Router.shared)
        .preferredColorScheme(.dark)
}
