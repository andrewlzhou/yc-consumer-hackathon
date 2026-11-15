// The tab bar: Home, Threads, Account, one row, no search tab. It is the system tab bar dressed
// as Worldscape glass, the same as Not Yet's (`notyet/ios/Views/RootTabView.swift`): dark blur
// over the content, a faint top hairline, white icons at fixed opacities and Hiragino labels.
// No blue in the bar.
import SwiftUI
import UIKit

enum AppTab: String, Hashable, CaseIterable {
    case home, threads, account

    var title: String {
        switch self {
        case .home: "Home"
        case .threads: "Threads"
        case .account: "Account"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .threads: "bubble.left.and.bubble.right"
        case .account: "person"
        }
    }
}

enum TabBarStyle {
    // UIKit appearance; call before the TabView builds its bar (`CheckPriceApp.init`). Same look
    // at rest and when content scrolls under, so the glass never disappears.
    @MainActor static func apply() {
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
