import CoreGraphics
import Observation
import SwiftUI

/// UI state of the brightness feature, backed by `BrightnessService`.
@Observable
final class BrightnessModel {
    /// Skeletons stay up at least this long so they don't just flash.
    private static let minimumSkeletonDuration: Duration = .milliseconds(450)

    private(set) var displays: [DisplaySnapshot] = []
    /// Slider positions (0…1), by display.
    private(set) var values: [CGDirectDisplayID: Double] = [:]
    /// Errors from writes, shown in place of the error from the last read.
    private(set) var writeErrors: [CGDirectDisplayID: String] = [:]
    private(set) var isLoading = false
    private(set) var showsSkeleton = true

    /// Called for every brightness change made through the UI (drives the OSD).
    @ObservationIgnored var onChange: (DisplaySnapshot, Int) -> Void = { _, _ in }

    @ObservationIgnored private let service = BrightnessService()
    /// Displays whose slider is being dragged or whose writes are in flight:
    /// their sliders aren't overwritten by values read back from hardware.
    @ObservationIgnored private var editing: Set<CGDirectDisplayID> = []
    @ObservationIgnored private var inFlight: [CGDirectDisplayID: Int] = [:]
    @ObservationIgnored private var sequence: [CGDirectDisplayID: Int] = [:]

    /// Loads the displays. `refresh` re-enumerates them; `skeleton` shows
    /// placeholders while loading (first load, manual refresh).
    func reload(refresh: Bool = false, skeleton: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        if skeleton { withAnimation(.smooth(duration: 0.2)) { showsSkeleton = true } }

        let start = ContinuousClock.now
        let snapshots = await service.list(refresh: refresh)
        if skeleton {
            try? await Task.sleep(until: start + Self.minimumSkeletonDuration)
        }

        withAnimation(.smooth(duration: 0.35)) {
            displays = snapshots
            for display in snapshots where !editing.contains(display.id) && inFlight[display.id, default: 0] == 0 {
                values[display.id] = display.brightness.map { Double($0) / 100 }
            }
            writeErrors = writeErrors.filter { id, _ in snapshots.contains { $0.id == id } }
            showsSkeleton = false
        }
    }

    func value(of display: DisplaySnapshot) -> Double? {
        values[display.id]
    }

    func error(of display: DisplaySnapshot) -> String? {
        writeErrors[display.id] ?? display.error
    }

    func setEditing(_ isEditing: Bool, display: DisplaySnapshot) {
        if isEditing {
            editing.insert(display.id)
        } else {
            editing.remove(display.id)
            // Released: write the final value and verify it right away.
            if let value = values[display.id] { setValue(value, of: display, commit: true) }
        }
    }

    func setValue(_ value: Double, of display: DisplaySnapshot, commit: Bool = false) {
        values[display.id] = value
        let percent = Int((value * 100).rounded())
        onChange(display, percent)

        let id = display.id
        sequence[id, default: 0] += 1
        let current = sequence[id]
        inFlight[id, default: 0] += 1
        Task {
            defer { inFlight[id, default: 1] -= 1 }
            do {
                try await service.setBrightness(percent, of: id, commit: commit)
                if sequence[id] == current { withAnimation { writeErrors[id] = nil } }
            } catch {
                if sequence[id] == current {
                    withAnimation { writeErrors[id] = (error as? LocalizedError)?.errorDescription }
                }
            }
        }
    }
}
