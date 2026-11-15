import SwiftUI

struct ReportView: View {
    let product: Product
    @Environment(\.dismiss) private var dismiss
    @State private var saved = false
    private let values: [CGFloat] = [0.74, 0.65, 0.72, 0.51, 0.58, 0.46, 0.39, 0.43, 0.28, 0.31]

    var body: some View {
        ScrollView(showsIndicators: false) { VStack(alignment: .leading, spacing: 23) {
            HStack { Button(action: { dismiss() }) { Image(systemName: "xmark").font(.headline).frame(width: 38, height: 38).background(AppColor.panel, in: Circle()) }; Spacer(); Badge(product.verdict.rawValue, color: .yellow) }
            VStack(alignment: .leading, spacing: 6) { Text(product.name).font(.system(size: 31, weight: .bold, design: .rounded)); Text("\(product.retailer) · Today \(product.price)").foregroundStyle(AppColor.muted) }
            Card { VStack(alignment: .leading, spacing: 18) {
                HStack { Text("PRICE HISTORY").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.2).foregroundStyle(AppColor.muted); Spacer(); Text("2 years").font(.caption).foregroundStyle(AppColor.electric) }
                chart.frame(height: 154)
                HStack { Text("Historical low  $299"); Spacer(); Text("Average  $337") }.font(.caption).foregroundStyle(AppColor.muted)
            } }
            Card { VStack(alignment: .leading, spacing: 14) {
                Text("THE SIGNAL").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.2).foregroundStyle(AppColor.muted)
                Text("Wait for \(product.projectedLow)." ).font(.system(size: 25, weight: .bold, design: .rounded))
                Text("This model has fallen during major November sales in each of the last two years. Today’s advertised discount is not close to its usual low.").font(.subheadline).foregroundStyle(AppColor.muted).lineSpacing(4)
            } }
            Button { saved.toggle() } label: { Label(saved ? "Watching this price" : "Save & alert me", systemImage: saved ? "checkmark.circle.fill" : "bookmark.fill").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 17).background(AppColor.electric, in: Capsule()) }
            Text("Saving is a prototype interaction. It will connect to Convex later.").font(.footnote).foregroundStyle(AppColor.muted).frame(maxWidth: .infinity).multilineTextAlignment(.center)
        }.padding(20).padding(.bottom, 30) }.preferredColorScheme(.dark)
    }

    private var chart: some View {
        GeometryReader { proxy in
            Path { path in
                for (index, value) in values.enumerated() {
                    let point = CGPoint(x: proxy.size.width * CGFloat(index) / CGFloat(values.count - 1), y: proxy.size.height * value)
                    index == 0 ? path.move(to: point) : path.addLine(to: point)
                }
            }.stroke(LinearGradient(colors: [.mint, .cyan], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}
