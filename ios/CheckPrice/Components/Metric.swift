import SwiftUI

struct Metric: View {
    let title: String; let value: String
    var body: some View { VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(AppColor.muted); Text(value).font(.system(size: 19, weight: .bold, design: .rounded)) } }
}
