import Foundation
import Testing
import TomatoKit

@Suite struct FormattingTests {
    @Test(arguments: [
        (0.0, "0:00"),
        (0.2, "0:01"),
        (59.0, "0:59"),
        (59.4, "1:00"),
        (1499.3, "25:00"),
        (1500.0, "25:00"),
        (3599.0, "59:59"),
        (3600.0, "1:00:00"),
        (3661.0, "1:01:01"),
        (-5.0, "0:00"),
    ])
    func clockString(seconds: TimeInterval, expected: String) {
        #expect(seconds.clockString == expected)
    }

    @Test(arguments: [
        (0.0, "0m"),
        (59.0, "0m"),
        (60.0, "1m"),
        (2100.0, "35m"),
        (3600.0, "1h"),
        (3659.0, "1h"),
        (3660.0, "1h 1m"),
        (8100.0, "2h 15m"),
        (-60.0, "0m"),
    ])
    func shortDuration(seconds: TimeInterval, expected: String) {
        #expect(seconds.shortDuration == expected)
    }

    @Test(arguments: [
        (0.0, "0s"),
        (45.0, "45s"),
        (59.9, "59s"),
        (60.0, "1m"),
        (1500.0, "25m"),
        (3900.0, "1h 5m"),
    ])
    func sessionDuration(seconds: TimeInterval, expected: String) {
        #expect(seconds.sessionDuration == expected)
    }
}
