// The prototype's colour names, now pointing at the Worldscape palette so screens compile before
// they are restyled. New code should use `Palette`, `TextStyle` and the DesignSystem components;
// delete this file once no screen uses `AppColor`.
import SwiftUI

enum AppColor {
    static let ink = Palette.canvas            // app background (was near-black #0D0E12)
    static let panel = Palette.fillBar         // card and bar fill (was dark grey)
    static let soft = Palette.fillChip         // icon tiles (was a lighter grey)
    static let muted = Palette.textSecondary   // secondary text
    static let electric = Palette.electric     // the accent (was mint green; now Worldscape blue)
}
