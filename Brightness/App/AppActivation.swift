import AppKit

/// A menu bar app (`LSUIElement`) has no Dock icon and its windows don't come
/// to the front on their own. While a regular window is open (Settings,
/// About, update dialogs) the app becomes a regular app: Dock icon, ⌘Tab and
/// main menu, and goes back to the menu bar once the last one closes.
enum AppActivation {
    static func start() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { notification in
            let closing = notification.object as? NSWindow
            MainActor.assumeIsolated {
                DispatchQueue.main.async { returnToMenuBarIfNoWindows(except: closing) }
            }
        }
    }

    /// Call before showing a regular window.
    static func bringToFront() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func returnToMenuBarIfNoWindows(except closing: NSWindow?) {
        let hasWindows = NSApp.windows.contains { window in
            window !== closing && window.isVisible && window.styleMask.contains(.titled)
        }
        if !hasWindows { NSApp.setActivationPolicy(.accessory) }
    }
}
