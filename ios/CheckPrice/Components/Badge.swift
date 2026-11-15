import SwiftUI

struct Badge: View {
    let text: String; let color: Color
    init(_ text: String, color: Color) { self.text = text; self.color = color }
    var body: some View { Text(text).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 6).background(color.opacity(0.14), in: Capsule()) }
}
