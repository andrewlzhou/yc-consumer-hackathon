import SwiftUI

@main
struct CheckPriceApp: App {
    init() {
        TabBarStyle.apply()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(ThreadStore.shared)
        }
    }
}
