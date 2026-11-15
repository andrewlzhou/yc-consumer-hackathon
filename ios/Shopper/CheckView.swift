import PhotosUI
import ShopperKit
import SwiftUI

struct CheckView: View {
    @EnvironmentObject var model: AppModel
    @State private var link = ""
    @State private var picked: PhotosPickerItem?
    @State private var busy = false
    @State private var watchMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Store link") {
                    TextField("https://www.bestbuy.com/site/...", text: $link)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    Button("Check link") { Task { await checkLink() } }
                        .disabled(busy || URL(string: link)?.scheme?.hasPrefix("http") != true)
                }
                Section("Screenshot (in-app test of the same pipeline)") {
                    PhotosPicker("Pick a screenshot", selection: $picked, matching: .screenshots)
                }
                if busy { ProgressView("Checking...") }
                if let outcome = model.lastScan {
                    Section("Result") {
                        ResultCard(outcome: outcome)
                        if let id = outcome.response?.productId {
                            NavigationLink("Full report") { ReportView(productId: id) }
                            Button("Watch this product") { Task { await watch(id) } }
                        }
                        if let watchMessage { Text(watchMessage).font(.footnote) }
                    }
                }
            }
            .navigationTitle("Worth It?")
            .onChange(of: picked) { _, item in
                guard let item else { return }
                Task { await checkScreenshot(item) }
            }
        }
    }

    private func checkLink() async {
        guard let url = URL(string: link.trimmingCharacters(in: .whitespaces)) else { return }
        busy = true
        model.remember(await ScanPipeline.run(url: url, deviceId: model.deviceId))
        busy = false
    }

    private func checkScreenshot(_ item: PhotosPickerItem) async {
        busy = true
        defer { busy = false; picked = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        model.remember(await ScanPipeline.run(imageData: data, deviceId: model.deviceId))
    }

    private func watch(_ productId: String) async {
        do {
            try await model.client.save(productId: productId)
            watchMessage = "Saved to your watchlist."
        } catch let error as ShopperError {
            watchMessage = error.message
        } catch {
            watchMessage = ShopperError.network.message
        }
    }
}

struct VerdictBadge: View {
    let verdict: Verdict

    var color: Color {
        switch verdict {
        case .buyNow: .green
        case .wait: .orange
        case .considerAlternative: .blue
        case .investigate: .gray
        }
    }

    var body: some View {
        Text(verdict.label)
            .font(.headline)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
}

struct ResultCard: View {
    let outcome: ScanOutcome

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let response = outcome.response {
                VerdictBadge(verdict: response.verdict)
                if let title = response.matchedTitle { Text("We think this is: \(title)").font(.subheadline) }
                Text(response.reason)
                HStack {
                    Text("Confidence \(Int((response.confidence * 100).rounded()))%")
                    if response.isSampleData { Text("Sample data").foregroundStyle(.orange) }
                }
                .font(.caption)
            } else {
                Text(outcome.error?.message ?? ShopperError.noProduct.message)
            }
            let e = outcome.extract
            if e.title != nil || e.currentPrice != nil {
                Text("Read on device: \(e.title ?? "no title") · \(e.currentPrice.map { String(format: "$%.2f", $0) } ?? "no price")\(e.originalPrice.map { String(format: " (was $%.2f)", $0) } ?? "")\(e.retailer.map { " · " + $0 } ?? "")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(String(format: "OCR %.2fs · model %.2fs · network %.2fs · total %.2fs", outcome.times.ocr, outcome.times.model, outcome.times.network, outcome.times.total))
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}
