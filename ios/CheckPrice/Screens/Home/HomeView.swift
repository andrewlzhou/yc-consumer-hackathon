// Home: only the check (`PrimaryCheckArea`) over the aurora (`HomeAurora`), which brightens while a
// check runs. Other tabs sit on the flat canvas; Home draws its own light full-bleed.
import SwiftUI

struct HomeView: View {
    // Set by the `-autoReveal YES` launch argument; runs the demo once, then clears.
    @Binding var autoReveal: Bool
    @State private var isAnalyzing = false

    var body: some View {
        PrimaryCheckArea(autoReveal: $autoReveal, isAnalyzing: $isAnalyzing)
            .background { HomeAurora(isActive: isAnalyzing) }
    }
}
