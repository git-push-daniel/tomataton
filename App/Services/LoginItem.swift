import Foundation
import OSLog
import ServiceManagement

/// Opening Tomataton at login, through the system's Login Items list.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// The user turned it off in System Settings, so registering again needs their approval there.
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    /// The login item opens this copy of the app, so it should be the installed one.
    static var isRunningFromApplications: Bool {
        Bundle.main.bundleURL.deletingLastPathComponent().path.hasSuffix("/Applications")
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.app.error("Couldn't \(enabled ? "add" : "remove", privacy: .public) login item: \(error, privacy: .public)")
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
