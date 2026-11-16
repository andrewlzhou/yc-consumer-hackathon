// The compact result after Back Tap, drawn by iOS as an App Intents snippet over the store app: the verdict
// colour as the background, the verdict word, a very short reason, a sample-data mark only when the evidence is
// seeded, and a blue Details button that opens this product's thread in the app. Title, confidence and timings
// stay in the thread. Dark ink on the verdict colours stays above 8:1 in light and dark mode.
import AppIntents
import SwiftUI

@available(iOS 26.0, *)
struct CompactVerdictView: View {
    let verdict: Verdict?
    let reason: String
    let isSampleData: Bool
    let productId: String?

    private let ink = Palette.canvas
    // Darker than system blue so its white label stays above 4.5:1 (Ruhaan asked for a blue way into the app).
    private let detailsBlue = Color(hex: 0x0B5FD3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let verdict {
                    Text(verdict.compactLabel)
                        .font(.hiragino(.w7, size: 26, relativeTo: .title2))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityLabel(verdict.compactSpokenLabel)
                }
                Text(reason)
                    .font(.hiragino(.w3, size: 17))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            if isSampleData || productId != nil {
                HStack(alignment: .center) {
                    if isSampleData {
                        Text("Sample data")
                            .font(.hiragino(.w6, size: 13, relativeTo: .footnote))
                    }
                    Spacer(minLength: 8)
                    if let productId {
                        Button(intent: OpenProductIntent(productId: productId)) {
                            Text("Details")
                                .font(.hiragino(.w6, size: 15, relativeTo: .callout))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .frame(minHeight: 44)
                                .background(detailsBlue, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open details in Check Price")
                    }
                }
            }
        }
        .foregroundStyle(ink)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(verdict?.color ?? Palette.muted, in: ContainerRelativeShape())
    }
}
