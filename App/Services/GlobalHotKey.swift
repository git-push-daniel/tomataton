import Carbon.HIToolbox
import OSLog

/// A keyboard shortcut that works while other apps are in front. Uses Carbon's
/// hot key API, which, unlike watching every key press, needs no Accessibility permission.
@MainActor
final class GlobalHotKey {
    /// The shortcut shown in Settings and the README.
    static let toggleTimerDisplay = "⌃⌥⌘P"

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    /// ⌃⌥⌘P by default. Returns nil if the shortcut is taken by another app.
    init?(keyCode: Int = kVK_ANSI_P, modifiers: Int = controlKey | optionKey | cmdKey, action: @escaping () -> Void) {
        self.action = action
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { hotKey.action() }  // Carbon delivers events on the main thread
            return noErr
        }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), &handler)

        let id = EventHotKeyID(signature: OSType(0x544D_544E), id: 1)  // "TMTN"
        let registered = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id,
                                             GetApplicationEventTarget(), 0, &hotKey)
        guard installed == noErr, registered == noErr else {
            Logger.app.error("Couldn't register global shortcut (\(installed), \(registered))")
            unregister()
            return nil
        }
    }

    /// Call before dropping the last reference; the handler holds an unretained pointer to self.
    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
    }
}
