// The Threads tab: one thread per time the app was triggered while shopping, newest first, grouped
// Today / This week / Earlier. Chips filter to All / Hearted / Saved; there is no search (the owner
// leaves that to a general agent). Swipe right to heart, left to save (watch the price), or
// long-press for both. Tapping a row opens ThreadDetailView. It is a List rather than Not Yet's
// ScrollView of FlatCards because swipe actions only exist on List rows; the rows carry the
// FlatCard fill and Worldscape dividers.
import SwiftUI

struct ThreadsView: View {
    @Environment(ThreadStore.self) private var store
    @State private var filter: ThreadsListFilter = .all
    @State private var path: [UUID] = []

    private var sections: [ThreadsListSection] {
        ThreadsListSection.group(store.threads.filter(filter.includes))
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                header
                if sections.isEmpty {
                    emptyState
                } else {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.threads) { thread in
                                row(thread)
                            }
                        } header: {
                            SectionLabel(section.title)
                                .textCase(nil)
                                .padding(.leading, 4)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(20)
            .environment(\.defaultMinListRowHeight, ControlHeight.row)
            .contentMargins(.horizontal, Spacing.screenMargin, for: .scrollContent)
            .scrollContentBackground(.hidden)
            // ContentView draws the backdrop behind every tab; keep the stack see-through.
            .containerBackground(.clear, for: .navigation)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { ThreadDetailView(threadID: $0) }
        }
    }

    // Title and chips sit in the content, as the first unstyled row, so they scroll with the list.
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenTitle("Threads")
            HStack(spacing: 8) {
                ForEach(ThreadsListFilter.allCases) { f in
                    Chip(title: f.title, selected: filter == f) {
                        withAnimation(Motion.rise) { filter = f }
                    }
                }
            }
        }
        .padding(.top, 8)
        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func row(_ thread: ShoppingThread) -> some View {
        ThreadsListRow(thread: thread) { path.append(thread.id) }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Palette.fillCard)
            .listRowSeparatorTint(Palette.divider)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button { toggleHeart(thread) } label: { heartLabel(thread) }
                    .tint(Palette.iris)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button { toggleSave(thread) } label: { saveLabel(thread) }
                    .tint(Palette.electric)
            }
            .contextMenu {
                Button { path.append(thread.id) } label: { Label("Open", systemImage: "arrow.up.right") }
                Button { toggleHeart(thread) } label: { heartLabel(thread) }
                Button { toggleSave(thread) } label: { saveLabel(thread) }
            }
    }

    private func heartLabel(_ thread: ShoppingThread) -> some View {
        Label(thread.isHearted ? "Unheart" : "Heart", systemImage: thread.isHearted ? "heart.slash" : "heart")
    }

    private func saveLabel(_ thread: ShoppingThread) -> some View {
        Label(thread.isSaved ? "Stop watching price" : "Save and watch price", systemImage: thread.isSaved ? "bookmark.slash" : "bookmark")
    }

    // Under a Hearted or Saved filter the row leaves the list, so the change animates.
    private func toggleHeart(_ thread: ShoppingThread) {
        withAnimation(Motion.rise) { store.toggleHeart(thread.id) }
    }

    private func toggleSave(_ thread: ShoppingThread) {
        withAnimation(Motion.rise) { store.toggleSave(thread.id) }
    }

    // Worldscape's empty list: a 22pt light symbol in tertiary and one caption line, 72pt down.
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: filter.emptySymbol)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Palette.textTertiary)
            Text(filter.emptyLine)
                .textStyle(.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 72)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .transition(.opacity)
    }
}

