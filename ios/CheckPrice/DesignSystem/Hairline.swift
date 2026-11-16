// From notyet/ios/Views/Theme.swift (Not Yet): the 1pt divider between rows in a `FlatCard`.
import SwiftUI

struct Hairline: View {
    var body: some View { Rectangle().fill(Palette.divider).frame(height: 1) }
}
