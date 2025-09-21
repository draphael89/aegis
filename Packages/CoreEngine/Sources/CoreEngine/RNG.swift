import Foundation

public struct RNG {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed &* 0x9E37_79B9_7F4A_7C15
    }

    @inline(__always)
    mutating func next32() -> UInt32 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z ^= z >> 30
        z &*= 0xBF58_476D_1CE4_E5B9
        z ^= z >> 27
        z &*= 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return UInt32(truncatingIfNeeded: z)
    }

    @inline(__always)
    mutating func next(_ upperExclusive: Int) -> Int {
        precondition(upperExclusive > 0, "Upper bound must be positive")
        return Int(next32() % UInt32(upperExclusive))
    }

    mutating func chance(percent: Int) -> Bool {
        precondition((0...100).contains(percent), "Percent must be 0...100")
        if percent == 0 { return false }
        if percent == 100 { return true }
        return next(100) < percent
    }

    mutating func shuffled<T>(_ values: [T]) -> [T] {
        var copy = values
        guard copy.count > 1 else { return copy }
        for i in stride(from: copy.count - 1, through: 1, by: -1) {
            let j = next(i + 1)
            if i != j {
                copy.swapAt(i, j)
            }
        }
        return copy
    }
}
