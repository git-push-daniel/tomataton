import SwiftUI

/// Icon only while idle; icon + countdown once a phase has started.
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let state = model.state
        if state.status == .ready {
            Image(systemName: "timer")
        } else {
            HStack(spacing: 4) {
                Image(systemName: state.status == .paused ? "pause.circle" : state.phase.symbol)
                Text(model.remaining.clockString).monospacedDigit()
            }
        }
    }
}
