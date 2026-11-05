import AppKit

/// UserDefaults keys for simple app preferences, read with `@AppStorage` in views.
enum Preferences {
    static let notificationsEnabled = "notificationsEnabled"
    static let soundEnabled = "soundEnabled"
    static let soundName = "soundName"

    /// Registered at launch so `@AppStorage` and direct reads agree on defaults.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            notificationsEnabled: true,
            soundEnabled: true,
            soundName: AlertSound.defaultName,
        ])
    }
}

enum AlertSound {
    static let defaultName = "Glass"
    /// The sounds macOS ships in /System/Library/Sounds.
    static let all = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    static func play(_ name: String) {
        NSSound(named: name)?.play()
    }
}
