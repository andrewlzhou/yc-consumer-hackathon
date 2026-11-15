// Target membership: widget extension only.
// Sketch: while searching, a pill with a radar icon, "Digging…" and an X to cancel.
// When done, the dollar sign pops in (like Shazam) with the verdict and the store.
import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// Same tokens as the app's Theme (the widget can't see app files).
private let buyGreen = Color(red: 0x3D / 255, green: 0xDC / 255, blue: 0x97 / 255)
private let waitAmber = Color(red: 0xFF / 255, green: 0xB5 / 255, blue: 0x47 / 255)
private let fakeRed = Color(red: 0xFF / 255, green: 0x5C / 255, blue: 0x5C / 255)
private let radarCyan = Color(red: 0x4A / 255, green: 0x86 / 255, blue: 0xBD / 255)   // Prussian, light
private let prussian = Color(red: 0x00 / 255, green: 0x31 / 255, blue: 0x53 / 255)

private extension ScanAttributes.ContentState {
    var isWorking: Bool { stage == "working" }

    var word: String {
        if isWorking { return "Digging…" }
        switch verdict {
        case "BUY_NOW": return "Buy"
        case "WAIT": return "Wait"
        case "FAKE_DEAL": return "Fake deal"
        default: return "Tap to open"
        }
    }

    var color: Color {
        if isWorking { return radarCyan }
        switch verdict {
        case "BUY_NOW": return buyGreen
        case "WAIT": return waitAmber
        case "FAKE_DEAL": return fakeRed
        default: return .gray
        }
    }

    // Live Activities can't loop animations, so the radar is a static symbol.
    // The swap to the dollar sign animates when the verdict arrives.
    var symbol: String {
        if isWorking { return "dot.radiowaves.left.and.right" }
        return verdict == nil ? "magnifyingglass" : "dollarsign.circle.fill"
    }

    var link: URL { URL(string: "notyet://scan/\(scanKey)")! }
}

private struct StateIcon: View {
    let state: ScanAttributes.ContentState
    var body: some View {
        Image(systemName: state.symbol)
            .foregroundStyle(state.color)
            .contentTransition(.symbolEffect(.replace))
    }
}

private struct RetailerPill: View {
    let name: String
    var body: some View {
        Text(name)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(prussian)
            .foregroundStyle(.white)
    }
}

private struct CancelButton: View {
    var body: some View {
        Button(intent: CancelScanIntent()) {
            Image(systemName: "xmark")
                .font(.caption.bold())
                .frame(width: 28, height: 28)
                .background(prussian)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
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
            .tint(state.color)
        }
    }
}

struct ScanLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScanAttributes.self) { context in
            // Lock Screen and banner
            let s = context.state
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    StateIcon(state: s).font(.title)
                    Text(s.word).font(.title3.bold()).foregroundStyle(.white)
                    if let r = s.retailer, !s.isWorking { RetailerPill(name: r) }
                    Spacer()
                    if s.isWorking { CancelButton() }
                }
                Text(s.headline)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                if s.isWorking { WorkingBar(state: s, startedAt: context.attributes.startedAt) }
            }
            .padding(16)
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(.white)
            .widgetURL(s.link)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StateIcon(state: s).font(.title)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(s.word).font(.headline).foregroundStyle(s.color)
                        if let name = s.productName {
                            Text(name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
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
                        Text(s.headline).font(.subheadline).lineLimit(2)
                        if s.isWorking { WorkingBar(state: s, startedAt: context.attributes.startedAt) }
                    }
                }
            } compactLeading: {
                StateIcon(state: s)
            } compactTrailing: {
                Text(s.isWorking ? "Digging…" : s.word)
                    .font(.caption2.bold())
                    .foregroundStyle(s.color)
            } minimal: {
                StateIcon(state: s)
            }
            .widgetURL(s.link)
            .keylineTint(s.color)
        }
    }
}
