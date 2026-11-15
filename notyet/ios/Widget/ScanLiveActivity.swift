// Target membership: widget extension only.
// While checking: a radar icon, "Digging…", the current step, a bar that fills over the longest
// the quick check can take, and an X to cancel. When done, the verdict word leads in its colour,
// with the product, the one-line reason and the store. Worldscape look: near-black, white text at
// fixed opacities, blue only for the working state, red only for errors.
import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// Same values as the app's Palette and `Verdict` in App/Models.swift (the widget can't see App/ or
// Views/). Change both together.
private enum WidgetPalette {
    static let canvas = Color(red: 0x01 / 255, green: 0x01 / 255, blue: 0x01 / 255)
    static let glow = Color(red: 0x43 / 255, green: 0x6F / 255, blue: 0xFF / 255)
    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.36)
    static let fillChip = Color.white.opacity(0.10)
    static let stroke = Color.white.opacity(0.16)

    static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

// Word, symbol and colour per verdict string, copied from `Verdict`. Strings this build doesn't
// know read as a neutral "Ready" rather than "Checking", since the check has finished.
private struct WidgetVerdict {
    let word: String
    let symbol: String
    let color: Color

    init(_ raw: String?) {
        switch raw?.uppercased() {
        case "BUY_NOW": (word, symbol, color) = ("Buy", "checkmark.circle.fill", WidgetPalette.rgb(0x3DDC97))
        case "WAIT": (word, symbol, color) = ("Wait", "clock.fill", WidgetPalette.rgb(0xFFB547))
        case "FAKE_DEAL": (word, symbol, color) = ("Fake deal", "exclamationmark.triangle.fill", WidgetPalette.rgb(0xFF5C7A))
        case "CONSIDER_ALTERNATIVE": (word, symbol, color) = ("Look around", "arrow.left.arrow.right.circle.fill", WidgetPalette.rgb(0xC4A7FF))
        case "INVESTIGATE": (word, symbol, color) = ("Check first", "magnifyingglass.circle.fill", WidgetPalette.rgb(0xFF9466))
        case nil: (word, symbol, color) = ("No answer yet", "hourglass", WidgetPalette.textSecondary)
        default: (word, symbol, color) = ("Ready", "ellipsis.circle.fill", WidgetPalette.rgb(0x9E9EA6))
        }
    }
}

private extension ScanAttributes.ContentState {
    var isWorking: Bool { stage == "working" }
    var kind: WidgetVerdict { WidgetVerdict(verdict) }

    var word: String { isWorking ? "Digging…" : kind.word }
    var color: Color { isWorking ? WidgetPalette.glow : kind.color }

    // Live Activities can't loop animations, so the radar is a static symbol.
    // The swap to the verdict symbol animates when the verdict arrives.
    var symbol: String { isWorking ? "dot.radiowaves.left.and.right" : kind.symbol }

    var link: URL { URL(string: "notyet://scan/\(scanKey)") ?? URL(string: "notyet://")! }
}

private struct StateIcon: View {
    let state: ScanAttributes.ContentState
    var body: some View {
        Image(systemName: state.symbol)
            .foregroundStyle(state.color)
            .contentTransition(.symbolEffect(.replace))
    }
}

// Worldscape pills are smoky and never blue: white 10% fill with a faint rim.
private struct RetailerPill: View {
    let name: String
    var body: some View {
        Text(name)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(WidgetPalette.textPrimary)
            .background(WidgetPalette.fillChip, in: Capsule())
            .overlay(Capsule().strokeBorder(WidgetPalette.stroke, lineWidth: 0.75))
    }
}

// Round icon button: white fill, faint ring, the × in secondary text.
private struct CancelButton: View {
    var body: some View {
        Button(intent: CancelScanIntent()) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetPalette.textSecondary)
                .frame(width: 32, height: 32)
                .background(WidgetPalette.fillChip, in: Circle())
                .overlay(Circle().strokeBorder(WidgetPalette.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cancel")
    }
}

private struct WorkingBar: View {
    let state: ScanAttributes.ContentState
    let startedAt: Date
    var body: some View {
        if state.etaEnd > startedAt {
            // Fills on its own over the estimated time. No updates needed.
            ProgressView(timerInterval: startedAt...state.etaEnd, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(WidgetPalette.glow)
        }
    }
}

// Lock Screen and banner.
private struct LockScreenView: View {
    let state: ScanAttributes.ContentState
    let startedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                StateIcon(state: state).font(.title2)
                Text(state.word)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(state.isWorking ? WidgetPalette.textPrimary : state.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                if state.isWorking {
                    CancelButton()
                } else if let r = state.retailer {
                    RetailerPill(name: r)
                }
            }
            if let name = state.productName, !state.isWorking {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetPalette.textPrimary)
                    .lineLimit(1)
            }
            Text(state.headline)
                .font(.subheadline)
                .foregroundStyle(WidgetPalette.textSecondary)
                .lineLimit(2)
            if state.isWorking {
                WorkingBar(state: state, startedAt: startedAt)
                    .padding(.top, 2)
            }
        }
        .padding(16)
    }
}

struct ScanLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScanAttributes.self) { context in
            LockScreenView(state: context.state, startedAt: context.attributes.startedAt)
                .activityBackgroundTint(WidgetPalette.canvas)
                .activitySystemActionForegroundColor(WidgetPalette.textPrimary)
                .widgetURL(context.state.link)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StateIcon(state: s).font(.title)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(s.word)
                            .font(.headline)
                            .foregroundStyle(s.isWorking ? WidgetPalette.textPrimary : s.color)
                            .lineLimit(1)
                        if let name = s.productName {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(WidgetPalette.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if s.isWorking {
                        CancelButton()
                    } else if let r = s.retailer {
                        RetailerPill(name: r)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.headline)
                            .font(.subheadline)
                            .foregroundStyle(WidgetPalette.textSecondary)
                            .lineLimit(2)
                        if s.isWorking { WorkingBar(state: s, startedAt: context.attributes.startedAt) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                StateIcon(state: s)
            } compactTrailing: {
                Text(s.isWorking ? "Digging…" : s.word)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(s.isWorking ? WidgetPalette.textPrimary : s.color)
                    .lineLimit(1)
            } minimal: {
                StateIcon(state: s)
            }
            .widgetURL(s.link)
            .keylineTint(s.color)
        }
    }
}
