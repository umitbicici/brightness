import CoreGraphics
import Foundation
import IOKit

/// Finds the connected displays and picks a way to control each of them.
nonisolated enum DisplayEnumerator {
    static func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    /// A cheap fingerprint of the display topology, to detect connects and
    /// disconnects without a full (slow) re-enumeration.
    static func signature() -> [CGDirectDisplayID] {
        activeDisplays().sorted()
    }

    static func enumerate() -> [any DisplayController] {
        let displays: [any DisplayController] = activeDisplays().map { id in
            let builtin = CGDisplayIsBuiltin(id) != 0
            let kind: DisplayKind = builtin ? .builtin : .external
            let name = builtin ? String(localized: "Built-in Display") : productName(of: id) ?? String(localized: "Display \(id)")

            if DisplayServices.shared.canChange(id) {
                return SystemDisplay(id: id, name: name, kind: kind)
            }
            if !builtin, let (service, address) = avService(for: id) {
                return DDCDisplay(id: id, name: name, service: service, address: address)
            }
            return UnsupportedDisplay(id: id, name: name, kind: kind)
        }
        // Built-in first, then by name for a stable order.
        return displays.sorted { a, b in
            if (a.kind == .builtin) != (b.kind == .builtin) { return a.kind == .builtin }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    // MARK: Display info

    private static func info(of display: CGDirectDisplayID) -> [String: Any]? {
        CoreDisplay_DisplayCreateInfoDictionary(display) as? [String: Any]
    }

    /// Localized product name, e.g. "Odyssey G5".
    static func productName(of display: CGDirectDisplayID) -> String? {
        guard let names = info(of: display)?["DisplayProductName"] as? [String: String] else { return nil }
        let preferred = Locale.preferredLanguages.lazy.compactMap { language in
            names.first { language.hasPrefix($0.key.replacingOccurrences(of: "_", with: "-")) }?.value
        }.first
        return preferred ?? names["en_US"] ?? names.values.first
    }

    // MARK: DDC service lookup (Apple Silicon)

    private static let ddcAddress: UInt32 = 0x37
    /// M1/M2 built-in HDMI ports sit behind an MCDP29xx DisplayPort-to-HDMI
    /// bridge that answers on a different I2C address.
    private static let mcdp29xxAddress: UInt32 = 0xB7

    /// Finds the `DCPAVServiceProxy` of an external display: the first one
    /// after the display's own IORegistry entry (`IODisplayLocation`).
    static func avService(for display: CGDirectDisplayID) -> (IOAVService, UInt32)? {
        guard let location = info(of: display)?["IODisplayLocation"] as? String else { return nil }

        var iterator = io_iterator_t()
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(root) }
        guard IORegistryEntryCreateIterator(root, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively),
                                            &iterator) == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }

        var passedDisplay = false
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            if !passedDisplay {
                passedDisplay = path(of: entry) == location
                continue
            }
            guard name(of: entry) == "DCPAVServiceProxy",
                  property("Location", of: entry) as? String == "External",
                  let service = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)
            else { continue }
            return (service, i2cAddress(of: entry))
        }
        return nil
    }

    private static func i2cAddress(of service: io_registry_entry_t) -> UInt32 {
        var parent = io_registry_entry_t()
        guard IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent) == KERN_SUCCESS else {
            return ddcAddress
        }
        defer { IOObjectRelease(parent) }
        return property("EPICProviderClass", of: parent) as? String == "AppleDCPMCDP29XX" ? mcdp29xxAddress : ddcAddress
    }

    private static func path(of entry: io_registry_entry_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 1024)
        guard IORegistryEntryGetPath(entry, kIOServicePlane, &buffer) == KERN_SUCCESS else { return nil }
        return string(from: buffer)
    }

    private static func name(of entry: io_registry_entry_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 128)
        guard IORegistryEntryGetName(entry, &buffer) == KERN_SUCCESS else { return nil }
        return string(from: buffer)
    }

    private static func string(from buffer: [CChar]) -> String {
        String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func property(_ key: String, of entry: io_registry_entry_t) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault,
                                        IOOptionBits(kIORegistryIterateRecursively))?.takeRetainedValue()
    }
}
