import SwiftUI

/// The "Timer" section of the main window: a progress ring around the countdown.
struct TimerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let phase = model.state.phase
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: model.progress)
                    .stroke(phase.tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: model.progress)
                VStack(spacing: 6) {
                    Text(phase.displayName.uppercased())
                        .font(.headline)
                        .foregroundStyle(phase.tint)
                    CountdownText(size: 64)
                    RoundDots()
                }
            }
            .frame(width: 220, height: 220)

            TimerControls(large: true)

            VStack(spacing: 12) {
                QuickAdjust()
                PresetChips()
                Divider()
                TodayStrip()
            }
            .frame(maxWidth: 380)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
