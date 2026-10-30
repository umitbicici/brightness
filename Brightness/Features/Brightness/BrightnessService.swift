import CoreGraphics
import Foundation

/// What the UI gets for each display.
nonisolated struct DisplaySnapshot: Sendable, Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    let kind: DisplayKind
    let method: ControlMethod
    /// Brightness in percent, `nil` if it could not be read.
    let brightness: Int?
    let error: String?
}

/// Owns all display handles on a single worker thread.
///
/// DDC/CI is slow (tens of milliseconds per transaction) and must not be
/// accessed concurrently, so every request goes through this thread.
///
/// Brightness changes are modelled as transitions towards a target: while the
/// slider moves, the target keeps changing and the worker steps towards it
/// with fast, unconfirmed writes (big jumps are animated in small steps). Once
/// the change is committed (slider released) or has been idle for a moment,
/// the final value is verified against the monitor.
nonisolated final class BrightnessService: @unchecked Sendable {
    /// How long a change must be idle before it is verified, for input
    /// without an explicit "release" (keyboard, scroll).
    static let verifyDelay: TimeInterval = 0.4

    private enum Request {
        case list(refresh: Bool, reply: @Sendable ([DisplaySnapshot]) -> Void)
        case set(display: CGDirectDisplayID, percent: Int, commit: Bool, reply: @Sendable (Error?) -> Void)
    }

    /// An in-progress brightness change of one display.
    private struct Transition {
        var target: Int
        /// Last value written; `nil` if unknown (then we jump straight to target).
        var current: Int?
        var commit: Bool
        /// When `current` reached `target`; `nil` while still moving.
        var settledAt: Date?
        var reply: (@Sendable (Error?) -> Void)?

        var isMoving: Bool { settledAt == nil }

        func verifyDue(at now: Date) -> Bool {
            guard let settledAt else { return false }
            return commit || now >= settledAt.addingTimeInterval(BrightnessService.verifyDelay)
        }
    }

    private let condition = NSCondition()
    private var queue: [Request] = []

    // Worker thread state.
    private var displays: [any DisplayController] = []
    private var signature: [CGDirectDisplayID]?
    private var transitions: [CGDirectDisplayID: Transition] = [:]
    /// Last known brightness per display, the starting point of transitions.
    private var known: [CGDirectDisplayID: Int] = [:]

    init() {
        let thread = Thread { [unowned self] in run() }
        thread.name = "BrightnessService"
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    // MARK: API

    /// Lists displays with their current brightness. `refresh` forces a full
    /// re-enumeration; otherwise it only happens when the topology changed.
    func list(refresh: Bool) async -> [DisplaySnapshot] {
        await withCheckedContinuation { continuation in
            enqueue(.list(refresh: refresh) { continuation.resume(returning: $0) })
        }
    }

    /// Moves a display towards `percent`. Returns once the target is reached,
    /// or when superseded by a newer value for the same display.
    func setBrightness(_ percent: Int, of display: CGDirectDisplayID, commit: Bool) async throws {
        let error: Error? = await withCheckedContinuation { continuation in
            enqueue(.set(display: display, percent: percent, commit: commit) { continuation.resume(returning: $0) })
        }
        if let error { throw error }
    }

    private func enqueue(_ request: Request) {
        condition.lock()
        queue.append(request)
        condition.signal()
        condition.unlock()
    }

    // MARK: Worker

    private func run() {
        while true {
            condition.lock()
            if queue.isEmpty {
                if transitions.values.contains(where: \.isMoving) {
                    // Keep stepping without waiting.
                } else if let due = transitions.values.compactMap(\.settledAt).min() {
                    condition.wait(until: due.addingTimeInterval(Self.verifyDelay))
                } else {
                    condition.wait()
                }
            }
            let requests = queue
            queue.removeAll()
            condition.unlock()

            requests.forEach(handle)
            step()
            verify()
        }
    }

    private func handle(_ request: Request) {
        switch request {
        case let .list(refresh, reply):
            reply(list(refresh: refresh))

        case let .set(display, percent, commit, reply):
            ensureEnumerated(force: false)
            var transition = transitions[display]
                ?? Transition(target: percent, current: known[display], commit: false, settledAt: nil, reply: nil)
            transition.reply?(nil) // superseded
            transition.reply = reply
            transition.target = min(max(percent, 0), 100)
            transition.commit = commit
            transition.settledAt = nil
            transitions[display] = transition
        }
    }

    static func step(from current: Int, towards target: Int, maxStep: Int) -> Int {
        current < target ? min(current + maxStep, target) : max(current - maxStep, target)
    }

    /// Advances every moving transition by one write.
    private func step() {
        for (id, var transition) in transitions where transition.isMoving {
            guard let display = displays.first(where: { $0.id == id }) else {
                transitions[id] = nil
                transition.reply?(DisplayError.unsupported)
                continue
            }
            let next = transition.current.map {
                Self.step(from: $0, towards: transition.target, maxStep: display.maxStep)
            } ?? transition.target
            do {
                try display.setBrightness(next)
            } catch {
                transitions[id] = nil
                transition.reply?(error)
                continue
            }
            transition.current = next
            known[id] = next
            if next == transition.target {
                transition.settledAt = Date()
                transition.reply?(nil)
                transition.reply = nil
            }
            transitions[id] = transition
        }
    }

    /// Verifies settled transitions that were committed or have been idle.
    private func verify() {
        let now = Date()
        for (id, transition) in transitions where transition.verifyDue(at: now) {
            transitions[id] = nil
            try? displays.first { $0.id == id }?.verifyBrightness(transition.target)
        }
    }

    private func ensureEnumerated(force: Bool) {
        let current = DisplayEnumerator.signature()
        guard force || signature != current else { return }
        displays = DisplayEnumerator.enumerate()
        signature = current
        for transition in transitions.values {
            transition.reply?(nil)
        }
        transitions.removeAll()
        known.removeAll()
    }

    private func list(refresh: Bool) -> [DisplaySnapshot] {
        ensureEnumerated(force: refresh)
        return displays.map { display in
            var brightness: Int?
            var message: String?
            if let transition = transitions[display.id] {
                // Mid-transition: report where we are heading.
                brightness = transition.target
            } else {
                do {
                    brightness = try display.brightness()
                    known[display.id] = brightness
                } catch {
                    NSLog("%@: %@", display.name, String(describing: error))
                    message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
            return DisplaySnapshot(id: display.id, name: display.name, kind: display.kind,
                                   method: display.method, brightness: brightness, error: message)
        }
    }
}
