// Target membership: app only.
// Filter chips, then Today / Last 7 days / Earlier, each a list card. A row reads at a glance:
// verdict (word and tile colour), price, product. The amber dot marks items re-checked daily.
import SwiftUI

struct HistoryView: View {
    enum Filter: Hashable, CaseIterable, Identifiable {
        case all, tracking, verdict(Verdict)

        // One chip per verdict the app knows, old backend and new.
        static let allCases: [Filter] = [.all, .tracking]
            + [Verdict.buyNow, .wait, .fakeDeal, .considerAlternative, .investigate].map(Filter.verdict)

        var id: Self { self }

        var title: String {
            switch self {
            case .all: "All"
            case .tracking: "Tracking"
            case .verdict(let v): v.word
            }
        }

        // `verdictKind` turns any string into a known verdict or `.unknown`, so a value this list
        // does not know still shows under All and Tracking.
        func includes(_ item: HistoryItem) -> Bool {
            switch self {
            case .all: true
            case .tracking: item.isTracking
            case .verdict(let v): item.verdictKind == v
            }
        }
    }

    private struct DaySection: Identifiable {
        let title: String
        let items: [HistoryItem]
        var id: String { title }
    }

    @EnvironmentObject var router: Router
    @State private var items: [HistoryItem] = []
    @State private var filter: Filter = .all
    @State private var newestFirst = true
    @State private var loading = true

    private var filtered: [HistoryItem] {
        let base = items.filter(filter.includes)
        return newestFirst ? base : base.reversed()
    }

    private var sections: [DaySection] {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: .now) ?? .now
        return [
            DaySection(title: "Today", items: filtered.filter { cal.isDateInToday($0.date) }),
            DaySection(title: "Last 7 days", items: filtered.filter { !cal.isDateInToday($0.date) && $0.date >= weekAgo }),
            DaySection(title: "Earlier", items: filtered.filter { $0.date < weekAgo }),
        ].filter { !$0.items.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenTitle("History")
                    filterBar.padding(.top, 12)
                    content
                        .animation(Motion.rise, value: filter)
                        .animation(Motion.rise, value: newestFirst)
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, 24)
            }
            .background { ScreenBackdrop() }
            .settingsButton()
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if loading && items.isEmpty {
            HoppingDots()
                .frame(maxWidth: .infinity)
                .padding(.top, 72)
        } else if filtered.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Palette.textTertiary)
                Text("Nothing here yet.")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 72)
            .transition(.opacity)
        } else {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(section.title).padding(.leading, 4)
                    FlatCard {
                        VStack(spacing: 0) {
                            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                                if index > 0 {
                                    // Inset to line up with the row text: padding 12 + tile 38 + gap 14.
                                    Hairline().padding(.leading, 64)
                                }
                                HistoryRow(item: item) { router.openKey = item.scanKey }
                            }
                        }
                    }
                }
                .padding(.top, 20)
                .transition(.rise)
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 4) {
            Menu {
                Picker("Sort", selection: $newestFirst) {
                    Text("Newest first").tag(true)
                    Text("Oldest first").tag(false)
                }
            } label: {
                RoundIcon(systemName: "line.3.horizontal.decrease")
            }
            .accessibilityLabel("Sort")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Filter.allCases) { f in
                        Chip(title: f.title, selected: filter == f) { filter = f }
                    }
                }
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        guard let fresh = try? await ScanAPI.fetchHistory() else { return }
        if items.isEmpty {
            // First arrival rises in; a refresh swaps in place.
            withAnimation(Motion.rise) { items = fresh }
        } else {
            items = fresh
        }
    }
}

struct HistoryRow: View {
    let item: HistoryItem
    let open: () -> Void
    @State private var trackedHere = false
    @State private var pressed = false

    private var tracking: Bool { item.isTracking || trackedHere }

    var body: some View {
        let verdict = item.verdictKind
        HStack(spacing: 0) {
            Button(action: open) {
                HStack(spacing: Spacing.rowIconToText) {
                    VerdictTile(symbol: Theme.productSymbol(item.productName), color: verdict.color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.productName ?? "Checking…")
                            .textStyle(.item)
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(verdict.word)
                                .font(.hiragino(.w6, size: TextStyle.caption.size, relativeTo: .caption))
                                .foregroundStyle(verdict.color)
                            if let retailer = item.retailer {
                                Text("·").foregroundStyle(Palette.textTertiary)
                                Text(retailer)
                                    .textStyle(.caption)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                        .lineLimit(1)
                        if tracking {
                            HStack(spacing: 6) {
                                Circle().fill(Theme.wait).frame(width: 6, height: 6)
                                Text(trackingLine)
                                    .textStyle(.footnote)
                                    .foregroundStyle(Theme.wait)
                            }
                        }
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 4) {
                        if let price = item.currentPrice {
                            Text(Theme.money(price))
                                .font(.hiragino(.w6, size: 17, relativeTo: .body))
                                .monospacedDigit()
                                .foregroundStyle(Palette.textPrimary)
                        }
                        Text(timeLabel)
                            .textStyle(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                .padding(.leading, Spacing.rowHorizontal)
                .padding(.vertical, 12)
                .frame(minHeight: ControlHeight.row)
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(PressReportingStyle(isPressed: $pressed))

            Menu {
                Button("Open", action: open)
                if !tracking {
                    Button("Track this price") {
                        Task {
                            try? await ScanAPI.saveToWishlist(key: item.scanKey)
                            trackedHere = true
                        }
                    }
                }
                if let one = item.oneLiner, let name = item.productName {
                    ShareLink(item: "\(name): \(one)")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
                    .frame(width: 40, height: ControlHeight.minTouch)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More")
        }
        // The whole row lights while its main area is pressed.
        .background { ListRowPressedFill(isPressed: pressed) }
        .animation(Motion.hover, value: pressed)
        .animation(Motion.valueChange, value: trackedHere)
    }

    private var trackingLine: String {
        if item.dropped == true { return "Price dropped" }
        if let d = Theme.day(item.needBy) {
            return "Daily until \(d.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return "Daily"
    }

    // Rows are already grouped by day, so today's rows show the time and older rows the date.
    private var timeLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(item.date) {
            return item.date.formatted(date: .omitted, time: .shortened)
        }
        if cal.isDate(item.date, equalTo: .now, toGranularity: .year) {
            return item.date.formatted(.dateTime.month(.abbreviated).day())
        }
        return item.date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}

// The product symbol on a tile tinted with the verdict colour.
private struct VerdictTile: View {
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

// Passes the button's pressed state out, so the row's fill can cover the menu area too.
private struct PressReportingStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .onChange(of: configuration.isPressed) { _, pressed in isPressed = pressed }
    }
}

#Preview {
    ScrollView {
        FlatCard {
            VStack(spacing: 0) {
                ForEach(SampleData.history) { HistoryRow(item: $0) {} }
            }
        }
        .padding()
    }
    .background { ScreenBackdrop() }
    .preferredColorScheme(.dark)
}
