// The Settings page's pieces (Account tab): section, card, rows and the pushed choice list. Kept
// here rather than in DesignSystem/ because only Settings uses them.
import SwiftUI

// A muted label over a card of rows. With no title, only the spacing above separates it.
struct SettingsSection<Content: View>: View {
    var title: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .textStyle(.label)
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, SettingsMetrics.horizontal)
            }
            SettingsCard { content }
        }
        .padding(.top, 32)
    }
}

// The cards' look: warm grey a step lighter than the bar fill so it reads over the backdrop's
// gradient, large corners, no border or shadow.
enum SettingsSurface {
    static let fill = Color.white.opacity(0.08)
    static let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
}

enum SettingsMetrics {
    static let horizontal = Spacing.cardLeading
    static let symbolWidth: CGFloat = 24
    static let labelLeading = horizontal + symbolWidth + Spacing.rowIconToText
    static let rowHeight: CGFloat = 52
}

// A grouped card of rows, clipped so a pressed row's fill keeps the card's corners.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(SettingsSurface.fill)
            .clipShape(SettingsSurface.shape)
    }
}

// The profile card's press: the whole card dims slightly while held.
struct SettingsCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(SettingsSurface.shape)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(Motion.hover, value: configuration.isPressed)
    }
}

// A row that opens something: a light fill while held.
struct SettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(configuration.isPressed ? Palette.fillRowPressed : Color.clear)
            .animation(Motion.hover, value: configuration.isPressed)
    }
}

// The line between rows, starting where the row labels start rather than at the symbols.
struct SettingsSeparator: View {
    var body: some View {
        Hairline().padding(.leading, SettingsMetrics.labelLeading)
    }
}

struct SettingsChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.textTertiary)
            .accessibilityHidden(true)
    }
}

// The thin outline symbol and label every row starts with.
struct SettingsLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: Spacing.rowIconToText) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: SettingsMetrics.symbolWidth)
                .accessibilityHidden(true)
            Text(title)
                .textStyle(.body)
                .foregroundStyle(Palette.textPrimary)
        }
    }
}

// One row: symbol, label, an optional value on the right, and a chevron when it opens something.
struct SettingsRow: View {
    let title: String
    let symbol: String
    var value: String?
    var opens = false

    var body: some View {
        HStack(spacing: Spacing.rowIconToText) {
            SettingsLabel(title: title, symbol: symbol)
            Spacer(minLength: 8)
            if let value, !value.isEmpty {
                Text(value)
                    .textStyle(.body)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textSecondary)
            }
            if opens { SettingsChevron() }
        }
        .lineLimit(1)
        .padding(.horizontal, SettingsMetrics.horizontal)
        .frame(minHeight: SettingsMetrics.rowHeight)
        .accessibilityElement(children: .combine)
    }
}

// A row with a switch, tinted with the accent when on.
struct SettingsToggleRow: View {
    let title: String
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) { SettingsLabel(title: title, symbol: symbol) }
            .tint(Palette.accent)
            .lineLimit(1)
            .padding(.horizontal, SettingsMetrics.horizontal)
            .frame(minHeight: SettingsMetrics.rowHeight)
    }
}

// A row that pushes a screen.
struct SettingsLinkRow<Destination: View>: View {
    let title: String
    let symbol: String
    let value: String
    @ViewBuilder let destination: Destination

    var body: some View {
        NavigationLink { destination } label: {
            SettingsRow(title: title, symbol: symbol, value: value, opens: true)
        }
        .buttonStyle(SettingsRowButtonStyle())
    }
}

// The pushed list behind Region, Currency, Preferred stores and the alert threshold: one card of
// options, a checkmark in the accent on each selected one. Single-choice lists set the value;
// Preferred stores toggles each store. See-through over the backdrop, like the Settings page.
struct SettingsChoiceList: View {
    let options: [String]
    let isSelected: (String) -> Bool
    let select: (String) -> Void

    var body: some View {
        ScrollView {
            SettingsCard {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    if index > 0 { Hairline().padding(.leading, SettingsMetrics.horizontal) }
                    Button { select(option) } label: { choiceRow(option) }
                        .buttonStyle(SettingsRowButtonStyle())
                }
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollContentBackground(.hidden)
        .background { AppBackdrop() }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func choiceRow(_ option: String) -> some View {
        HStack {
            Text(option)
                .textStyle(.body)
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 8)
            if isSelected(option) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, SettingsMetrics.horizontal)
        .frame(minHeight: SettingsMetrics.rowHeight)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected(option) ? .isSelected : [])
    }
}
