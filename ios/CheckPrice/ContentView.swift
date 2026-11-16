import SwiftUI

// The root: three tabs (Home, Threads, Account), icons only, and the thread detail sheet. The bar's
// look lives in `Components/TabBar.swift`. Each tab sits on the app backdrop (`AppBackdrop`), so tab
// screens draw no background of their own. Any screen opens a thread by setting
// `ThreadStore.openThreadID`; this view presents it and clears it on dismiss.
//
// Launch arguments for screenshots and cloud devices: `-startTab home|threads|account` opens on
// that tab, and `-openThread YES` opens the newest thread's detail on launch.
struct ContentView: View {
    @Environment(ThreadStore.self) private var store
    @State private var tab = AppTab(rawValue: UserDefaults.standard.string(forKey: "startTab") ?? "") ?? .home
    @State private var didHandleLaunch = false

    var body: some View {
        TabView(selection: $tab) {
            Tab(value: AppTab.home) {
                screen(HomeView(showLibrary: { tab = .threads }))
            } label: { label(.home) }
            Tab(value: AppTab.threads) {
                screen(ThreadsView())
            } label: { label(.threads) }
            Tab(value: AppTab.account) {
                screen(AccountView())
            } label: { label(.account) }
        }
        // Tint reaches the screens (toolbar buttons, links). Neutral, so the orange accent stays rare;
        // the bar's own colours are in TabBarStyle.
        .tint(Palette.textPrimary)
        .sheet(item: openThread) { thread in
            ThreadDetailView(threadID: thread.id)
                .presentationDragIndicator(.visible)
                .presentationBackground { AppBackdrop() }
        }
        .onAppear {
            guard !didHandleLaunch else { return }
            didHandleLaunch = true
            if UserDefaults.standard.bool(forKey: "openThread") { store.openThreadID = store.threads.first?.id }
        }
        .preferredColorScheme(.dark)
    }

    // Every tab sits on the backdrop and carries the hook that fixes up the bar's items.
    private func screen(_ content: some View) -> some View {
        content
            .background { AppBackdrop() }
            .background { TabBarItemHook(selection: tab).frame(width: 0, height: 0) }
    }

    // Icon only. iOS 26's tab bar draws a title whenever the item has one, whatever its colour, so
    // there the label is the image alone and `TabBarItemHook` gives each item its spoken name.
    // Before iOS 26 the title stays on the item for VoiceOver and TabBarStyle draws it clear. The
    // system tab bar fills every symbol by default; `.none` keeps the outline on unselected tabs.
    @ViewBuilder private func label(_ item: AppTab) -> some View {
        let icon = Image(systemName: item.symbol(selected: tab == item))
            .environment(\.symbolVariants, .none)
        if #available(iOS 26, *) {
            icon.accessibilityLabel(item.title)
        } else {
            Label { Text(item.title) } icon: { icon }
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
