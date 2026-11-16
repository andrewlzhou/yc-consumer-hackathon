// Target membership: app only.
// Home, History, Account, plus the search tab at the end (iOS draws its placement).
// The system tab bar is dressed as Worldscape glass: dark blur over the content, a faint top
// hairline, white icons at fixed opacities and Hiragino labels. No blue in the bar.
import SwiftUI
import UIKit

enum AppTab: String, Hashable { case home, history, account, search }

struct RootTabView: View {
    // For screenshots: launch with `-startTab history` (or account, search) to open on that tab.
    @State private var tab: AppTab = AppTab(rawValue: UserDefaults.standard.string(forKey: "startTab") ?? "") ?? .home

    init() {
        Self.styleTabBar()
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house", value: AppTab.home) { HomeView() }
            Tab("History", systemImage: "clock.arrow.circlepath", value: AppTab.history) { HistoryView() }
            Tab("Account", systemImage: "person", value: AppTab.account) { AccountView() }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) { SearchView() }
        }
        // Tint still reaches the screens (toolbar buttons, links); the bar's own colours are set below.
        .tint(Theme.prussianLight)
        .preferredColorScheme(.dark)
    }

    // UIKit appearance, applied before the TabView builds its bar. Same look at rest and when
    // content scrolls under, so the glass never disappears.
    @MainActor private static func styleTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor(red: 1 / 255, green: 1 / 255, blue: 1 / 255, alpha: 0.55)
        appearance.shadowColor = UIColor(white: 1, alpha: 0.08)

        let normal = UIColor(white: 1, alpha: 0.36)
        let selected = UIColor(white: 1, alpha: 0.94)
        let font = UIFont(name: "HiraginoSans-W5", size: 10)
            ?? UIFont(name: "HiraginoSans-W6", size: 10)
            ?? UIFont.systemFont(ofSize: 10, weight: .medium)
        for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = normal
            item.normal.titleTextAttributes = [.foregroundColor: normal, .font: font]
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [.foregroundColor: selected, .font: font]
        }

        let bar = UITabBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
    }
}

#Preview("Whole app, sample data") {
    RootTabView().environmentObject(Router.shared)
}
