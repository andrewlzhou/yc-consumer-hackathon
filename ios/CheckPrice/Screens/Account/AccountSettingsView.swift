// Settings, pushed from the gear on Account: the setup steps and the app version, one word each.
// Nothing behind the setup rows is built yet, so they are not buttons.
import SwiftUI

struct AccountSettingsView: View {
    var body: some View {
        ScrollView {
            FlatCard {
                VStack(spacing: 0) {
                    SettingsRow(title: "Shortcut", symbol: "plus.circle")
                    Hairline()
                    SettingsRow(title: "Back Tap", symbol: "hand.tap")
                    Hairline()
                    SettingsRow(title: "Price alerts", symbol: "bell.badge")
                    Hairline()
                    SettingsRow(title: "Version", symbol: "info.circle", trailing: Self.version)
                }
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(Palette.canvas)
        .navigationBarTitleDisplayMode(.inline)
        // No title in the bar (owner, 2026-11-15); it holds only the back button.
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

// One settings row: a symbol, a title, and an optional trailing value.
private struct SettingsRow: View {
    let title: String
    let symbol: String
    var trailing: String?

    var body: some View {
        HStack(spacing: Spacing.rowIconToText) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 24)
            Text(title)
                .textStyle(.item)
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 8)
            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .textStyle(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.rowHorizontal)
        .padding(.vertical, 12)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}
