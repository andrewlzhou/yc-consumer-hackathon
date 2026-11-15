// Target membership: widget extension only.
// The check's pop-up. Checking: deep blue wisps and "Checking". Decided: the same wisps in the
// verdict's hue, the verdict word, and a very short reason in a serif, all centred.
// Deliberately absent (owner, 2026-11-15): store, product name, clock or other icon, logo.
// The leading slot holds only a small wisp glow, so a logo can replace it later.
// The Dynamic Island's outer pill is always black, so the art sits inside its regions.
import ActivityKit
import SwiftUI
import WidgetKit

private extension CheckAttributes.ContentState {
    var isChecking: Bool { stage == .checking || verdict == nil }
    var word: String { isChecking ? "Checking" : verdict?.word ?? "Checking" }
    var palette: WispPalette { isChecking ? .checking : verdict.map(WispPalette.decided) ?? .checking }
    var shownReason: String? { isChecking ? nil : reason }
}

private enum IslandType {
    // Hiragino Sans W6, the app's title face; iOS falls back to the system font if it's missing.
    static func word(_ size: CGFloat) -> Font { .custom("HiraginoSans-W6", size: size) }
    // New York, Apple's built-in serif, standing in for the serif Granola uses.
    static func reason(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
}

// Word over reason, centred, white on the wisps.
private struct VerdictStack: View {
    let state: CheckAttributes.ContentState
    var wordSize: CGFloat = 20
    var reasonSize: CGFloat = 15

    var body: some View {
        VStack(spacing: 4) {
            Text(state.word)
                .font(IslandType.word(wordSize))
                .foregroundStyle(Color.white.opacity(0.96))
                .contentTransition(.opacity)
            if let reason = state.shownReason {
                Text(reason)
                    .font(IslandType.reason(reasonSize))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .lineLimit(2)
                    .transition(.opacity)
            }
        }
        .multilineTextAlignment(.center)
        .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.8), value: state.stage)
    }
}

// Lock Screen and banner: the wisps full-bleed, the words centred.
private struct LockScreenView: View {
    let state: CheckAttributes.ContentState

    var body: some View {
        VerdictStack(state: state, wordSize: 22, reasonSize: 16)
            .frame(minHeight: 96)
            .background { WispField(palette: state.palette, phase: state.phase) }
    }
}

// Expanded island: a rounded wisp card under the camera, words centred on it.
private struct ExpandedCard: View {
    let state: CheckAttributes.ContentState

    var body: some View {
        VerdictStack(state: state)
            .frame(height: state.isChecking ? 64 : 84)
            .background { WispField(palette: state.palette, phase: state.phase) }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(state.palette.rim.opacity(0.35), lineWidth: 0.5)
            }
    }
}

struct CheckLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CheckAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(context.state.palette.mid)
                .activitySystemActionForegroundColor(Color.white.opacity(0.94))
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedCard(state: s)
                }
            } compactLeading: {
                WispOrb(palette: s.palette, phase: s.phase)
            } compactTrailing: {
                Text(s.word)
                    .font(IslandType.word(13))
                    .foregroundStyle(s.palette.ink)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            } minimal: {
                WispOrb(palette: s.palette, phase: s.phase, diameter: 18)
            }
            .contentMargins(.all, 10, for: .expanded)
            .keylineTint(s.palette.rim)
        }
    }
}
