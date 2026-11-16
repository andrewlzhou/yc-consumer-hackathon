// The compact result after Back Tap, drawn by iOS as an App Intents snippet over the store app. Decision only
// (Ruhaan, 2026-11-15): the verdict colour as the background, the verdict word, and a blue More Details button.
// No reason, title, confidence or timings: those are in the check's thread. A tap anywhere on a verdict brings
// Check Price forward, on that thread when the phone still has it. "Sample data" appears only when the evidence is seeded, since an unmarked verdict would pass for real.
// A failed check shows its message on grey, with no word and no button. iOS adds its own Done button below.
// Dark ink on the verdict colours stays above 8:1 in light and dark mode.
import AppIntents
import SwiftUI

@available(iOS 26.0, *)
struct CompactVerdictView: View {
    let verdict: Verdict?
    let failure: String?
    let isSampleData: Bool
    let checkId: String?
    // The canned demo's own words; nil for every real verdict.
    var demoLabel: String? = nil

    private let ink = Palette.canvas
    // Darker than system blue so its white label stays above 4.5:1 (Ruhaan asked for a blue way into the app).
    private let detailsBlue = Color(hex: 0x0B5FD3)

    var body: some View {
        if let verdict {
            // The whole result is the button, on every verdict.
            Button(intent: OpenProductIntent(checkId: checkId ?? "")) { card(verdict) }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spoken(verdict) + ", More Details")
                .accessibilityHint("Opens Check Price")
        } else {
            Text(failure ?? "")
                .font(.hiragino(.w3, size: 15))
                .fixedSize(horizontal: false, vertical: true)
                .modifier(Platter(color: Palette.muted, ink: ink))
        }
    }

    private func card(_ verdict: Verdict) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 8) {
                Text(demoLabel ?? verdict.compactLabel)
                    .font(.hiragino(.w7, size: 24, relativeTo: .title2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                Text("More Details")
                    .font(.hiragino(.w6, size: 15, relativeTo: .callout))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(detailsBlue, in: Capsule())
            }
            if isSampleData {
                Text("Sample data")
                    .font(.hiragino(.w6, size: 13, relativeTo: .footnote))
            }
        }
        .frame(minHeight: 44)
        .modifier(Platter(color: verdict.color, ink: ink))
    }

    private func spoken(_ verdict: Verdict) -> String {
        (demoLabel ?? verdict.compactSpokenLabel) + (isSampleData ? ", sample data" : "")
    }
}

// The coloured block that fills the snippet.
@available(iOS 26.0, *)
private struct Platter: ViewModifier {
    let color: Color
    let ink: Color

    func body(content: Content) -> some View {
        content
            .foregroundStyle(ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: ContainerRelativeShape())
            .contentShape(Rectangle())
    }
}
