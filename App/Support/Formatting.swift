import SwiftUI
import TomatoKit

extension Phase {
    var tint: Color {
        switch self {
        case .work: Color(red: 0.90, green: 0.30, blue: 0.24)
        case .shortBreak, .longBreak: Color(red: 0.20, green: 0.66, blue: 0.47)
        }
    }

    var symbol: String {
        isRest ? "cup.and.saucer.fill" : "timer"
    }
}
