import AppKit
import Observation
import Sparkle

/// Self-update through Sparkle, with an appcast published on GitHub Releases.
@Observable
final class Updater: NSObject, SPUStandardUserDriverDelegate {
    @ObservationIgnored private var controller: SPUStandardUpdaterController!

    private(set) var canCheckForUpdates = false

    var automaticallyChecksForUpdates: Bool {
        get {
            access(keyPath: \.automaticallyChecksForUpdates)
            return controller.updater.automaticallyChecksForUpdates
        }
        set {
            withMutation(keyPath: \.automaticallyChecksForUpdates) {
                controller.updater.automaticallyChecksForUpdates = newValue
            }
        }
    }

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
        canCheckForUpdates = controller.updater.canCheckForUpdates
        observation = controller.updater.observe(\.canCheckForUpdates) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheckForUpdates = updater.canCheckForUpdates }
        }
    }

    @ObservationIgnored private var observation: NSKeyValueObservation?

    func checkForUpdates() {
        // A menu bar app has no Dock icon: bring Sparkle's window to the front.
        AppActivation.bringToFront()
        controller.checkForUpdates(nil)
    }

    // MARK: SPUStandardUserDriverDelegate

    /// Background (menu bar) apps should use gentle reminders for scheduled
    /// update checks instead of popping up a window out of nowhere.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }
}
