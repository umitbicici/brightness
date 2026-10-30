import SwiftUI

/// A self-contained feature of the app (brightness control is the first one).
///
/// Each feature contributes a section to the menu bar panel and a tab to the
/// Settings window. Adding a feature means adding a type that conforms to this
/// protocol and registering it in `AppEnvironment`.
@MainActor
protocol AppFeature: AnyObject {
    /// Stable identifier, also used for persisted state.
    var id: String { get }
    /// Title of the feature's Settings tab.
    var title: String { get }
    /// SF Symbol of the feature's Settings tab.
    var systemImage: String { get }

    /// The feature's section in the menu bar panel.
    func panelSection() -> AnyView
    /// The feature's tab in the Settings window.
    func settingsView() -> AnyView

    /// Called every time the panel opens, e.g. to refresh state.
    func panelWillOpen()
}

extension AppFeature {
    func panelWillOpen() {}
}
