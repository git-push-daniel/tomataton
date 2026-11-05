import TomatoKit
import UserNotifications

@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func phaseFinished(_ finished: Phase, next: TimerState) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch finished {
        case .work:
            content.title = "Focus session done"
            content.body = "Time for a \(next.phase.displayName.lowercased())."
        case .shortBreak, .longBreak:
            content.title = "Break's over"
            content.body = next.status == .running
                ? "Round \(next.round) has started."
                : "Ready for round \(next.round)? Start when you are."
        }
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
