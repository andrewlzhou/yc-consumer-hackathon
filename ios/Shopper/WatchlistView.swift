import ShopperKit
import SwiftUI

struct WatchlistView: View {
    @EnvironmentObject var model: AppModel
    @State private var items: [WatchItem] = []
    @State private var error: String?
    @State private var editing: WatchItem?

    var body: some View {
        NavigationStack {
            List {
                if let error { Text(error).foregroundStyle(.red) }
                if items.isEmpty && error == nil { Text("Nothing watched yet. Check a product, then tap Watch.").foregroundStyle(.secondary) }
                ForEach(items) { item in
                    NavigationLink { ReportView(productId: item.productId) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.titles[item.productId] ?? item.productId).font(.subheadline)
                            HStack {
                                if let verdict = item.lastVerdict { VerdictBadge(verdict: verdict).scaleEffect(0.8) }
                                if let price = item.lastPrice { Text(String(format: "$%.2f", price)) }
                                if let target = item.targetPrice { Text(String(format: "target $%.2f", target)).foregroundStyle(.secondary) }
                            }
                            .font(.caption)
                        }
                    }
                    .swipeActions {
                        Button("Remove", role: .destructive) { Task { await remove(item) } }
                        Button("Edit") { editing = item }
                    }
                }
            }
            .navigationTitle("Watchlist")
            .refreshable { await load() }
            .task { await load() }
            .sheet(item: $editing) { item in
                WatchEditor(item: item) { await load() }
            }
        }
    }

    private func load() async {
        do {
            items = try await model.client.watchlist()
            error = nil
        } catch let e as ShopperError {
            error = e.message
        } catch {
            self.error = ShopperError.network.message
        }
    }

    private func remove(_ item: WatchItem) async {
        do {
            try await model.client.remove(productId: item.productId)
            await load()
        } catch let e as ShopperError {
            error = e.message
        } catch {
            self.error = ShopperError.network.message
        }
    }
}

struct WatchEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let item: WatchItem
    let saved: () async -> Void
    @State private var target = ""
    @State private var prefs = WatchPrefs()
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Target price") {
                    TextField("e.g. 249.99 (empty = none)", text: $target).keyboardType(.decimalPad)
                }
                Section("Notify me about") {
                    Toggle("Target price reached", isOn: $prefs.target_hit)
                    Toggle("New low", isOn: $prefs.new_low)
                    Toggle("Verdict turns BUY NOW", isOn: $prefs.buy_now_flip)
                    Toggle("Sale starts", isOn: $prefs.sale_start)
                    Toggle("Better alternative", isOn: $prefs.better_alternative)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Edit watch")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } } }
            }
            .onAppear {
                target = item.targetPrice.map { String(format: "%.2f", $0) } ?? ""
                prefs = item.prefs ?? WatchPrefs()
            }
        }
    }

    private func save() async {
        let trimmed = target.trimmingCharacters(in: .whitespaces)
        let change: TargetPriceChange
        if trimmed.isEmpty {
            change = .clear
        } else if let value = Double(trimmed), value > 0 {
            change = .set(value)
        } else {
            error = "Enter a price like 249.99, or leave it empty."
            return
        }
        do {
            try await model.client.save(productId: item.productId, target: change, prefs: prefs)
            await saved()
            dismiss()
        } catch let e as ShopperError {
            error = e.message
        } catch {
            self.error = ShopperError.network.message
        }
    }
}
