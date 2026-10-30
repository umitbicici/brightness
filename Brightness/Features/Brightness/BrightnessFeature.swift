import AppKit
import SwiftUI

/// Brightness control for every connected display.
final class BrightnessFeature: AppFeature {
    let id = "brightness"
    let title = String(localized: "Displays")
    let systemImage = "sun.max"

    private let model = BrightnessModel()

    /// - Parameters:
    ///   - osd: Shows the brightness on the screen being adjusted.
    ///   - panelScreen: The screen the panel is open on, if any. Like the
    ///     system HUD while Control Center is open, there is no OSD on the
    ///     screen where the panel already shows the value.
    init(osd: OSDController, panelScreen: @escaping () -> NSScreen?) {
        model.onChange = { display, percent in
            guard Preferences.showOSD,
                  let screen = NSScreen.screens.first(where: { $0.displayID == display.id }),
                  panelScreen() != screen
            else { return }
            osd.show(title: display.name, percent: percent, on: screen)
        }
        Task { await model.reload(refresh: true, skeleton: true) }
    }

    func panelSection() -> AnyView {
        AnyView(BrightnessPanelSection(model: model))
    }

    func settingsView() -> AnyView {
        AnyView(BrightnessSettingsView(model: model))
    }

    func panelWillOpen() {
        Task { await model.reload() }
    }
}
