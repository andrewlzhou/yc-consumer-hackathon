import SwiftUI

@main
struct ShopperApp: App {
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                #if DEBUG
                .task { await DebugHook.runIfRequested(model) }
                #endif
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            CheckView().tabItem { Label("Check", systemImage: "tag") }
            WatchlistView().tabItem { Label("Watchlist", systemImage: "eye") }
            InboxView().tabItem { Label("Inbox", systemImage: "bell") }
            SettingsView().tabItem { Label("Setup", systemImage: "gearshape") }
        }
    }
}
