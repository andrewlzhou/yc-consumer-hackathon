import SwiftUI

// The root: three tabs (Home, Threads, Account), icons only, and the thread detail sheet. The bar's
// look lives in `Components/TabBar.swift`. Each tab sits on `ScreenBackdrop`, so screens draw no backdrop
// of their own. Any screen opens a thread by setting `ThreadStore.openThreadID`; this view
// presents it and clears it on dismiss.
//
// Launch arguments for screenshots and cloud devices: `-startTab home|threads|account` opens on
// that tab, `-autoReveal YES` runs Home's capture → analyzing → reveal demo on launch, and
// `-openThread YES` opens the newest thread's detail on launch.
struct ContentView: View {
    @Environment(ThreadStore.self) private var store
    @State private var tab = AppTab(rawValue: UserDefaults.standard.string(forKey: "startTab") ?? "") ?? .home
    @State private var autoReveal = UserDefaults.standard.bool(forKey: "autoReveal")
    @State private var didHandleLaunch = false

    var body: some View {
        TabView(selection: $tab) {
            Tab(value: AppTab.home) {
                screen(HomeView(autoReveal: $autoReveal))
            } label: { label(.home) }
            Tab(value: AppTab.threads) {
                screen(ThreadsView())
            } label: { label(.threads) }
            Tab(value: AppTab.account) {
                screen(AccountView())
            } label: { label(.account) }
        }
        // Tint still reaches the screens (toolbar buttons, links); the bar's own colours are in TabBarStyle.
        .tint(Palette.glow)
        .sheet(item: openThread) { thread in
            ThreadDetailView(threadID: thread.id)
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.canvas)
        }
        .onAppear {
            guard !didHandleLaunch else { return }
            didHandleLaunch = true
            if UserDefaults.standard.bool(forKey: "openThread") { store.openThreadID = store.threads.first?.id }
        }
        .preferredColorScheme(.dark)
    }

    // Every tab sits on the backdrop and carries the hook that centres the bar's icons.
    private func screen(_ content: some View) -> some View {
        content
            .background { ScreenBackdrop() }
            .background { TabBarIconInsets(selection: tab).frame(width: 0, height: 0) }
    }

    // Icon only: the title is kept for VoiceOver and drawn clear by TabBarStyle. The system tab bar
    // fills every symbol by default; `.none` keeps the outline on tabs that aren't selected.
    private func label(_ item: AppTab) -> some View {
        Label {
            Text(item.title)
        } icon: {
            Image(systemName: item.symbol(selected: tab == item))
                .environment(\.symbolVariants, .none)
        }
    }

    // `.sheet(item:)` needs an Identifiable value; it keeps the detail on screen while it slides away.
    private struct OpenThread: Identifiable { let id: UUID }

    private var openThread: Binding<OpenThread?> {
        Binding(
            get: { store.openThreadID.map(OpenThread.init) },
            set: { store.openThreadID = $0?.id }
        )
    }
}
