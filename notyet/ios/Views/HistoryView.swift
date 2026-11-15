// Target membership: app only.
// Filters, then Today / Last 7 days / Earlier. The amber square marks items re-checked daily.
import SwiftUI

struct HistoryView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", tracking = "Tracking", buy = "Buy", wait = "Wait", fake = "Fake"
        var id: String { rawValue }
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
        let base = items.filter { item in
            switch filter {
            case .all: return true
            case .tracking: return item.isTracking
            case .buy: return item.verdict == "BUY_NOW"
            case .wait: return item.verdict == "WAIT"
            case .fake: return item.verdict == "FAKE_DEAL"
            }
        }
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
                    filterBar.padding(.bottom, 16)
                    if loading && items.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if filtered.isEmpty {
                        Text("Nothing here yet.").foregroundStyle(Theme.slate).padding(.top, 24)
                    } else {
                        ForEach(sections) { section in
                            Text(section.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.slate)
                                .padding(.top, 16)
                                .padding(.bottom, 6)
                            ForEach(section.items) { item in
                                HistoryRow(item: item) { router.openKey = item.scanKey }
                                Hairline()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Theme.paper)
            .navigationTitle("History")
            .settingsButton()
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Sort", selection: $newestFirst) {
                    Text("Newest first").tag(true)
                    Text("Oldest first").tag(false)
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .frame(width: 36, height: 36)
                    .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
                    .foregroundStyle(Theme.ink)
            }
            .accessibilityLabel("Sort")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Filter.allCases) { f in
                        Chip(title: f.rawValue, selected: filter == f) { filter = f }
                    }
                }
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        if let fresh = try? await ScanAPI.fetchHistory() { items = fresh }
    }
}

struct HistoryRow: View {
    let item: HistoryItem
    let open: () -> Void
    @State private var trackedHere = false

    private var tracking: Bool { item.isTracking || trackedHere }

    var body: some View {
        let style = VerdictStyle(item.verdict)
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.prussian).frame(width: 46, height: 46)
                    Rectangle().fill(style.color).frame(width: 3, height: 46)
                    Image(systemName: Theme.productSymbol(item.productName))
                        .font(.title3)
                        .foregroundStyle(Theme.ink)
                        .frame(width: 46, height: 46)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.productName ?? "Checking…")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(item.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year()))
                        .font(.subheadline)
                        .foregroundStyle(Theme.slate)
                    if tracking {
                        HStack(spacing: 6) {
                            Rectangle().fill(Theme.wait).frame(width: 6, height: 6)
                            Text(trackingLine).font(.caption).foregroundStyle(Theme.wait)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: open)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 14) {
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
                    Image(systemName: "ellipsis").padding(6).foregroundStyle(Theme.slate)
                }
                .accessibilityLabel("More")
                if let r = item.retailer { RetailerBadge(name: r) }
            }
        }
        .padding(.vertical, 12)
    }

    private var trackingLine: String {
        if item.dropped == true { return "Price dropped" }
        if let d = Theme.day(item.needBy) {
            return "Daily until \(d.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return "Daily"
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 0) { ForEach(SampleData.history) { HistoryRow(item: $0) {}; Hairline() } }.padding()
    }
    .background(Theme.paper)
    .preferredColorScheme(.dark)
}
