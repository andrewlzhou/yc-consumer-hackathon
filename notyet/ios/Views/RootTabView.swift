// Target membership: app only.
// Home, History, Account, plus the round search button at the end (drawn by iOS, so it stays round).
import SwiftUI

enum AppTab: String, Hashable { case home, history, account, search }

struct RootTabView: View {
    // For screenshots: launch with `-startTab history` (or account, search) to open on that tab.
    @State private var tab: AppTab = AppTab(rawValue: UserDefaults.standard.string(forKey: "startTab") ?? "") ?? .home

    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house", value: AppTab.home) { HomeView() }
            Tab("History", systemImage: "clock.arrow.circlepath", value: AppTab.history) { HistoryView() }
            Tab("Account", systemImage: "person", value: AppTab.account) { AccountView() }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) { SearchView() }
        }
        .tint(Theme.prussianLight)
        .preferredColorScheme(.dark)
    }
}

#Preview("Whole app, sample data") {
    RootTabView().environmentObject(Router.shared)
}
