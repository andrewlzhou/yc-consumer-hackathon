// One thread: the report about the purchase, a row with the check's time plus heart and save, then
// the chat, with the input bar pinned to the bottom. Heart and save sit in the content (not the
// navigation bar), so they show both when pushed from Threads and when Home presents it as a sheet.
import SwiftUI

struct ThreadDetailView: View {
    let threadID: UUID
    @Environment(ThreadStore.self) private var store
    @State private var draft = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Screenshot runs start fully shown so nothing is caught mid-animation.
    @State private var revealed = ProcessInfo.processInfo.arguments.contains("-screenshots")

    private static let bottomID = "thread-detail-bottom"

    var body: some View {
        Group {
            if let thread = store.thread(threadID) {
                content(thread)
            } else {
                missing
            }
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func content(_ thread: ShoppingThread) -> some View {
        let isReplying = store.replyingIn == thread.id
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ThreadDetailReport(product: thread.product, revealed: revealed)
                    ThreadDetailActions(thread: thread,
                                        onHeart: { store.toggleHeart(thread.id) },
                                        onSave: { store.toggleSave(thread.id) })
                        .modifier(ThreadDetailArrive(index: 4, revealed: revealed, reduceMotion: reduceMotion))
                    ChatColumn(
                        messages: thread.messages,
                        isReplying: isReplying,
                        onGrow: { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                    )
                    .modifier(ThreadDetailArrive(index: 5, revealed: revealed, reduceMotion: reduceMotion))
                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.top, 20)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ChatInputBar(text: $draft, isReplying: isReplying) { store.send($0, in: thread.id) }
                    .padding(.horizontal, Spacing.screenMargin)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background {
                        // Content fades out under the bar instead of meeting it at a hard edge.
                        LinearGradient(colors: [Palette.canvas.opacity(0), Palette.canvas], startPoint: .top, endPoint: .center)
                            .ignoresSafeArea()
                    }
            }
            .onChange(of: thread.messages.count) { scrollToNewest(proxy) }
            .onChange(of: isReplying) { scrollToNewest(proxy) }
            .onAppear { revealed = true }
        }
    }

    private func scrollToNewest(_ proxy: ScrollViewProxy) {
        // After the new row is laid out.
        DispatchQueue.main.async {
            withAnimation(Motion.rise) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
        }
    }

    private var missing: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.hiragino(.w3, size: 22))
                .foregroundStyle(Palette.textTertiary)
            Text("This thread is no longer here.")
                .textStyle(.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 72)
    }
}

// When the check happened, then heart (a favourite) and save.
private struct ThreadDetailActions: View {
    let thread: ShoppingThread
    let onHeart: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(thread.startedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                .textStyle(.footnote)
                .monospacedDigit()
                .foregroundStyle(Palette.textTertiary)
            Spacer(minLength: 8)
            heartButton
            saveButton
        }
    }

    private var heartButton: some View {
        Button(action: onHeart) {
            Image(systemName: thread.isHearted ? "heart.fill" : "heart")
                .font(.hiragino(.w6, size: 15))
                .foregroundStyle(.white.opacity(thread.isHearted ? 0.94 : 0.6))
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: thread.isHearted)
                .frame(width: ControlHeight.smallKey, height: ControlHeight.smallKey)
                .background { Circle().fill(.white.opacity(thread.isHearted ? 0.22 : 0.07)) }
                .overlay { Circle().strokeBorder(.white.opacity(thread.isHearted ? 0.24 : 0.12), lineWidth: 1) }
                .scaleEffect(thread.isHearted ? 1.08 : 1)
                .frame(width: ControlHeight.minTouch, height: ControlHeight.minTouch)
                .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .animation(Motion.appear, value: thread.isHearted)
        .sensoryFeedback(.impact(weight: .light), trigger: thread.isHearted)
        .accessibilityLabel(thread.isHearted ? "Remove heart" : "Heart")
    }

    private var saveButton: some View {
        Button(action: onSave) {
            HStack(spacing: 6) {
                Image(systemName: thread.isSaved ? "bookmark.fill" : "bookmark")
                    .font(.hiragino(.w6, size: 12))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: thread.isSaved)
                Text(thread.isSaved ? "Saved" : "Save")
                    .textStyle(.smallButton)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            .foregroundStyle(thread.isSaved ? Palette.textPrimary : Palette.textSecondary)
            .padding(.horizontal, 14)
            .frame(height: ControlHeight.smallKey)
            .background { Capsule().fill(.white.opacity(thread.isSaved ? 0.22 : 0.07)) }
            .overlay { Capsule().strokeBorder(.white.opacity(thread.isSaved ? 0.24 : 0.12), lineWidth: 1) }
            .frame(height: ControlHeight.minTouch)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .animation(Motion.appear, value: thread.isSaved)
        .sensoryFeedback(.success, trigger: thread.isSaved) { _, new in new }
        .accessibilityLabel(thread.isSaved ? "Unsave" : "Save")
    }
}
