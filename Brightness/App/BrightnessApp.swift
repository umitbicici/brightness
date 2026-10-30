import SwiftUI

@main
struct BrightnessApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        MenuBarExtra(Bundle.main.displayName, systemImage: "bird.fill") {
            PanelView(environment: environment)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(environment: environment)
        }
    }
}
