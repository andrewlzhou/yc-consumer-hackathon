import ShopperKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var runs = TimingLog.load()

    var body: some View {
        NavigationStack {
            List {
                Section("Back Tap shortcut (one-time setup)") {
                    Text("1. Shortcuts > + > add Take Screenshot, then Check Price in Screenshot (Worth It).")
                    Text("2. Settings > Accessibility > Touch > Back Tap > Double Tap > pick that shortcut.")
                    Text("3. For links: in the shortcut's settings turn on Show in Share Sheet with Check Price of Link.")
                }
                .font(.footnote)
                Section("Backend") {
                    LabeledContent("Host", value: AppModel.config.baseURL.host() ?? "-")
                    LabeledContent("App key", value: model.hasKey ? "configured (debug build)" : "missing")
                    LabeledContent("Device id", value: model.deviceId).font(.caption)
                    Button("Use a new test device id") { model.newTestDevice() }
                }
                Section("On-device model") {
                    Text("Apple Foundation Models: \(ModelAssist.availability)").font(.footnote)
                }
                Section("Measured on this phone (last \(runs.count) checks)") {
                    timing("OCR", runs.filter { $0.source == "screenshot" }.map(\.times.ocr))
                    timing("Network", runs.map(\.times.network))
                    timing("Screenshot total", runs.filter { $0.source == "screenshot" }.map(\.times.total))
                    timing("Link total", runs.filter { $0.source == "link" }.map(\.times.total))
                    Button("Clear timings") { TimingLog.save([]); runs = [] }
                }
            }
            .navigationTitle("Setup")
            .onAppear { runs = TimingLog.load() }
        }
    }

    private func timing(_ name: String, _ values: [Double]) -> some View {
        let p50 = TimingLog.percentile(values, 0.5)
        let p95 = TimingLog.percentile(values, 0.95)
        return LabeledContent(name, value: p50.map { String(format: "p50 %.2fs · p95 %.2fs · n=%d", $0, p95 ?? $0, values.count) } ?? "no runs")
    }
}
