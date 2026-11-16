// Target membership: app only.
// Name and two counts on a glass card over the top light, then the one blue key.
import SwiftUI

struct AccountView: View {
    @AppStorage("profileName") private var name = ""
    @State private var history: [HistoryItem] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenTitle("Account")
                    profileCard.padding(.top, Spacing.titleToForm)
                    Link(destination: Config.proCheckoutURL) { Text("Upgrade to Pro") }
                        .buttonStyle(SharpButtonStyle())
                        .padding(.top, 24)
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { ScreenBackdrop() }
            .settingsButton()
            .task {
                let fresh = (try? await ScanAPI.fetchHistory()) ?? []
                withAnimation(Motion.valueChange) { history = fresh }
            }
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Your name", text: $name, prompt: Text("Your name").foregroundStyle(Palette.textTertiary))
                .font(Theme.display(26))
                .foregroundStyle(Palette.textPrimary)
                .tint(Palette.glow)
                .textContentType(.name)
                .submitLabel(.done)
                .padding(.bottom, 16)
            Hairline()
            HStack(spacing: 18) {
                stat("Checked", history.count)
                Rectangle().fill(Palette.divider).frame(width: 1)
                stat("Tracking", history.filter(\.isTracking).count)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 16)
        }
        .padding(18)
        .glassSurface()
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .textStyle(.label)
                .foregroundStyle(Palette.textSecondary)
            Text("\(value)")
                .font(Theme.display(30))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText(value: Double(value)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AccountView().preferredColorScheme(.dark)
}
