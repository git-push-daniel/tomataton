import SwiftUI
import UserNotifications

@main
struct TomatatonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("Tomataton", id: WindowID.main) {
            MainWindow()
                .environment(model)
        }
        // The window can shrink a little but never grow past its default size.
        .windowResizability(.contentSize)
        .defaultSize(MainWindow.maxSize)
        #if DEBUG
        .commands {
            CommandMenu("Debug") {
                Button("Add Sample History") { model.addSampleHistory() }
                Button("Remove Sample History") { model.removeSampleHistory() }
            }
        }
        #endif

        MenuBarExtra {
            PopoverView()
                .environment(model)
        } label: {
            MenuBarLabel()
                .environment(model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

enum WindowID {
    static let main = "main"
}

enum LaunchArgument {
    /// Start in the menu bar without opening the main window.
    static let background = "--background"
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var terminationSignal: (any DispatchSourceSignal)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        quitNormallyOnSIGTERM()
        if launchedInBackground {
            // Opened at login or by the CLI: stay in the menu bar. SwiftUI has
            // already created the window by now; the Dock icon brings it back.
            NSApp.windows.filter { $0.identifier?.rawValue == WindowID.main }.forEach { $0.close() }
        }
        #if DEBUG
        DebugSnapshot.runIfRequested()
        #endif
    }

    /// True when launched as a login item or with `--background` (as the CLI does).
    /// The launch Apple event is only available while the app finishes launching.
    private var launchedInBackground: Bool {
        if CommandLine.arguments.contains(LaunchArgument.background) { return true }
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    /// `kill`/`pkill` (and so `make run`) send SIGTERM, which would end the
    /// process immediately. Turn it into a normal quit so the timer is paused
    /// and saved like it is for ⌘Q.
    private func quitNormallyOnSIGTERM() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { NSApp.terminate(nil) }
        }
        source.resume()
        terminationSignal = source
    }

    // Closing the window keeps the timer running in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // Show banners even while Tomataton is the frontmost app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
