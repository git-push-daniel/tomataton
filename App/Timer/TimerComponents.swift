import SwiftUI
import TomatoKit

/// Building blocks shared by the menu bar popover and the main window.

struct TimerControls: View {
    @Environment(AppModel.self) private var model
    var large = false

    var body: some View {
        let isRunning = model.state.status == .running
        let tint = model.state.phase.tint
        HStack(spacing: large ? 12 : 8) {
            Button("Restart", systemImage: "arrow.counterclockwise", action: model.restart)
                .help("Restart this phase from the beginning")
            Button(isRunning ? "Pause" : "Start", systemImage: isRunning ? "pause.fill" : "play.fill", action: model.toggle)
                .buttonStyle(ControlButtonStyle(tint: tint, prominent: true, large: large))
                .keyboardShortcut(.space, modifiers: [])
                .help("\(isRunning ? "Pause" : "Start") (Space)")
            Button("Skip", systemImage: "forward.end.fill", action: model.skip)
                .help("Skip to the next phase")
            Button("Stop", systemImage: "stop.fill", action: model.stop)
                .help("Stop and reset the whole cycle")
        }
        .buttonStyle(ControlButtonStyle(tint: tint, large: large))
    }
}

struct QuickAdjust: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 6) {
            ForEach([-5, -1, 1, 5], id: \.self) { minutes in
                Button(minutes > 0 ? "+\(minutes)" : "−\(-minutes)") { model.adjust(minutes: minutes) }
                    .help("\(minutes > 0 ? "Add" : "Remove") \(abs(minutes)) min")
            }
            Spacer(minLength: 12)
            Text("Rounds").foregroundStyle(.secondary)
            Button("Fewer rounds", systemImage: "minus") { model.adjustRounds(by: -1) }
            Text("\(model.state.round)/\(model.state.totalRounds)")
                .monospacedDigit()
                .frame(minWidth: 28)
            Button("More rounds", systemImage: "plus") { model.adjustRounds(by: 1) }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct RoundDots: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let state = model.state
        HStack(spacing: 4) {
            ForEach(1...max(state.totalRounds, 1), id: \.self) { index in
                Circle()
                    .fill(color(for: index, state: state))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityLabel("Round \(state.round) of \(state.totalRounds)")
    }

    private func color(for index: Int, state: TimerState) -> Color {
        let done = index < state.round || (index == state.round && state.phase != .work)
        if done { return Phase.work.tint }
        if index == state.round { return Phase.work.tint.opacity(0.45) }
        return .secondary.opacity(0.25)
    }
}

struct CountdownText: View {
    @Environment(AppModel.self) private var model
    var size: CGFloat

    var body: some View {
        Text(model.remaining.clockString)
            .font(.system(size: size, weight: .light, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: true))
            .foregroundStyle(model.state.status == .paused ? .secondary : .primary)
    }
}

struct PresetChips: View {
    @Environment(AppModel.self) private var model

    /// Presets beyond this many go in an overflow menu so the row fits the popover.
    private let visibleCount = 3

    var body: some View {
        let inUse = model.state.preset.id
        HStack(spacing: 6) {
            ForEach(model.presets.prefix(visibleCount)) { preset in
                let selected = preset.id == inUse
                Button { model.choose(preset) } label: {
                    VStack(spacing: 1) {
                        Text(preset.name).font(.callout.weight(.medium)).lineLimit(1)
                        Text("\(preset.workMinutes)/\(preset.shortBreakMinutes)/\(preset.longBreakMinutes)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(selected ? model.state.phase.tint : nil)
                .help("\(preset.workMinutes) min focus, \(preset.shortBreakMinutes) min break, "
                    + "\(preset.longBreakMinutes) min long break every \(preset.roundsBeforeLongBreak) rounds")
            }
            if model.presets.count > visibleCount {
                let overflow = model.presets.dropFirst(visibleCount)
                Menu("More presets", systemImage: "ellipsis") {
                    ForEach(overflow) { preset in
                        Toggle(preset.name, isOn: Binding {
                            preset.id == inUse
                        } set: { _ in
                            model.choose(preset)
                        })
                    }
                }
                .labelStyle(.iconOnly)
                .menuIndicator(.hidden)
                .fixedSize()
                .tint(overflow.contains { $0.id == inUse } ? model.state.phase.tint : nil)
                .help("More presets")
            }
        }
    }
}

struct TodayStrip: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let today = model.today
        HStack(spacing: 12) {
            Label(today.worked.shortDuration, systemImage: Phase.work.symbol)
                .foregroundStyle(Phase.work.tint)
                .help("Worked today")
            Label(today.rested.shortDuration, systemImage: Phase.shortBreak.symbol)
                .foregroundStyle(Phase.shortBreak.tint)
                .help("Rested today")
            Spacer()
            Text("\(today.pomodoros) 🍅").help("Completed focus sessions today")
        }
        .font(.callout)
        .monospacedDigit()
    }
}
