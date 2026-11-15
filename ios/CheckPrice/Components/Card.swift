// A padded flat card: `FlatCard` with 18pt inside. Kept for screens written against the
// prototype's `Card { … }`; new code can use `FlatCard` directly.
import SwiftUI

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        FlatCard(cornerRadius: Radius.glassCard) {
            content
                .padding(Spacing.cardLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
