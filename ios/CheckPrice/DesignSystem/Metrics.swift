// Copied from notyet/ios/Views/DesignSystem/Metrics.swift (Not Yet).
// Spacing, radii, sizes, shadows and motion, as Worldscape uses them. Worldscape has no named
// spacing scale; these are its values in use, plus iOS touch sizes where noted.
import SwiftUI

enum Spacing {
    static let screenMargin: CGFloat = 16      // iOS: screen edge to content
    static let labelToField: CGFloat = 9
    static let betweenFields: CGFloat = 18
    static let titleToForm: CGFloat = 28
    static let rowIconToText: CGFloat = 14
    static let pillContents: CGFloat = 8
    static let betweenMessages: CGFloat = 18
    static let bubblesInReply: CGFloat = 6
    static let fieldHorizontal: CGFloat = 14
    static let rowHorizontal: CGFloat = 12
    static let bubbleHorizontal: CGFloat = 16
    static let bubbleVertical: CGFloat = 12.5
    // Glass card padding.
    static let cardLeading: CGFloat = 18
    static let cardTrailing: CGFloat = 12
    static let cardTop: CGFloat = 13
    static let cardBottom: CGFloat = 17
}

// All corners use `style: .continuous`. Bars, pills and chips are capsules.
enum Radius {
    static let thumbnail: CGFloat = 6
    static let smallKey: CGFloat = 8
    static let key: CGFloat = 10
    static let field: CGFloat = 10
    static let listRow: CGFloat = 12
    static let listCard: CGFloat = 14
    static let attachmentCard: CGFloat = 16
    static let glassCard: CGFloat = 20
    static let notice: CGFloat = 22
    static let heroPanel: CGFloat = 28
}

enum ControlHeight {
    static let minTouch: CGFloat = 44          // iOS minimum hit area
    static let key: CGFloat = 44
    static let mainKey: CGFloat = 50           // iOS: main call to action
    static let smallKey: CGFloat = 36          // Mac 28, raised for touch
    static let quietKey: CGFloat = 44          // Mac 40, raised for touch
    static let field: CGFloat = 44
    static let chip: CGFloat = 32              // Mac 22, raised for touch; hit area stays 44
    static let row: CGFloat = 58
    static let inputBar: CGFloat = 56
    static let avatar: CGFloat = 38
}

struct ShadowToken {
    let color: Color
    let radius: CGFloat
    var x: CGFloat = 0
    let y: CGFloat
}

enum Shadows {
    static let listCard = ShadowToken(color: .black.opacity(0.5), radius: 12, y: 6)
    static let heroPanel = ShadowToken(color: .black.opacity(0.35), radius: 28, y: 10)
    static let labelOnColor = ShadowToken(color: .black.opacity(0.22), radius: 1, y: 1)
    static let sendArrow = ShadowToken(color: .black.opacity(0.3), radius: 4, y: 1)
}

extension View {
    func dropShadow(_ token: ShadowToken) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}

// Springy on arrival, absent on exit: closing is instant or a short fade. Rest state is still.
enum Motion {
    static let hover = Animation.easeOut(duration: 0.15)          // lit colour change (iOS: pressed)
    static let pressDown = Animation.easeOut(duration: 0.07)      // key sinks
    static let pressRelease = Animation.spring(response: 0.3, dampingFraction: 0.6) // key returns
    static let iconPress = Animation.spring(response: 0.2, dampingFraction: 0.6)    // round icon, scale 0.9
    static let layout = Animation.spring(response: 0.3, dampingFraction: 0.85)      // bar or tray grows
    static let tray = Animation.spring(response: 0.36, dampingFraction: 0.84)
    static let rise = Animation.spring(response: 0.44, dampingFraction: 0.84)       // message rises in
    static let replyDelay: Double = 0.22
    static let streamReflow = Animation.easeOut(duration: 0.14)
    static let dotsToText = Animation.smooth(duration: 0.28)
    static let disclosure = Animation.spring(response: 0.3, dampingFraction: 0.86)
    static let cardArrive = Animation.spring(response: 0.7, dampingFraction: 0.86)  // stagger with .delay
    static let cardPress = Animation.spring(response: 0.26, dampingFraction: 0.7)   // scale 0.975
    static let cardSelect = Animation.spring(response: 0.42, dampingFraction: 0.72) // scale 1.045
    static let dismiss = Animation.spring(response: 0.3, dampingFraction: 0.9)      // scale 0.86 + fade
    static let appear = Animation.spring(response: 0.25, dampingFraction: 0.75)     // × appears, scale 0.7→1
    static let screenSwap = Animation.easeInOut(duration: 0.3)
    static let emptyStateSwap = Animation.easeInOut(duration: 0.45)
    static let valueChange = Animation.easeOut(duration: 0.25)    // with .contentTransition(.numericText())
    static let bloom = Animation.timingCurve(0.5, 0, 0.2, 1, duration: 1.3)
}

// Rises from below, growing and fading in; leaves with a plain fade. Used for messages and cards.
struct RiseEffect: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(0.92 + 0.08 * progress, anchor: .bottom)
            .offset(y: (1 - progress) * 46)
            .opacity(progress)
    }
}

extension AnyTransition {
    static var rise: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: RiseEffect(progress: 0), identity: RiseEffect(progress: 1)),
            removal: .opacity
        )
    }
}
