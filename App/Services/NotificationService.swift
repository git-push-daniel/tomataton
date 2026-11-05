import Foundation
import TomatoKit
import UserNotifications

@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func phaseFinished(_ finished: Phase, next: TimerState) {
        let defaults = UserDefaults.standard
        // The sound is played here rather than attached to the notification so
        // it can be chosen in Settings and works with notifications turned off.
        if defaults.bool(forKey: Preferences.soundEnabled) {
            AlertSound.play(defaults.string(forKey: Preferences.soundName) ?? AlertSound.defaultName)
        }
        guard defaults.bool(forKey: Preferences.notificationsEnabled) else { return }

        let content = UNMutableNotificationContent()
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
