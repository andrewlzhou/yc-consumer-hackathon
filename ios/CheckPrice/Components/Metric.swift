// A small label over a value: "Today" over "$349".
import SwiftUI

struct Metric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .textStyle(.section)
                .foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(.hiragino(.w6, size: 20, relativeTo: .title3))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}
