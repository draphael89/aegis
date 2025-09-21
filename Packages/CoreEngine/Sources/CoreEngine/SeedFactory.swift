import Foundation

public enum SeedFactory {
    /// Generates a new run seed using a deterministic mixer over random entropy.
    public static func makeRunSeed(random: () -> UInt64 = { UInt64.random(in: UInt64.min...UInt64.max) }) -> UInt64 {
        mix(random())
    }

    /// Derives a deterministic encounter seed from the run seed, floor index, and node identifier.
    public static func encounterSeed(runSeed: UInt64, floor: Int, nodeID: UUID, salt: UInt64 = 0) -> UInt64 {
        var state = mix(runSeed &+ salt)
        state = mix(state &+ UInt64(bitPattern: Int64(floor)))

        var high: UInt64 = 0
        var low: UInt64 = 0
        withUnsafeBytes(of: nodeID.uuid) { buffer in
            for i in 0..<8 {
                high = (high << 8) | UInt64(buffer[i])
            }
            for i in 8..<16 {
                low = (low << 8) | UInt64(buffer[i])
            }
        }
        state = mix(state ^ high)
        state = mix(state ^ low)
        return state
    }

    /// SplitMix64-style mixer used to decorrelate seeds deterministically.
    static func mix(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
