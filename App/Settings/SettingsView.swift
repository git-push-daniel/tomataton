import SwiftUI
import TomatoKit
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Preferences.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(Preferences.soundEnabled) private var soundEnabled = true
    @AppStorage(Preferences.soundName) private var soundName = AlertSound.defaultName

    /// Whether macOS lets Tomataton post notifications at all.
    @State private var systemAllowsNotifications = true

    var body: some View {
        Form {
            Section("When a phase ends") {
                Toggle("Show a notification", isOn: $notificationsEnabled)
                if notificationsEnabled && !systemAllowsNotifications {
                    LabeledContent {
                        Button("Open System Settings…", action: openNotificationSettings)
                    } label: {
                        Label("Notifications are turned off for Tomataton in System Settings.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
                Toggle("Play a sound", isOn: $soundEnabled)
                Picker("Sound", selection: $soundName) {
                    ForEach(AlertSound.all, id: \.self) { Text($0) }
                }
                .disabled(!soundEnabled)
                .onChange(of: soundName) { _, name in AlertSound.play(name) }
            }

            Section {
                Picker("Default preset", selection: defaultPreset) {
                    ForEach(model.presets) { Text($0.name).tag($0.id) }
                }
            } header: {
                Text("Timer")
            } footer: {
                Text("Used when Tomataton launches. Durations and auto-start are set per preset in the main window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .task { await refreshNotificationStatus() }
        // Pick up changes made in System Settings when the user comes back.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshNotificationStatus() }
        }
    }

    private var defaultPreset: Binding<Preset.ID> {
        Binding { model.library.defaultID } set: { model.setDefaultPreset(id: $0) }
    }

    private func refreshNotificationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        systemAllowsNotifications = status == .authorized || status == .provisional
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
