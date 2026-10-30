import AppKit

/// App-wide services and the list of features, shared by all scenes.
final class AppEnvironment {
    let updater = Updater()
    let launchAtLogin = LaunchAtLogin()
    let panel = PanelWindow()
    let features: [any AppFeature]

    private let osd = OSDController()

    init() {
        Preferences.registerDefaults()
        AppActivation.start()
        launchAtLogin.setUpOnFirstLaunch()

        let panel = panel
        features = [
            BrightnessFeature(osd: osd, panelScreen: { panel.visibleScreen }),
        ]
        panel.onOpen = { [features] in features.forEach { $0.panelWillOpen() } }
    }
}
