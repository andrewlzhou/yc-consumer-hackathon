// The Account tab is the Settings page (owner, 2026-11-15), laid out after Grok's iOS Settings:
// "Settings" small and centred in the bar, a profile card (avatar, name, @handle, chevron) that
// opens EditProfileSheet, then "App" over one card of plain rows (Notifications, Shortcut, Back
// Tap, Version). None of the App rows opens anything yet, so they have no chevrons and aren't
// buttons. ContentView draws the backdrop behind the tab; nothing here paints over it.
import SwiftUI

struct AccountView: View {
    @AppStorage(ProfileKeys.name) private var name = ""
    @AppStorage(ProfileKeys.handle) private var handle = ""
    @State private var editing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Button { editing = true } label: { profileCard }
                        .buttonStyle(SettingsCardButtonStyle())
                        .accessibilityHint("Edit profile")
                    SettingsSection(title: "App") {
                        SettingsRow(title: "Notifications", symbol: "bell")
                        SettingsSeparator()
                        SettingsRow(title: "Shortcut", symbol: "plus.circle")
                        SettingsSeparator()
                        SettingsRow(title: "Back Tap", symbol: "hand.tap")
                        SettingsSeparator()
                        SettingsRow(title: "Version", symbol: "info.circle", value: Self.version)
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollContentBackground(.hidden)
            .containerBackground(.clear, for: .navigation)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.hiragino(.w7, size: 16, relativeTo: .headline))
                        .foregroundStyle(Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $editing) {
                EditProfileSheet()
                    .presentationDragIndicator(.visible)
                    .presentationBackground { AppBackdrop() }
            }
        }
    }

    // Avatar, then the name (semibold) over the @handle (secondary). With only a handle, it takes
    // the top line; with neither, the avatar's person symbol stands alone.
    private var profileCard: some View {
        HStack(spacing: Spacing.rowIconToText) {
            ProfileAvatar(name: name, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                if !name.isEmpty {
                    Text(name)
                        .font(.hiragino(.w6, size: 17, relativeTo: .body))
                        .foregroundStyle(Palette.textPrimary)
                }
                if !handle.isEmpty {
                    Text("@\(handle)")
                        .font(name.isEmpty ? .hiragino(.w6, size: 17, relativeTo: .body) : .hiragino(.w4, size: 14, relativeTo: .subheadline))
                        .foregroundStyle(name.isEmpty ? Palette.textPrimary : Palette.textSecondary)
                }
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            SettingsChevron()
        }
        .padding(.horizontal, SettingsRow.horizontal)
        .padding(.vertical, 16)
        .background(SettingsSurface.fill, in: SettingsSurface.shape)
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
        .padding(.top, 32)
    }
}

// The cards' look: warm grey a step lighter than the bar fill so it reads over the backdrop's
// gradient, large corners, no border or shadow.
private enum SettingsSurface {
    static let fill = Color.white.opacity(0.08)
    static let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
}

// A grouped card of rows.
private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(SettingsSurface.fill, in: SettingsSurface.shape)
    }
}

// The profile card's press: the whole card dims slightly while held.
private struct SettingsCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(SettingsSurface.shape)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(Motion.hover, value: configuration.isPressed)
    }
}

// The line between rows, starting where the row labels start rather than at the symbols.
private struct SettingsSeparator: View {
    var body: some View {
        Hairline().padding(.leading, SettingsRow.labelLeading)
    }
}

private struct SettingsChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.textTertiary)
            .accessibilityHidden(true)
    }
}

// One row: a thin outline symbol, the label, and an optional value on the right.
private struct SettingsRow: View {
    let title: String
    let symbol: String
    var value: String?

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
        }
        .lineLimit(1)
        .padding(.horizontal, Self.horizontal)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}

// Where the profile fields are kept on the device. Nothing is sent anywhere.
enum ProfileKeys {
    static let name = "profileName"
    static let handle = "profileHandle"
    static let bio = "profileBio"
}

// A round avatar: the name's initials, or a person symbol when there is no name, on a warm grey
// pair with a white top sheen (worldscape F/People/PersonRow.swift).
struct ProfileAvatar: View {
    let name: String
    var size: CGFloat = 84

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(colors: [Color(hex: 0x76746E), Palette.stone], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            Circle().fill(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .center))
            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                Text(initials)
                    .font(.hiragino(.w6, size: size * 0.34, relativeTo: .title))
                    .foregroundStyle(.white)
                    .dropShadow(Shadows.labelOnColor)
            }
        }
        .frame(width: size, height: size)
        .overlay { Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1) }
        .accessibilityHidden(true)
    }
}

// The money a saved thread stands to save by waiting: its price minus the low end of its
// projected low, never below zero. Prices are demo strings like "$349" and "$309–$319".
enum SavedByWaiting {
    static func total(_ threads: [ShoppingThread]) -> Int {
        threads.reduce(0) { $0 + amount($1.product) }
    }

    static func amount(_ product: Product) -> Int {
        guard let price = firstDollars(product.price), let low = firstDollars(product.projectedLow) else { return 0 }
        return max(0, price - low)
    }

    static func format(_ dollars: Int) -> String { "$\(dollars)" }

    // The first whole-dollar number in the string: "$1,299.99" → 1299.
    private static func firstDollars(_ text: String) -> Int? {
        var digits = ""
        for character in text.drop(while: { !$0.isNumber }) {
            if character.isNumber { digits.append(character) }
            else if character == "," { continue }
            else { break }
        }
        return Int(digits)
    }
}
