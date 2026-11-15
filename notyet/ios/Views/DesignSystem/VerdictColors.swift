// Target membership: app only.
// Verdict colours as SwiftUI colours. Words, symbols and hex values live on `Verdict` in
// App/Models.swift so every screen and the widget agree. Worldscape has no verdict colours: green
// and amber are kept from the original design, red is Worldscape's danger, and the two newer
// verdicts use lavender and coral so none of them is mistaken for the blue accent.
import SwiftUI

extension Verdict {
    var color: Color { Color(hex: rgb) }
}
