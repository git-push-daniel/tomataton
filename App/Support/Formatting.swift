import SwiftUI
import TomatoKit

extension Phase {
    var tint: Color {
        switch self {
        case .work: Color(red: 0xe6 / 255, green: 0x4d / 255, blue: 0x3d / 255)
        // Teal-green rather than pure green: stays distinguishable from the
        // focus red with red-green color blindness (checked with the dataviz validator).
        case .shortBreak, .longBreak: Color(red: 0x16 / 255, green: 0x91 / 255, blue: 0x7f / 255)
        }
    }

    var symbol: String {
        isRest ? "cup.and.saucer.fill" : "timer"
    }
}
