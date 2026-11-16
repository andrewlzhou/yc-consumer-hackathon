// Home: a dashboard (owner, 2026-11-15: "only a dashboard, without the animation"). No screen title;
// it opens on a round check button at the top right, then the cards: three counts, the Watchlist,
// and Recent checks. The layout follows the Truck page of Apple's Food Truck sample
// (`TruckView`): a scrolling stack of cards at even spacing, each card with its own header, and
// rows that push the item they show. The cards are in `HomeCards.swift`; the check is `CheckFlow`,
// shown in a sheet.
import PhotosUI
import SwiftUI

struct HomeView: View {
    // Set by the `-autoReveal YES` launch argument; runs the demo once, then clears.
    @Binding var autoReveal: Bool
    // Switches to the Threads tab, for Recent checks' "See all".
    let showLibrary: () -> Void
    @Environment(ThreadStore.self) private var store
    @State private var flow = CheckFlow()
    @State private var path: [UUID] = []
    @State private var screenshot: PhotosPickerItem?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    checkButton
                    if let failure = flow.failure {
                        FailureNote(message: failure, action: startCheck, onDismiss: { flow.failure = nil })
                    }
                    HomeSummaryRow(threads: store.threads, saved: store.saved)
                    if !store.saved.isEmpty {
                        HomeWatchlistCard(threads: store.saved, open: open)
                    }
                    if !store.threads.isEmpty {
                        HomeRecentChecksCard(threads: Array(store.threads.prefix(3)), open: open, seeAll: showLibrary)
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, 32)
            }
            // ContentView draws the backdrop behind every tab; keep the stack see-through.
            .containerBackground(.clear, for: .navigation)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { ThreadDetailView(threadID: $0) }
        }
        .photosPicker(isPresented: $flow.pickingScreenshot, selection: $screenshot, matching: .screenshots)
        .onChange(of: screenshot) { _, item in
            guard let item else { return }
            screenshot = nil
            Task { await flow.checkScreenshot(item, store: store) }
        }
        .sheet(isPresented: sheetShown) {
            CheckSheet(flow: flow, openDetails: openCheckedThread)
                .presentationDragIndicator(.visible)
                .presentationBackground { AppBackdrop() }
        }
        .onAppear {
            if autoReveal { autoReveal = false; flow.startDemo(store: store) }
        }
    }

    // The only way into a check from the app: a small round button, top right.
    private var checkButton: some View {
        HStack {
            Spacer()
            Button(action: startCheck) {
                RoundIcon(systemName: "plus")
            }
            .buttonStyle(IconPressStyle())
            .accessibilityLabel("Check a price")
        }
        .padding(.trailing, -(ControlHeight.minTouch - ControlHeight.smallKey) / 2)
    }

    private var sheetShown: Binding<Bool> {
        Binding(get: { flow.phase != nil }, set: { if !$0 { flow.phase = nil } })
    }

    private func startCheck() { flow.start(store: store) }

    private func open(_ id: UUID) { path.append(id) }

    // Details closes the sheet and pushes the new thread onto Home's stack.
    private func openCheckedThread() {
        flow.phase = nil
        if let id = flow.threadID { path.append(id) }
    }
}
