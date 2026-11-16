// The thread's chat, Worldscape style (worldscape F/Chat/MessageColumn.swift): the shopper's
// messages on the right, replies on the left in flat bubbles. A new message rises in; while a reply
// is on its way, hopping dots wait in a reply bubble, and the reply then writes itself in behind a
// glow caret.
import SwiftUI

struct ChatColumn: View {
    let messages: [ChatMessage]
    let isReplying: Bool
    // Called as a streaming reply grows, so the screen can keep the newest line in view.
    var onGrow: () -> Void = {}

    // Messages already on screen; anything newer from the other side streams in.
    @State private var known: Set<UUID>?
    @State private var streamingID: UUID?
    @State private var shownWords = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.betweenMessages) {
            ForEach(messages) { message in
                row(message)
                    .id(message.id)
                    .transition(message.fromUser ? .rise : .opacity)
            }
            if isReplying {
                replyRow { HoppingDots(color: Palette.textSecondary) }
                    .transition(.asymmetric(insertion: AnyTransition.rise.animation(Motion.rise.delay(Motion.replyDelay)),
                                            removal: .identity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Motion.rise, value: messages.count)
        .animation(Motion.dotsToText, value: isReplying)
        .onAppear { if known == nil { known = Set(messages.map(\.id)) } }
        .onChange(of: messages.map(\.id)) { _, ids in
            let seen = known ?? []
            if let reply = messages.last(where: { !$0.fromUser && !seen.contains($0.id) }), !reduceMotion {
                shownWords = 0
                streamingID = reply.id
            }
            known = Set(ids)
        }
        .task(id: streamingID) { await stream() }
    }

    // MARK: Rows

    @ViewBuilder private func row(_ message: ChatMessage) -> some View {
        if message.fromUser {
            HStack(spacing: 0) {
                Spacer(minLength: 56)
                Bubble(isPerson: true) { messageText(message.text) }
            }
        } else {
            let isStreaming = message.id == streamingID
            replyRow {
                StreamingText(isStreaming ? Self.prefix(message.text, words: shownWords) : message.text, isStreaming: isStreaming)
                    .textStyle(.body)
                    .lineSpacing(5)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityLabel(message.text)
        }
    }

    private func replyRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            Bubble(isPerson: false, content: content)
            Spacer(minLength: 40)
        }
    }

    private func messageText(_ text: String) -> some View {
        Text(verbatim: text)
            .textStyle(.body)
            .lineSpacing(5)
            .foregroundStyle(Palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Streaming

    // Reveals the reply a word at a time, then drops the caret.
    private func stream() async {
        guard let id = streamingID, let text = messages.first(where: { $0.id == id })?.text else { return }
        let count = Self.words(in: text).count
        while shownWords < count {
            try? await Task.sleep(for: .milliseconds(45))
            if Task.isCancelled { return }
            shownWords += 1
            onGrow()
        }
        streamingID = nil
    }

    private static func words(in text: String) -> [Substring] {
        text.split(separator: " ", omittingEmptySubsequences: false)
    }

    private static func prefix(_ text: String, words count: Int) -> String {
        words(in: text).prefix(count).joined(separator: " ")
    }
}
