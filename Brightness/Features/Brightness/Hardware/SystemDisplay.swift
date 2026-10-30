import CoreGraphics
import Foundation

/// The private DisplayServices framework: the same path the brightness keys
/// use for built-in panels and Apple displays.
nonisolated final class DisplayServices: Sendable {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias CanChangeBrightness = @convention(c) (CGDirectDisplayID) -> Bool

    static let shared = DisplayServices()

    private let getBrightness: GetBrightness?
    private let setBrightness: SetBrightness?
    private let canChangeBrightness: CanChangeBrightness?

    private init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        func load<T>(_ symbol: String, as type: T.Type) -> T? {
            guard let handle, let pointer = dlsym(handle, symbol) else { return nil }
            return unsafeBitCast(pointer, to: type)
        }
        getBrightness = load("DisplayServicesGetBrightness", as: GetBrightness.self)
        setBrightness = load("DisplayServicesSetBrightness", as: SetBrightness.self)
        canChangeBrightness = load("DisplayServicesCanChangeBrightness", as: CanChangeBrightness.self)
    }

    func canChange(_ display: CGDirectDisplayID) -> Bool {
        canChangeBrightness?(display) ?? false
    }

    func brightness(of display: CGDirectDisplayID) throws -> Float {
        guard let getBrightness else { throw DisplayError.unsupported }
        var value: Float = 0
        let result = getBrightness(display, &value)
        guard result == 0 else { throw DisplayError.system(result) }
        return value
    }

    func setBrightness(_ value: Float, of display: CGDirectDisplayID) throws {
        guard let setBrightness else { throw DisplayError.unsupported }
        let result = setBrightness(display, value)
        guard result == 0 else { throw DisplayError.system(result) }
    }
}

/// Built-in panel or Apple display, controlled through DisplayServices.
nonisolated final class SystemDisplay: DisplayController {
    let id: CGDirectDisplayID
    let name: String
    let kind: DisplayKind
    let method = ControlMethod.system

    init(id: CGDirectDisplayID, name: String, kind: DisplayKind) {
        self.id = id
        self.name = name
        self.kind = kind
    }

    func brightness() throws -> Int {
        let value = try DisplayServices.shared.brightness(of: id)
        return Int((min(max(value, 0), 1) * 100).rounded())
    }

    func setBrightness(_ percent: Int) throws {
        try DisplayServices.shared.setBrightness(Float(min(max(percent, 0), 100)) / 100, of: id)
    }
}
