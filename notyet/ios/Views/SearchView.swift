// Target membership: app only. Discover rows, and an "Ask" bar with a mic for voice.
import SwiftUI

struct SearchView: View {
    @EnvironmentObject var router: Router
    @StateObject private var voice = VoiceInput()
    @State private var query = ""
    @State private var asking = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Discover")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.slate)
                        .padding(.bottom, 6)
                    NavigationLink {
                        DiscoverListView(kind: "lowest", title: "Lowest prices")
                    } label: {
                        DiscoverRow(title: "Lowest prices", symbol: "arrow.down", tint: Theme.buy)
                    }
                    Hairline()
                    NavigationLink {
                        DiscoverListView(kind: "deals", title: "Best deals")
                    } label: {
                        DiscoverRow(title: "Best deals", symbol: "tag", tint: Theme.wait)
                    }
                    Hairline()
                    if failed {
                        Text("Try the exact model name.").foregroundStyle(Theme.fake).padding(.top, 12)
                    }
                }
                .padding(20)
            }
            .background(Theme.paper)
            .navigationTitle("Search")
            .settingsButton()
            .safeAreaInset(edge: .bottom) { askBar }
            .onChange(of: voice.transcript) { _, text in
                if !text.isEmpty { query = text }
            }
        }
    }

    private var askBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about any product", text: $query)
                .foregroundStyle(Theme.ink)
                .submitLabel(.search)
                .onSubmit { Task { await ask() } }
            if asking { ProgressView() }
            Button { voice.toggle() } label: {
                Image(systemName: voice.isListening ? "waveform" : "mic.fill")
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(voice.isListening ? Theme.prussianLight : Theme.prussian)
            }
            .accessibilityLabel(voice.isListening ? "Stop listening" : "Ask by voice")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .background(Theme.paper)
        .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func ask() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !asking else { return }
        if voice.isListening { voice.stop() }
        asking = true
        defer { asking = false }
        do {
            let quick = try await ScanAPI.ask(q)
            failed = false
            query = ""
            router.openKey = quick.scanKey
        } catch {
            failed = true
        }
    }
}

private struct DiscoverRow: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(Theme.prussian)
            Text(title).font(Theme.display(22)).foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.slate)
        }
        .padding(.vertical, 14)
    }
}

struct DiscoverListView: View {
    let kind: String
    let title: String
    @State private var items: [DiscoverItem] = []
    @State private var loading = true

    var body: some View {
        List {
            if loading && items.isEmpty {
                ProgressView().listRowBackground(Theme.paper)
            } else if items.isEmpty {
                Text("Nothing yet.").foregroundStyle(Theme.slate).listRowBackground(Theme.paper)
            }
            ForEach(items) { item in
                NavigationLink {
                    ProductReportView(result: item.result, scanKey: nil)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: Theme.productSymbol(item.result.product.name))
                            .frame(width: 36, height: 36)
                            .background(Theme.prussian)
                            .foregroundStyle(Theme.ink)
                        Text(item.result.product.name).font(.headline).foregroundStyle(Theme.ink).lineLimit(1)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Theme.money(item.result.currentPrice)).monospacedDigit().foregroundStyle(Theme.ink)
                            if item.discount > 0 {
                                Text("\(item.discount)% off usual").font(.caption).foregroundStyle(Theme.buy)
                            }
                        }
                    }
                }
                .listRowBackground(Theme.paper)
                .listRowSeparatorTint(Theme.hairline)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle(title)
        .task {
            items = (try? await ScanAPI.fetchDiscover(kind: kind)) ?? []
            loading = false
        }
    }
}

#Preview {
    SearchView().environmentObject(Router.shared).preferredColorScheme(.dark)
}
