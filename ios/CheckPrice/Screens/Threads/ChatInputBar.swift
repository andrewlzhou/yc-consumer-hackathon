// The thread's input bar, as Search's ask bar draws it (worldscape F/CommandBar/ChatBar.swift): a
// blue capsule, 56pt for one line and growing to four, 17pt text, and a white arrow that is dim
// until there is something to send. While a reply is on its way the arrow stays dim.
import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isReplying: Bool
    let onSend: (String) -> Void
    @FocusState private var focused: Bool

    private static let font = Font.hiragino(.w4, size: 17, relativeTo: .body)
    private static let prompt = "Ask about this price"

    private var canSend: Bool {
        !isReplying && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            TextField(
                Self.prompt,
                text: $text,
                prompt: Text(Self.prompt).font(Self.font).foregroundStyle(.white.opacity(0.74)),
                axis: .vertical
            )
            .font(Self.font)
            .foregroundStyle(.white)
            .tint(.white)
            .lineLimit(1...4)
            .submitLabel(.send)
            .focused($focused)
            .onSubmit(send)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(Self.prompt)

            sendButton
        }
        .padding(.leading, 22)
        .padding(.trailing, 6)
        .frame(minHeight: ControlHeight.inputBar)
        .background { InputBarSurface() }
        .animation(Motion.layout, value: text)
        // A vertical field types a return instead of submitting; treat it as send.
        .onChange(of: text) { _, new in
            guard new.contains("\n") else { return }
            text = new.replacingOccurrences(of: "\n", with: " ")
            send()
        }
    }

    private var sendButton: some View {
        Button(action: send) {
            Image(systemName: "arrow.up")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white.opacity(canSend ? 1 : 0.6))
                .dropShadow(Shadows.sendArrow)
                .frame(width: ControlHeight.minTouch, height: ControlHeight.minTouch)
                .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .disabled(!canSend)
        .padding(.bottom, (ControlHeight.inputBar - ControlHeight.minTouch) / 2)
        .animation(Motion.hover, value: canSend)
        .accessibilityLabel("Send")
    }

    private func send() {
        guard canSend else { return }
        onSend(text)
        text = ""
    }
}
