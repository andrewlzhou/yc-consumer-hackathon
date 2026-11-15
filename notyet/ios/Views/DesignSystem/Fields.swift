// Target membership: app only.
// Text fields as a hairline outline with nothing filled in, so only keys look raised
// (worldscape DS/LabeledField.swift). No focus or error highlight: the caret shows focus, and
// a message beside the field explains problems.
import SwiftUI

struct OutlinedField: View {
    // Label above the box, in secondary text. Nil for no label.
    var title: String?
    let prompt: String
    @Binding var text: String
    var isSecure = false
    @FocusState private var isFocused: Bool

    init(_ title: String? = nil, prompt: String, text: Binding<String>, isSecure: Bool = false) {
        self.title = title
        self.prompt = prompt
        self._text = text
        self.isSecure = isSecure
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.labelToField) {
            if let title {
                Text(title)
                    .textStyle(.label)
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityHidden(true)
            }

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(prompt)
                        .font(TextStyle.body.font)
                        .tracking(isSecure ? 4.5 : TextStyle.body.tracking)
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(1)
                        .accessibilityHidden(true)
                }
                input
                    .textFieldStyle(.plain)
                    .textStyle(.body)
                    .foregroundStyle(Palette.textPrimary)
                    .tint(Palette.glow)
                    .focused($isFocused)
            }
            .padding(.horizontal, Spacing.fieldHorizontal)
            .frame(height: ControlHeight.field)
            .background { FieldBorder() }
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
        }
    }

    @ViewBuilder private var input: some View {
        if isSecure {
            SecureField(title ?? prompt, text: $text, prompt: Text(""))
        } else {
            TextField(title ?? prompt, text: $text, prompt: Text(""))
        }
    }
}

// The outline every field and field-like control draws: 1pt white 16%, brighter while pressed,
// or glow blue while highlighted (for example a search match).
struct FieldBorder: View {
    var isPressed = false
    var isHighlighted = false
    var cornerRadius: CGFloat = Radius.field

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(color, lineWidth: 1)
    }

    private var color: Color {
        if isHighlighted { return Palette.glow }
        return isPressed ? Palette.strokeHover : Palette.stroke
    }
}
