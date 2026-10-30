import Foundation

/// UserDefaults keys and their defaults. Views use `@AppStorage` with these
/// keys; non-view code reads them through `Preferences`.
enum Preferences {
    enum Key {
        static let showOSD = "showOSD"
        static let didSetUpLaunchAtLogin = "didSetUpLaunchAtLogin"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.showOSD: true,
            Key.didSetUpLaunchAtLogin: false,
        ])
    }

    static var showOSD: Bool {
        UserDefaults.standard.bool(forKey: Key.showOSD)
    }
}
