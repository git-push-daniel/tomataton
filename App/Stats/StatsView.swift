import SwiftUI
import TomatoKit

/// The "Stats" section of the main window: one week at a time.
struct StatsView: View {
    @Environment(AppModel.self) private var model

    /// Start of the week being shown.
    @State private var weekStart = Calendar.current.week(containing: .now)?.start ?? .now
    /// Start of the day selected in the chart.
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    /// Stored sessions for the week; reloaded when the week or the history changes.
    @State private var stored: [SessionRecord] = []

    private let calendar = Calendar.current

    var body: some View {
        let week = calendar.week(containing: weekStart) ?? DateInterval(start: weekStart, duration: 7 * 86_400)
        let sessions = sessions(in: week)
        let days = Totals.daily(sessions, in: week, calendar: calendar)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(week)
                WeekSummary(days: days)
                WeekChart(days: days, selection: $selectedDay)
                    .frame(height: 190)
                Divider()
                DayDetail(day: days.first { $0.day.start == selectedDay }, sessions: sessions)
            }
            .padding(20)
        }
        .task(id: LoadKey(weekStart: week.start, revision: model.historyRevision)) {
            stored = model.storedSessions(in: week)
        }
    }

    private struct LoadKey: Equatable {
        let weekStart: Date
        let revision: Int
    }

    /// Stored sessions plus the phase in progress, if it falls in this week.
    private func sessions(in week: DateInterval) -> [SessionRecord] {
        guard let live = model.liveRecord, live.startedAt < week.end, live.endedAt > week.start else { return stored }
        return stored + [live]
    }

    // MARK: - Header

    private func header(_ week: DateInterval) -> some View {
        let isCurrentWeek = week.contains(.now)
        return HStack(spacing: 8) {
            Text(weekTitle(week))
                .font(.title3.weight(.semibold))
            Spacer()
            if !isCurrentWeek {
                Button("This Week") { show(week: .now) }
            }
            ControlGroup {
                Button("Previous Week", systemImage: "chevron.left") { move(weeks: -1, from: week) }
                Button("Next Week", systemImage: "chevron.right") { move(weeks: 1, from: week) }
                    .disabled(isCurrentWeek)
            }
            .fixedSize()
        }
    }

    private func weekTitle(_ week: DateInterval) -> String {
        let lastDay = week.end.addingTimeInterval(-1)
        let range = (week.start..<lastDay).formatted(.interval.month(.abbreviated).day())
        if week.contains(.now) { return "This week · \(range)" }
        return calendar.isDate(week.start, equalTo: .now, toGranularity: .year)
            ? range
            : "\(range), \(week.start.formatted(.dateTime.year()))"
    }

    private func move(weeks: Int, from week: DateInterval) {
        guard let date = calendar.date(byAdding: .weekOfYear, value: weeks, to: week.start) else { return }
        show(week: date)
    }

    private func show(week date: Date) {
        guard let week = calendar.week(containing: date) else { return }
        weekStart = week.start
        // Today in the current week; otherwise the week's first day.
        selectedDay = week.contains(.now) ? calendar.startOfDay(for: .now) : week.start
    }
}

// MARK: - Summary tiles

private struct WeekSummary: View {
    let days: [DayTotals]

    var body: some View {
        let worked = days.reduce(0) { $0 + $1.totals.worked }
        let rested = days.reduce(0) { $0 + $1.totals.rested }
        let pomodoros = days.reduce(0) { $0 + $1.totals.pomodoros }
        let activeDays = days.filter { $0.totals.worked > 0 }.count

        HStack(spacing: 10) {
            StatTile(label: "Focus", value: worked.shortDuration, swatch: Phase.work.tint)
            StatTile(label: "Rest", value: rested.shortDuration, swatch: Phase.shortBreak.tint)
            StatTile(label: "Pomodoros", value: "\(pomodoros)")
            StatTile(label: "Average focus day",
                     value: activeDays > 0 ? (worked / Double(activeDays)).shortDuration : "–")
        }
    }
}

struct StatTile: View {
    let label: String
    let value: String
    var swatch: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let swatch {
                    RoundedRectangle(cornerRadius: 2).fill(swatch).frame(width: 8, height: 8)
                }
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}
