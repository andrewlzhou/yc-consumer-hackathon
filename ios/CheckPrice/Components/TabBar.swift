// The tab bar: Home, Threads, Account, one row, no search tab, icons only (owner, 2026-11-15:
// "only the icons and no names under it"). It is the system tab bar dressed as Worldscape glass,
// the same as Not Yet's (`notyet/ios/Views/RootTabView.swift`): dark blur over the content, a
// faint top hairline, white icons at fixed opacities. No blue in the bar.
//
// VoiceOver still reads "Home", "Threads", "Account". Before iOS 26 each item keeps its title,
// drawn clear, and `TabBarItemHook` moves the icons down into the space it leaves. iOS 26's tab bar
// ignores the clear title colour, so there the items get no title at all (ContentView's labels are
// the image alone) and `TabBarItemHook` sets each item's spoken name instead.
import SwiftUI
import UIKit

enum AppTab: String, Hashable, CaseIterable {
    case home, threads, account

    // Spoken by VoiceOver only; never drawn.
    var title: String {
        switch self {
        case .home: "Home"
        case .threads: "Threads"
        case .account: "Account"
        }
    }

    // Outline when the tab is not selected, filled when it is. All exist on iOS 17 and later.
    func symbol(selected: Bool) -> String {
        switch self {
        case .home: selected ? "house.fill" : "house"
        case .threads: selected ? "bubble.left.and.text.bubble.right.fill" : "bubble.left.and.text.bubble.right"
        case .account: selected ? "person.crop.circle.fill" : "person.crop.circle"
        }
    }
}

enum TabBarStyle {
    // Before iOS 26: how far each icon moves down to sit in the middle of the bar once the title is
    // hidden, half the space UIKit keeps for the title. Not yet checked on a device or simulator.
    static let iconInsets = UIEdgeInsets(top: 6, left: 0, bottom: -6, right: 0)

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
        // Titles stay on the items for VoiceOver but are never seen.
        let hidden: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.clear]
        for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = normal
            item.normal.titleTextAttributes = hidden
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = hidden
        }

        let bar = UITabBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
    }
}

// Fixes up each UITabBarItem, which has no appearance proxy for these, by reaching the tab bar
// controller from inside a tab: the spoken name from `AppTab` (items are in `AppTab.allCases`
// order), and before iOS 26 `TabBarStyle.iconInsets`. It re-applies whenever the selection
// changes, after SwiftUI has updated the items.
struct TabBarItemHook: UIViewControllerRepresentable {
    let selection: AppTab

    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) { controller.apply() }

    final class Controller: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            apply()
        }

        func apply() {
            DispatchQueue.main.async { [weak self] in
                guard let items = self?.tabBarController?.tabBar.items else { return }
                for (item, tab) in zip(items, AppTab.allCases) {
                    item.accessibilityLabel = tab.title
                    if #unavailable(iOS 26) { item.imageInsets = TabBarStyle.iconInsets }
                }
            }
        }
    }
}
