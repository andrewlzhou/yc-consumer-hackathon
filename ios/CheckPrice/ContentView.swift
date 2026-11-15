import SwiftUI

// The root: three tabs and the report sheet. Launch arguments for screenshots and cloud devices:
// `-startTab home|watchlist|setup` opens on that tab, `-autoReveal YES` runs Home's capture →
// analyzing → reveal demo on launch, and `-openReport YES` opens the report sheet on launch.
struct ContentView: View {
    @State private var tab = ContentView.startTab
    @State private var report = UserDefaults.standard.bool(forKey: "openReport")
    @State private var autoReveal = UserDefaults.standard.bool(forKey: "autoReveal")

    private static var startTab: Int {
        switch UserDefaults.standard.string(forKey: "startTab") {
        case "watchlist": 1
        case "setup": 2
        default: 0
        }
    }

    var body: some View {
        ZStack {
            AppColor.ink.ignoresSafeArea()
            Group {
                if tab == 0 { HomeView(report: $report, autoReveal: $autoReveal) }
                else if tab == 1 { WatchlistView(report: $report) }
                else { SetupView() }
            }
            .padding(.horizontal, 20).padding(.top, 12)
        }
        .safeAreaInset(edge: .bottom) { TabBar(tab: $tab).padding(.horizontal, 20).padding(.bottom, 8).background(AppColor.ink.opacity(0.95)) }
        .sheet(isPresented: $report) { ReportView(product: Demo.headphones).presentationDragIndicator(.visible).presentationBackground(AppColor.ink) }
        .preferredColorScheme(.dark)
    }
}
