// Settings, a sheet from the gear on Account, laid out like the Claude app's Settings: a round X
// top-left and "Settings" centred (owner, 2026-11-15, replacing "no title" for this screen), then
// the account card (avatar, name, @handle), then "Account" (Profile, Notifications) and "App"
// (Shortcut, Back Tap, Version) cards. Only Profile opens something (EditProfileSheet), so only it
// is a button with a chevron; the rest are plain rows until what they stand for is built.
import SwiftUI

struct AccountSettingsView: View {
    @AppStorage(ProfileKeys.name) private var name = ""
    @AppStorage(ProfileKeys.handle) private var handle = ""
    @State private var editing = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsCard { accountRow }
                    SettingsSection(title: "Account") {
                        Button { editing = true } label: {
                            SettingsRow(title: "Profile", symbol: "person", opens: true)
                        }
                        .buttonStyle(ListRowButtonStyle())
                        SettingsSeparator()
                        SettingsRow(title: "Notifications", symbol: "bell")
                    }
                    SettingsSection(title: "App") {
                        SettingsRow(title: "Shortcut", symbol: "plus.circle")
                        SettingsSeparator()
                        SettingsRow(title: "Back Tap", symbol: "hand.tap")
                        SettingsSeparator()
                        SettingsRow(title: "Version", symbol: "info.circle", value: Self.version)
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .background(Palette.canvas.ignoresSafeArea())
        .sheet(isPresented: $editing) {
            EditProfileSheet()
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.canvas)
        }
    }

    // X on the left, the title centred on the whole width, nothing on the right.
    private var header: some View {
        ZStack {
            Text("Settings")
                .textStyle(.cardTitle)
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button { dismiss() } label: { RoundIcon(systemName: "xmark") }
                    .buttonStyle(IconPressStyle())
                    .accessibilityLabel("Close")
                Spacer()
            }
        }
        .padding(.horizontal, Spacing.screenMargin - (ControlHeight.minTouch - ControlHeight.smallKey) / 2)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // The name on top and the @handle under it. With only a handle, it takes the top line; with
    // neither, the avatar's person symbol stands alone.
    private var accountRow: some View {
        HStack(spacing: Spacing.rowIconToText) {
            ProfileAvatar(name: name, size: ControlHeight.avatar + 4)
            VStack(alignment: .leading, spacing: 5) {
                if !name.isEmpty {
                    Text(name)
                        .textStyle(.body)
                        .foregroundStyle(Palette.textPrimary)
                }
                if !handle.isEmpty {
                    Text("@\(handle)")
                        .textStyle(name.isEmpty ? .body : .label)
                        .foregroundStyle(name.isEmpty ? Palette.textPrimary : Palette.textSecondary)
                }
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SettingsRow.horizontal)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

// A muted label over a card of rows.
private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .textStyle(.label)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, SettingsRow.horizontal)
            SettingsCard { content }
        }
        .padding(.top, 28)
    }
}

// A grouped card: a fill a little lighter than the canvas, large corners, no border or shadow.
private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Palette.fillBar, in: RoundedRectangle(cornerRadius: Radius.glassCard, style: .continuous))
    }
}

// The line between rows, starting where the row labels start rather than at the symbols.
private struct SettingsSeparator: View {
    var body: some View {
        Hairline().padding(.leading, SettingsRow.labelLeading)
    }
}

// One row: a thin outline symbol, the label, an optional value on the right, and a chevron only
// when the row opens something.
private struct SettingsRow: View {
    let title: String
    let symbol: String
    var value: String?
    var opens = false

    static let horizontal = Spacing.cardLeading
    static let symbolWidth: CGFloat = 24
    static let labelLeading = horizontal + symbolWidth + Spacing.rowIconToText

    var body: some View {
        HStack(spacing: Spacing.rowIconToText) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: Self.symbolWidth)
                .accessibilityHidden(true)
            Text(title)
                .textStyle(.body)
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 8)
            if let value, !value.isEmpty {
                Text(value)
                    .textStyle(.body)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textSecondary)
            }
            if opens {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, Self.horizontal)
        .frame(minHeight: ControlHeight.row)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
