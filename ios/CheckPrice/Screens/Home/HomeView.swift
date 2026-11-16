// Home: the first screen is the app's main function (`PrimaryCheckArea`); scrolling past it shows
// the summary across all threads (`HomeSummary`). ContentView draws the backdrop behind it.
import SwiftUI

struct HomeView: View {
    // Set by the `-autoReveal YES` launch argument; runs the demo once, then clears.
    @Binding var autoReveal: Bool

    var body: some View {
        // The reader's size leaves out the status bar and the tab bar, so the first screen ends at
        // the bar's top edge and the summary starts below it instead of under it.
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    PrimaryCheckArea(autoReveal: $autoReveal)
                        .frame(height: proxy.size.height)
                    HomeSummary()
                }
            }
            // Room past the last row so it scrolls clear of the floating tab bar.
            .contentMargins(.bottom, 24, for: .scrollContent)
        }
    }
}
