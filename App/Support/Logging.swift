import OSLog
import TomatoKit

extension Logger {
    static let timer = Logger(subsystem: "com.tomataton.Tomataton", category: "timer")
}

extension TimerState {
    /// Compact one-line description for logs, e.g. "work r2/4 paused 13:07".
    func logDescription(at now: Date) -> String {
        "\(phase.rawValue) r\(round)/\(totalRounds) \(status.rawValue) \(Int(remaining(at: now)))s"
    }
}
