// Target membership: app only. Opened from the gear on every tab.
import SwiftUI
import UIKit

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Set up once") {
                    Link(destination: Config.shortcutURL) { Text("Add the shortcut") }
                    Text("Back Tap: Accessibility, Touch, Back Tap")
                    Text("Action Button: Settings, Action Button")
                }
                .listRowBackground(Theme.paper)
                Section("Notifications") {
                    Button("Test reminder") {
                        Reminders.demoReminder(scanKey: "", productName: "AirPods Pro 3",
                                               body: "It just hit your price at Best Buy.")
                    }
                    Button("iPhone Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                .listRowBackground(Theme.paper)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .foregroundStyle(Theme.ink)
            .tint(Theme.prussianLight)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
