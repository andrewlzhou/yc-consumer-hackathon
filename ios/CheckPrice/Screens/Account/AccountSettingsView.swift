// Settings, pushed from the gear on Account. The setup steps that used to be the Setup tab, then
// the usual account rows. None of it is connected yet, and each row says so.
import SwiftUI

struct AccountSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                group("Set up") {
                    SettingsRow(title: "Add the Shortcut", symbol: "plus.circle", detail: "Not connected yet")
                    Hairline()
                    SettingsRow(title: "Set Back Tap or Action Button", symbol: "hand.tap", detail: "Not connected yet")
                    Hairline()
                    SettingsRow(title: "Allow price alerts", symbol: "bell.badge", detail: "Not connected yet")
                }
                Text("These steps are shown for the look only until the Shortcut and alerts are built.")
                    .textStyle(.footnote)
                    .lineSpacing(3)
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)

                group("Account") {
                    SettingsRow(title: "Notifications", symbol: "bell", detail: "Not connected yet")
                    Hairline()
                    SettingsRow(title: "Privacy", symbol: "lock", detail: "Not connected yet")
                    Hairline()
                    SettingsRow(title: "About", symbol: "info.circle", trailing: Self.version)
                }
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.bottom, 24)
        }
        .background(Palette.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .textStyle(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
            }
        }
    }

    private static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return short.map { "Version \($0)" } ?? ""
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title).padding(.leading, 4)
            FlatCard {
                VStack(spacing: 0) { content() }
            }
        }
        .padding(.top, 20)
    }
}

// One settings row: a symbol, a title, an optional line under it, and an optional trailing value.
// Rows are not buttons, since nothing behind them works yet.
private struct SettingsRow: View {
    let title: String
    let symbol: String
    var detail: String?
    var trailing: String?

    var body: some View {
        HStack(spacing: Spacing.rowIconToText) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .textStyle(.item)
                    .foregroundStyle(Palette.textPrimary)
                if let detail {
                    Text(detail)
                        .textStyle(.caption)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
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
