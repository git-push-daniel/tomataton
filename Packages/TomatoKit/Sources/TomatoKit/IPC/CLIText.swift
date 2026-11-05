import Foundation

/// Plain-text rendering of app state for the terminal.
public struct CLIText: Sendable {
    public var locale: Locale
    public var calendar: Calendar
    /// ANSI colors for the stats bars. Without color, rest uses a lighter
    /// block so focus and rest stay distinguishable.
    public var color: Bool

    public init(locale: Locale = .current, calendar: Calendar = .current, color: Bool = false) {
        self.locale = locale
        self.calendar = calendar
        self.color = color
    }

    // MARK: - Status

    /// One short token for shell prompts and status bars: "🍅 18:42",
    /// "☕ 3:12", "⏸ 18:42", or "" when nothing has started.
    public func short(_ status: StatusSnapshot) -> String {
        let clock = TimeInterval(status.remainingSeconds).clockString
        switch status.status {
        case .ready: return ""
        case .paused: return "⏸ \(clock)"
        case .running: return "\(status.phase.isRest ? "☕" : "🍅") \(clock)"
        }
    }

    public func status(_ status: StatusSnapshot) -> String {
        let clock = TimeInterval(status.remainingSeconds).clockString
        let state = switch status.status {
        case .ready: "\(clock) · ready to start"
        case .running: "\(clock) left"
        case .paused: "\(clock) left · paused"
        }
        return """
        \(status.phase.displayName) · \(state)
        Round \(status.round) of \(status.totalRounds) · \(status.presetName)
        Today: \(summary(status.today))
        """
    }

    // MARK: - Presets

    public func presets(_ list: PresetList) -> String {
        let width = list.presets.map(\.name.count).max() ?? 0
        return list.presets.map { preset in
            let marker = preset.id == list.inUseID ? "▸" : " "
            let name = preset.name.padding(toLength: width, withPad: " ", startingAt: 0)
            let durations = "\(preset.workMinutes)/\(preset.shortBreakMinutes)/\(preset.longBreakMinutes) min ×\(preset.roundsBeforeLongBreak)"
            var notes: [String] = []
            if preset.id == list.defaultID { notes.append("default") }
            if preset.id == list.inUseID { notes.append("in use") }
            return "\(marker) \(name)  \(durations)\(notes.isEmpty ? "" : "  (\(notes.joined(separator: ", ")))")"
        }.joined(separator: "\n")
    }

    // MARK: - Stats

    public func stats(_ report: StatsReport) -> String {
        switch report.range {
        case .today:
            let day = report.days.first
            let label = day.map { format($0.day, .dateTime.weekday(.abbreviated).day().month(.abbreviated)) } ?? ""
            return "Today (\(label)): \(day.map(summary) ?? "nothing yet")"
        case .week:
            return week(report)
        }
    }

    private func week(_ report: StatsReport) -> String {
        let barWidth = 20
        let longest = report.days.map { $0.workedSeconds + $0.restedSeconds }.max() ?? 0
        let lines = report.days.map { day -> String in
            let label = format(day.day, .dateTime.weekday(.abbreviated).day())
                .padding(toLength: 7, withPad: " ", startingAt: 0)
            guard day.workedSeconds + day.restedSeconds > 0 else { return "\(label) –" }
            // Split the day's total cells, so rounding never makes a bar wider than the scale.
            let totalCells = cells(day.workedSeconds + day.restedSeconds, of: longest, width: barWidth)
            var focusCells = min(cells(day.workedSeconds, of: longest, width: barWidth), totalCells)
            if day.restedSeconds > 0, focusCells == totalCells, focusCells > 1 { focusCells -= 1 }
            let restCells = totalCells - focusCells
            let bar = paint(String(repeating: "█", count: focusCells), ansi: 31)
                + paint(String(repeating: color ? "█" : "▒", count: restCells), ansi: 36)
            let padding = String(repeating: " ", count: max(0, barWidth - focusCells - restCells))
            return "\(label) \(bar)\(padding)  \(summary(day))"
        }
        let total = DaySummary(
            day: report.start,
            totals: Totals(
                worked: TimeInterval(report.days.map(\.workedSeconds).reduce(0, +)),
                rested: TimeInterval(report.days.map(\.restedSeconds).reduce(0, +)),
                pomodoros: report.days.map(\.pomodoros).reduce(0, +)
            )
        )
        let lastDay = report.end.addingTimeInterval(-1)
        let title = "Week of \(format(report.start, .dateTime.day().month(.abbreviated))) – \(format(lastDay, .dateTime.day().month(.abbreviated).year()))"
        let legend = "\(paint("█", ansi: 31)) focus  \(paint(color ? "█" : "▒", ansi: 36)) rest"
        return ([title, legend, ""] + lines + ["", "Total: \(summary(total))"]).joined(separator: "\n")
    }

    // MARK: - Helpers

    private func summary(_ day: DaySummary) -> String {
        "\(TimeInterval(day.workedSeconds).shortDuration) focus · "
            + "\(TimeInterval(day.restedSeconds).shortDuration) rest · \(day.pomodoros) 🍅"
    }

    /// Rounded so any non-zero amount gets at least one cell.
    private func cells(_ seconds: Int, of longest: Int, width: Int) -> Int {
        guard seconds > 0, longest > 0 else { return 0 }
        return max(1, Int((Double(seconds) / Double(longest) * Double(width)).rounded()))
    }

    private func paint(_ text: String, ansi code: Int) -> String {
        color ? "\u{1B}[\(code)m\(text)\u{1B}[0m" : text
    }

    private func format(_ date: Date, _ style: Date.FormatStyle) -> String {
        var style = style
        style.locale = locale
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }
}

extension Totals {
    init(worked: TimeInterval, rested: TimeInterval, pomodoros: Int) {
        self.init()
        self.worked = worked
        self.rested = rested
        self.pomodoros = pomodoros
    }
}
