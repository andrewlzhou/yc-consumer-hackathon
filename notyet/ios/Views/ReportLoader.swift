// Target membership: app only.
// Loads a scan by key. Shows a square scanner with "Digging…" until the report is ready.
import SwiftUI

struct ReportLoader: View {
    let key: String
    @State private var scan: ScanResponse?

    var body: some View {
        Group {
            if let result = scan?.result {
                ProductReportView(result: result, scanKey: key)
            } else if scan?.status == "error" {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.magnifyingglass").font(.system(size: 36)).foregroundStyle(Theme.slate)
                    Text(scan?.error == "No product found" ? "No product found" : "Couldn't finish this check")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Try the product page or the exact model name.")
                        .foregroundStyle(Theme.slate)
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DiggingView(step: scan?.step, quick: scan?.quick)
            }
        }
        .background(Theme.paper)
        .task(id: key) { await poll() }
    }

    private func poll() async {
        for _ in 0..<150 {
            if Task.isCancelled { return }
            if let s = try? await ScanAPI.fetchScan(key: key) {
                scan = s
                if s.status == "done" || s.status == "error" { return }
            }
            try? await Task.sleep(for: .seconds(2))
        }
    }
}

struct DiggingView: View {
    let step: String?
    let quick: QuickInfo?
    @State private var scanning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let size: CGFloat = 160

    var body: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .top) {
                Rectangle().stroke(Theme.hairline, lineWidth: 1)
                Rectangle()
                    .fill(LinearGradient(colors: [Theme.prussianLight.opacity(0), Theme.prussianLight.opacity(0.7)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: 36)
                    .offset(y: scanning ? size - 36 : 0)
                Image(systemName: "dollarsign")
                    .font(.title.bold())
                    .foregroundStyle(Theme.ink)
                    .frame(width: size, height: size)
            }
            .frame(width: size, height: size)
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { scanning = true }
            }
            Text("Digging…").font(Theme.display(28)).foregroundStyle(Theme.ink)
            Text(step ?? "Starting…").foregroundStyle(Theme.slate)
            if let one = quick?.oneLiner {
                Text(one).font(.headline).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Digging") {
    DiggingView(step: "Reading the price history…", quick: nil)
        .background(Theme.paper)
        .preferredColorScheme(.dark)
}
