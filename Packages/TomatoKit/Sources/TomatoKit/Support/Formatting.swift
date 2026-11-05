import Foundation

extension TimeInterval {
    /// Countdown style: "24:59", or "1:05:00" past an hour. Rounds up so a
    /// fresh 25-minute phase reads "25:00" rather than "24:59".
    public var clockString: String {
        let total = Swift.max(0, Int(self.rounded(.up)))
        let hours = total / 3600, minutes = total % 3600 / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    /// Summary style: "2h 15m", "35m". Partial minutes are dropped.
    public var shortDuration: String {
        let minutes = Swift.max(0, Int(self) / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
