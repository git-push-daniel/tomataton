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
    /// Mirrors the system's login item status, which can also change in System Settings.
    @State private var opensAtLogin = LoginItem.isEnabled
    @State private var loginItemNeedsApproval = LoginItem.needsApproval

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Toggle("Open at login", isOn: $opensAtLogin)
                    .onChange(of: opensAtLogin) { _, enabled in
                        guard enabled != LoginItem.isEnabled else { return }
                        LoginItem.setEnabled(enabled)
                        refreshLoginItemStatus()
                    }
                if loginItemNeedsApproval {
                    LabeledContent {
                        Button("Open System Settings…", action: LoginItem.openSystemSettings)
                    } label: {
                        Label("Allow Tomataton in Login Items to open it at login.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
                Toggle(isOn: $model.globalShortcutEnabled) {
                    Text("Start or pause with \(GlobalHotKey.toggleTimerDisplay) from any app")
                }
            } header: {
                Text("General")
            } footer: {
                if !LoginItem.isRunningFromApplications {
                    Text("This copy isn't in Applications. Install it with `make install` so login opens the installed app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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
            refreshLoginItemStatus()
            Task { await refreshNotificationStatus() }
        }
    }

    private var defaultPreset: Binding<Preset.ID> {
        Binding { model.library.defaultID } set: { model.setDefaultPreset(id: $0) }
    }

    private func refreshLoginItemStatus() {
        opensAtLogin = LoginItem.isEnabled
        loginItemNeedsApproval = LoginItem.needsApproval
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
