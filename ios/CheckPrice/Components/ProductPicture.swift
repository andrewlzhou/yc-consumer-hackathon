// A product's picture in a rounded square: the asset-catalog image when the product has one,
// otherwise a grey tile with the product's symbol. Used by Library rows and the thread's hero.
import SwiftUI

struct ProductPicture: View {
    let product: Product
    let size: CGFloat
    var cornerRadius: CGFloat = Radius.key

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if let image = product.image {
                Image(image)
                    .resizable()
                    .scaledToFill()
            } else {
                Palette.fillChip.overlay {
                    Image(systemName: product.icon)
                        .font(.system(size: size * 0.4, weight: .light))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .accessibilityHidden(true)
    }
}
