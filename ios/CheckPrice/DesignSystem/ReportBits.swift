// Copied from notyet/ios/Views/DesignSystem/ReportBits.swift (Not Yet).
// Small pieces the report and the loading state share: the sample-data label the backend contract
// requires, and a confidence meter. Additive; nothing else in DesignSystem changes.
import SwiftUI

// "Sample data" capsule. Shown whenever a verdict, chart or analysis is built from sample data, as
// the backend contract requires. Smoky glass look, never blue, so it reads on the hero light.
struct SampleDataTag: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "testtube.2")
                .font(.system(size: 10, weight: .semibold))
            Text("Sample data")
                .textStyle(.footnote)
                .lineLimit(1)
        }
        .foregroundStyle(Palette.textPrimary)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background { Capsule().fill(Color.black.opacity(0.28)) }
        .overlay { Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 0.75) }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sample data, not live prices")
    }
}

// "Confidence ━━━━━── 78%". `value` is 0...1; the fill takes the verdict colour.
struct ConfidenceMeter: View {
    let value: Double
    var tint: Color = Palette.textPrimary

    private var clamped: Double { min(max(value, 0), 1) }
    private var percent: Int { Int((clamped * 100).rounded()) }

    var body: some View {
        HStack(spacing: 10) {
            Text("Confidence")
                .textStyle(.footnote)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize()
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(4, proxy.size.width * clamped))
                }
            }
            .frame(height: 4)
            Text("\(percent)%")
                .textStyle(.caption)
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Confidence \(percent) percent")
    }
}
