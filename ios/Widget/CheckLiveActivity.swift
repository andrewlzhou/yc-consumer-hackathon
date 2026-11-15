// Target membership: widget extension only.
// The check's pop-up. Checking: deep blue wisps and a playful word that changes on each update
// (`CheckingWords` in Shared/CheckAttributes.swift). Decided: the same wisps in the
// verdict's hue, the verdict word, and a very short reason, all centred, in Hiragino Sans.
// Deliberately absent (owner, 2026-11-15): store, product name, clock or other icon, logo.
// The compact leading and minimal slots show only the wisps, kept for a future logo.
// The wisps fill every island region edge to edge (content margins 0); only the camera cutout
// stays black.
import ActivityKit
import SwiftUI
import WidgetKit

private extension CheckAttributes.ContentState {
    var isChecking: Bool { stage == .checking || verdict == nil }
    var checkingWord: String { CheckingWords.word(start: wordStart, phase: phase) }
    var word: String { isChecking ? checkingWord : verdict?.word ?? checkingWord }
    var palette: WispPalette { isChecking ? .checking : verdict.map(WispPalette.decided) ?? .checking }
    var shownReason: String? { isChecking ? nil : reason }
}

// Hiragino Sans, the Worldscape font (the widget can't see the app's DesignSystem).
private enum IslandType {
    static func word(_ size: CGFloat) -> Font { .custom("HiraginoSans-W6", size: size) }
    static func reason(_ size: CGFloat) -> Font { .custom("HiraginoSans-W3", size: size) }
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

// One wisp field for the whole island. Every region draws the same canvas, placed at the same
// spot on screen (offset by the region's own position), so where regions meet or overlap the
// art lines up and they read as one continuous field. Only the camera cutout stays black.
private struct IslandField: View {
    let state: CheckAttributes.ContentState
    let canvas: CGSize

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            WispField(palette: state.palette, phase: state.phase)
                .frame(width: canvas.width, height: canvas.height)
                .offset(x: -origin.x, y: -origin.y)
        }
    }
}

// Canvas sizes in screen points, from the top-left of the screen; wider than any iPhone so
// every region finds its slice. The island's top sits about 11 pt down.
private enum Canvas {
    static let compact = CGSize(width: 480, height: 52)
    static func expanded(_ state: CheckAttributes.ContentState) -> CGSize {
        CGSize(width: 480, height: state.isChecking ? 130 : 160)
    }
}

private extension View {
    func islandField(_ state: CheckAttributes.ContentState, _ canvas: CGSize) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { IslandField(state: state, canvas: canvas) }
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
            let big = Canvas.expanded(s)
            return DynamicIsland {
                // Leading, trailing and centre carry only the field (the leading slot is kept
                // for a future logo); the words sit centred in the bottom region.
                DynamicIslandExpandedRegion(.leading) { Color.clear.islandField(s, big) }
                DynamicIslandExpandedRegion(.trailing) { Color.clear.islandField(s, big) }
                DynamicIslandExpandedRegion(.center) { Color.clear.islandField(s, big) }
                DynamicIslandExpandedRegion(.bottom) {
                    VerdictStack(state: s)
                        .padding(.vertical, 8)
                        .islandField(s, big)
                }
            } compactLeading: {
                // Field only: reserved for a future logo, and it balances the word on the right.
                Color.clear.islandField(s, Canvas.compact)
            } compactTrailing: {
                Text(s.word)
                    .font(IslandType.word(13))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(1)
                    // The longest word ("Markdownmusing") is about 125 pt at 13 pt; cap the slot
                    // and let it shrink rather than widen the island.
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: 100)
                    .padding(.horizontal, 8)
                    .contentTransition(.opacity)
                    .islandField(s, Canvas.compact)
            } minimal: {
                Color.clear.islandField(s, Canvas.compact)
            }
            .contentMargins(.all, 0, for: .expanded)
            .contentMargins(.all, 0, for: .compactLeading)
            .contentMargins(.all, 0, for: .compactTrailing)
            .contentMargins(.all, 0, for: .minimal)
            .keylineTint(s.palette.rim)
        }
    }
}
