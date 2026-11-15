// Target membership: app only.
import SwiftUI

struct AccountView: View {
    @AppStorage("profileName") private var name = ""
    @State private var history: [HistoryItem] = []

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                TextField("Your name", text: $name)
                    .font(Theme.display(28))
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 16)
                Hairline()
                stat("Checked", "\(history.count)")
                Hairline()
                stat("Tracking", "\(history.filter(\.isTracking).count)")
                Hairline()
                Link(destination: Config.proCheckoutURL) { Text("Upgrade to Pro") }
                    .buttonStyle(SharpButtonStyle())
                    .padding(.top, 24)
                Spacer()
            }
            .padding(20)
            .background(Theme.paper)
            .navigationTitle("Account")
            .settingsButton()
            .task { history = (try? await ScanAPI.fetchHistory()) ?? [] }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.slate)
            Spacer()
            Text(value).font(Theme.display(24)).monospacedDigit().foregroundStyle(Theme.ink)
        }
        .padding(.vertical, 14)
    }
}

#Preview {
    AccountView().preferredColorScheme(.dark)
}
