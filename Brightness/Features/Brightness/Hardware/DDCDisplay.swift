import CoreGraphics
import Foundation
import IOKit

/// Third-party external monitor, controlled over DDC/CI (Apple Silicon).
nonisolated final class DDCDisplay: DisplayController {
    /// Minimum gap between DDC/CI transactions. Back-to-back commands get
    /// silently dropped (seen on a Samsung Odyssey G5). The spec asks for
    /// 50 ms, but monitors tolerate much less in practice, and the final value
    /// of every change is verified, so a dropped intermediate write only costs
    /// a little smoothness.
    static let commandGap: Duration = .milliseconds(25)
    /// Time the monitor needs to prepare a reply to a read request.
    static let replyDelay: Duration = .milliseconds(40)
    static let attempts = 3

    private static let brightnessCode: UInt8 = 0x10
    private static let hostAddress: UInt8 = 0x51
    /// Checksum seeds: destination address 0x6E for writes, 0x6F ^ 0x51 for replies.
    private static let writeChecksumSeed: UInt8 = 0x6E ^ 0x51
    private static let replyChecksumSeed: UInt8 = 0x6F ^ 0x51

    let id: CGDirectDisplayID
    let name: String
    let kind = DisplayKind.external
    let method = ControlMethod.ddc
    let maxStep = 4

    private let service: IOAVService
    private let address: UInt32
    private let clock = ContinuousClock()
    private var lastCommand: ContinuousClock.Instant?
    /// Maximum raw brightness reported by the monitor (often 100, not always).
    private var maximum: Int?
    /// Raw value we believe the monitor is at, to skip redundant writes.
    private var lastValue: Int?

    init(id: CGDirectDisplayID, name: String, service: IOAVService, address: UInt32) {
        self.id = id
        self.name = name
        self.service = service
        self.address = address
    }

    // MARK: DisplayController

    func brightness() throws -> Int {
        let (current, maximum) = try readBrightness()
        return Self.percent(raw: current, maximum: maximum)
    }

    func setBrightness(_ percent: Int) throws {
        let raw = try rawValue(percent)
        guard raw != lastValue else { return }
        try writeBrightness(raw)
    }

    func verifyBrightness(_ percent: Int) throws {
        let raw = try rawValue(percent)
        // Some monitors acknowledge a write and then silently drop it.
        for _ in 0..<Self.attempts {
            guard let (current, _) = try? readBrightness() else { return } // write-only monitor
            if current == raw { return }
            try writeBrightness(raw)
        }
    }

    // MARK: Conversions

    static func percent(raw: Int, maximum: Int) -> Int {
        guard maximum > 0 else { return 0 }
        return min(100, Int((Double(raw) / Double(maximum) * 100).rounded()))
    }

    static func raw(percent: Int, maximum: Int) -> Int {
        Int((Double(min(max(percent, 0), 100)) / 100 * Double(maximum)).rounded())
    }

    private func rawValue(_ percent: Int) throws -> Int {
        let maximum = try maximum ?? readBrightness().maximum
        return Self.raw(percent: percent, maximum: maximum)
    }

    // MARK: DDC/CI

    private func readBrightness() throws -> (current: Int, maximum: Int) {
        let reply = try transact { try self.readVCP(Self.brightnessCode) }
        maximum = reply.maximum
        lastValue = reply.current
        return reply
    }

    private func writeBrightness(_ raw: Int) throws {
        let value = UInt16(clamping: raw)
        try transact { try self.write([0x03, Self.brightnessCode, UInt8(value >> 8), UInt8(value & 0xFF)]) }
        lastValue = raw
    }

    /// Runs one DDC/CI transaction, keeping the required gap to the previous
    /// one and retrying a few times (I2C is flaky on some adapters/ports).
    private func transact<T>(_ operation: () throws -> T) throws -> T {
        for _ in 0..<Self.attempts {
            if let lastCommand {
                let wait = Self.commandGap - lastCommand.duration(to: clock.now)
                if wait > .zero { Thread.sleep(forTimeInterval: wait.seconds) }
            }
            defer { lastCommand = clock.now }
            if let result = try? operation() { return result }
        }
        throw DisplayError.ddcNoResponse
    }

    private func write(_ payload: [UInt8]) throws {
        var packet = [0x80 | UInt8(payload.count)] + payload
        packet.append(packet.reduce(Self.writeChecksumSeed, ^))
        let result = IOAVServiceWriteI2C(service, address, UInt32(Self.hostAddress), packet, UInt32(packet.count))
        guard result == kIOReturnSuccess else { throw DisplayError.ddcNoResponse }
    }

    /// Reads a VCP feature: returns (current, maximum).
    private func readVCP(_ code: UInt8) throws -> (current: Int, maximum: Int) {
        try write([0x01, code])
        Thread.sleep(forTimeInterval: Self.replyDelay.seconds)
        var reply = [UInt8](repeating: 0, count: 11)
        let result = IOAVServiceReadI2C(service, address, 0, &reply, UInt32(reply.count))
        // [1] length, [2] 0x02 = VCP reply, [3] 0 = no error, [4] code,
        // [6…7] maximum, [8…9] current, [10] checksum.
        guard result == kIOReturnSuccess,
              reply[2] == 0x02, reply[3] == 0x00, reply[4] == code,
              reply[1..<10].reduce(Self.replyChecksumSeed, ^) == reply[10]
        else { throw DisplayError.ddcNoResponse }
        return (Int(reply[8]) << 8 | Int(reply[9]), Int(reply[6]) << 8 | Int(reply[7]))
    }
}

nonisolated extension Duration {
    var seconds: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
