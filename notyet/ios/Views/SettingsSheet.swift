// Target membership: app only. Opened from the gear on every tab.
// Two list cards on the plain canvas; settings stay near-monochrome.
import SwiftUI
import UIKit

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    group("Set up once") {
                        Link(destination: Config.shortcutURL) {
                            SettingsRow(title: "Add the shortcut", symbol: "arrow.up.right")
                        }
                        .buttonStyle(ListRowButtonStyle())
                        Hairline()
                        SettingsRow(title: "Back Tap", detail: "Accessibility, Touch, Back Tap")
                        Hairline()
                        SettingsRow(title: "Action Button", detail: "Settings, Action Button")
                    }
                    group("Notifications") {
                        Button {
                            Reminders.demoReminder(scanKey: "", productName: "AirPods Pro 3",
                                                   body: "It just hit your price at Best Buy.")
                        } label: {
                            SettingsRow(title: "Test reminder", symbol: "bell")
                        }
                        .buttonStyle(ListRowButtonStyle())
                        Hairline()
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            SettingsRow(title: "iPhone Settings", symbol: "arrow.up.right")
                        }
                        .buttonStyle(ListRowButtonStyle())
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, 24)
            }
            .background(Palette.canvas)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .textStyle(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(Palette.glow)
                }
            }
        }
        .presentationBackground(Palette.canvas)
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

// One settings row: a title, an optional path under it, an optional trailing symbol.
private struct SettingsRow: View {
    let title: String
    var detail: String?
    var symbol: String?

    var body: some View {
        HStack(spacing: 12) {
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
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.rowHorizontal)
        .padding(.vertical, 12)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SettingsSheet().preferredColorScheme(.dark)
}
