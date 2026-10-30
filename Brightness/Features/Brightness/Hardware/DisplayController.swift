import CoreGraphics
import Foundation

nonisolated enum DisplayKind: Sendable {
    case builtin
    case external
}

/// How a display's brightness is controlled.
nonisolated enum ControlMethod: Sendable {
    /// DisplayServices: built-in panels and Apple displays (Studio Display, XDR).
    case system
    /// DDC/CI over I2C: third-party external monitors.
    case ddc
    case unsupported
}

nonisolated enum DisplayError: LocalizedError {
    case ddcNoResponse
    case unsupported
    case system(Int32)

    var errorDescription: String? {
        switch self {
        case .ddcNoResponse:
            String(localized: "The monitor doesn't respond to DDC/CI commands. Turn on DDC/CI in the monitor's menu; if you use a dock or an adapter, try connecting the monitor directly.")
        case .unsupported:
            String(localized: "This display doesn't support brightness control.")
        case .system(let code):
            String(localized: "Couldn't change the brightness (error \(code)).")
        }
    }
}

/// A physical display whose brightness can (possibly) be controlled.
///
/// Implementations are only used on the `BrightnessService` worker thread.
nonisolated protocol DisplayController: AnyObject {
    var id: CGDirectDisplayID { get }
    var name: String { get }
    var kind: DisplayKind { get }
    var method: ControlMethod { get }

    /// Current brightness in percent (0–100).
    func brightness() throws -> Int
    /// Sets brightness in percent. Should return quickly; the write doesn't
    /// have to be confirmed (see `verifyBrightness`).
    func setBrightness(_ percent: Int) throws
    /// Makes sure `percent` actually took effect, re-writing it if needed.
    /// Called once a change has settled (e.g. the slider was released).
    func verifyBrightness(_ percent: Int) throws
    /// Largest change (in percent) applied in a single write; larger jumps
    /// are animated in steps of this size.
    var maxStep: Int { get }
}

nonisolated extension DisplayController {
    func verifyBrightness(_ percent: Int) throws {}
    var maxStep: Int { 100 }
}

/// A display we found but have no way to control.
nonisolated final class UnsupportedDisplay: DisplayController {
    let id: CGDirectDisplayID
    let name: String
    let kind: DisplayKind
    let method = ControlMethod.unsupported

    init(id: CGDirectDisplayID, name: String, kind: DisplayKind) {
        self.id = id
        self.name = name
        self.kind = kind
    }

    func brightness() throws -> Int { throw DisplayError.unsupported }
    func setBrightness(_ percent: Int) throws { throw DisplayError.unsupported }
}
