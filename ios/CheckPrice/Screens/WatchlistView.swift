import SwiftUI

struct WatchlistView: View {
    @Binding var report: Bool
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            Text("WATCHLIST").font(.system(size: 13, weight: .bold, design: .rounded)).tracking(1.6).foregroundStyle(AppColor.electric)
            Text("We’ll tell you when it’s time.").font(.system(size: 30, weight: .bold, design: .rounded))
            ForEach(Demo.saved) { SignalRow(product: $0) { report = true } }
            Card { Label("Daily price checks are a planned backend feature.", systemImage: "clock.badge.checkmark").font(.footnote).foregroundStyle(AppColor.muted) }
        }.padding(.bottom, 106) }
    }
}
