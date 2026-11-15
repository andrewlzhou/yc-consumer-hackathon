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
                // `-demoLiveActivity YES` plays the check's pop-up; see LiveActivity/CheckActivity.swift.
                .task { await CheckActivity.runDemoIfRequested() }
        }
    }
}
