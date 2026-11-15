import SwiftUI

struct SetupView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SETUP").font(.system(size: 13, weight: .bold, design: .rounded)).tracking(1.6).foregroundStyle(AppColor.electric)
            Text("Make checking effortless.").font(.system(size: 30, weight: .bold, design: .rounded))
            Card { VStack(alignment: .leading, spacing: 16) {
                Label("Add the Shortcut", systemImage: "plus.circle.fill")
                Label("Set Back Tap or Action Button", systemImage: "hand.tap.fill")
                Label("Allow price alerts", systemImage: "bell.badge.fill")
            }.font(.headline) }
            Text("These are visual onboarding steps until Shortcut and notification work is connected.").font(.footnote).foregroundStyle(AppColor.muted)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
