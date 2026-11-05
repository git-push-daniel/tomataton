import Foundation

/// Parses durations typed on the command line: "5m", "-2m", "+30s", "1h30m",
/// "1.5h", "25min". A bare number means minutes ("90" = 90 minutes).
public enum DurationParser {
    public static func seconds(from text: String) -> Int? {
        var rest = Substring(text.trimmingCharacters(in: .whitespaces).lowercased())
        var sign = 1.0
        if let first = rest.first, first == "-" || first == "+" {
            sign = first == "-" ? -1 : 1
            rest = rest.dropFirst()
        }
        guard !rest.isEmpty else { return nil }
        if let minutes = Double(rest) {
            return Int((sign * minutes * 60).rounded())
        }

        var total = 0.0
        while !rest.isEmpty {
            let number = rest.prefix { $0.isNumber || $0 == "." }
            let unit = rest.dropFirst(number.count).prefix { $0.isLetter }
            guard let value = Double(number), let multiplier = multiplier(for: unit) else { return nil }
            total += value * multiplier
            rest = rest.dropFirst(number.count + unit.count)
        }
        return Int((sign * total).rounded())
    }

    private static func multiplier(for unit: Substring) -> Double? {
        switch unit {
        case "h", "hr", "hrs", "hour", "hours": 3600
        case "m", "min", "mins", "minute", "minutes": 60
        case "s", "sec", "secs", "second", "seconds": 1
        default: nil
        }
    }
}
