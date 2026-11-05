import SwiftUI
import TomatoKit

/// The selected day's totals and its sessions: every number in the chart
/// is readable here without hovering.
struct DayDetail: View {
    let day: DayTotals?
    /// The week's sessions; filtered to the day here.
    let sessions: [SessionRecord]

    var body: some View {
        if let day {
            let daySessions = sessions.filter { $0.startedAt < day.day.end && $0.endedAt > day.day.start }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(day.day.start.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.headline)
                    Spacer()
                    Text("\(day.totals.worked.shortDuration) focus · \(day.totals.rested.shortDuration) rest · \(day.totals.pomodoros) 🍅")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if daySessions.isEmpty {
                    Text("No sessions")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(daySessions) { session in
                            SessionRow(session: session)
                            if session.id != daySessions.last?.id { Divider() }
                        }
                    }
                }
            }
        }
    }
}

private struct SessionRow: View {
    let session: SessionRecord

    var body: some View {
        let isLive = session.id == AppModel.liveRecordID
        HStack(spacing: 10) {
            // Identity from the colored key, not colored text.
            Capsule()
                .fill(session.phase.tint)
                .frame(width: 3, height: 16)
            Text((session.startedAt..<session.endedAt).formatted(date: .omitted, time: .shortened))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 130, alignment: .leading)
            Text(session.phase.displayName)
            Spacer()
            if let note = isLive ? "In progress" : note(for: session.outcome) {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(TimeInterval(session.activeSeconds).sessionDuration)
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)
        }
        .font(.callout)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func note(for outcome: SessionRecord.Outcome) -> String? {
        switch outcome {
        case .completed: nil
        case .skipped: "Skipped"
        case .stopped: "Stopped"
        case .restarted: "Restarted"
        }
    }
}
