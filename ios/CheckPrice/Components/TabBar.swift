import SwiftUI

struct TabBar: View {
    @Binding var tab: Int
    let icons = ["sparkles", "bookmark.fill", "slider.horizontal.3"]
    var body: some View { HStack { ForEach(icons.indices, id: \.self) { index in Button { withAnimation(.easeOut(duration: 0.2)) { tab = index } } label: { Image(systemName: icons[index]).font(.system(size: 17, weight: .bold)).foregroundStyle(tab == index ? .black : AppColor.muted).frame(maxWidth: .infinity).padding(.vertical, 13).background(tab == index ? AppColor.electric : .clear, in: Capsule()) } } }.padding(5).background(AppColor.panel, in: Capsule()).overlay { Capsule().stroke(.white.opacity(0.08), lineWidth: 1) } }
}
