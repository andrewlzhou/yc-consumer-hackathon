import SwiftUI

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(18).background(AppColor.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous)).overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1) } }
}
