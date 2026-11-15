// Home: the first screen is the app's main function (`PrimaryCheckArea`); scrolling past it shows
// the summary across all threads (`HomeSummary`). ContentView draws the backdrop behind it.
import SwiftUI

struct HomeView: View {
    // Set by the `-autoReveal YES` launch argument; runs the demo once, then clears.
    @Binding var autoReveal: Bool

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                PrimaryCheckArea(autoReveal: $autoReveal)
                    .containerRelativeFrame(.vertical)
                HomeSummary()
            }
        }
    }
}
