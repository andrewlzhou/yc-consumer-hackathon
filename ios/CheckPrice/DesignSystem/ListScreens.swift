// Copied from notyet/ios/Views/DesignSystem/ListScreens.swift (Not Yet).
// Pieces for list screens (History, Account, Settings): a Hiragino screen title, a small section
// label, a pressed fill for list rows, and a round icon button (worldscape F/Settings/RowCard.swift,
// F/People/PersonRow.swift, F/CommandBar/CommandBarParts.swift).
import SwiftUI

// The screen's title in the content, Hiragino W6 28 (the system large title is SF Pro).
struct ScreenTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .textStyle(.title)
            .foregroundStyle(Palette.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }
}

// A small heading over a list card.
struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .textStyle(.section)
            .foregroundStyle(Palette.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

// A list row inside a `FlatCard`: no fill at rest, white 5% while pressed (Worldscape's hover fill).
// The fill is inset 2pt so its corners sit inside the card's.
struct ListRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background { ListRowPressedFill(isPressed: configuration.isPressed) }
            .animation(Motion.hover, value: configuration.isPressed)
    }
}

// The pressed fill alone, for rows whose tappable area is split (a row plus a trailing menu).
struct ListRowPressedFill: View {
    var isPressed: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.listRow, style: .continuous)
            .fill(isPressed ? Palette.fillRowPressed : Color.clear)
            .padding(2)
    }
}

// A small round icon button's face: white 7% circle, 1pt white 12% ring, symbol at 60%.
// Use as a `Button` or `Menu` label. The visual is 36pt; the hit area is 44pt.
struct RoundIcon: View {
    let systemName: String
    var size: CGFloat = ControlHeight.smallKey

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.6))
            .frame(width: size, height: size)
            .background { Circle().fill(.white.opacity(0.07)) }
            .overlay { Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1) }
            .frame(width: max(size, ControlHeight.minTouch), height: max(size, ControlHeight.minTouch))
            .contentShape(Rectangle())
    }
}
