import SwiftUI

struct SignalRow: View {
    let product: Product; let action: () -> Void
    var body: some View { Button(action: action) { HStack(spacing: 13) {
        Image(systemName: product.icon).font(.system(size: 21)).frame(width: 48, height: 48).background(AppColor.soft, in: RoundedRectangle(cornerRadius: 15))
        VStack(alignment: .leading, spacing: 4) { Text(product.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1); Text(product.summary).font(.caption).foregroundStyle(AppColor.muted).lineLimit(1) }
        Spacer(); Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(AppColor.muted)
    }.padding(12).background(AppColor.panel, in: RoundedRectangle(cornerRadius: 19)) } }
}
