import Observation
import ServiceManagement

/// Launch at login through `SMAppService`, so the app shows up under
/// System Settings › General › Login Items like any other app.
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled = SMAppService.mainApp.status == .enabled
    private(set) var lastError: String?

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Turns launch at login on the first time a release build runs. After
    /// that it is entirely up to the user. (A debug build would register the
    /// temporary build product instead of the installed app.)
    func setUpOnFirstLaunch() {
        #if !DEBUG
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Preferences.Key.didSetUpLaunchAtLogin) else { return }
        setEnabled(true)
        defaults.set(true, forKey: Preferences.Key.didSetUpLaunchAtLogin)
        #endif
    }
}
