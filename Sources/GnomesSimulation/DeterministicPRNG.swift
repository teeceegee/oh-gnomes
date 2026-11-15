import Foundation

/// Pure deterministic 64-bit Pseudo-Random Number Generator implementing Xoshiro256**
/// Guarantees bit-exact reproduction across all platforms and runs.
public struct Xoshiro256StarStar: Sendable, Equatable {
    private var s0: UInt64
    private var s1: UInt64
    private var s2: UInt64
    private var s3: UInt64

    public init(seed: UInt64) {
        // Seed using SplitMix64
        var smState = seed
        func splitMix64() -> UInt64 {
            smState &+= 0x9E3779B97F4A7C15
            var z = smState
            z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
            return z ^ (z &>> 31)
        }

        self.s0 = splitMix64()
        self.s1 = splitMix64()
        self.s2 = splitMix64()
        self.s3 = splitMix64()

        // Handle edge case of all zeros
        if s0 == 0 && s1 == 0 && s2 == 0 && s3 == 0 {
            self.s0 = 0x9E3779B97F4A7C15
        }
    }

    private func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 {
        return (x &<< k) | (x &>> (64 - k))
    }

    /// Generates next pseudo-random UInt64
    public mutating func nextUInt64() -> UInt64 {
        let result = rotl(s1 &* 5, 7) &* 9
        let t = s1 &<< 17

        s2 ^= s0
        s3 ^= s1
        s1 ^= s2
        s0 ^= s3

        s2 ^= t
        s3 = rotl(s3, 45)

        return result
    }

    /// Generates a pseudo-random Double in the half-open interval [0.0, 1.0)
    public mutating func nextDouble() -> Double {
        // Use upper 53 bits for standard IEEE 754 double precision
        let bits = nextUInt64() &>> 11
        return Double(bits) / Double(1 &<< 53)
    }

    /// Generates an integer in the closed range [min, max]
    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        precondition(range.lowerBound <= range.upperBound)
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        let value = nextUInt64() % span
        return range.lowerBound + Int(value)
    }

    /// Returns true with probability `chance` (where 0.0 <= chance <= 1.0)
    public mutating func rollProbability(_ chance: Double) -> Bool {
        return nextDouble() < chance
    }
}

/// Container for isolated, named PRNG sub-streams so that visual or incidental rolls
/// never perturb the core physics or movement trajectories.
public struct DeterministicPRNGStreams: Sendable {
    public var physicsStream: Xoshiro256StarStar
    public var incidentStream: Xoshiro256StarStar
    public var decisionStream: Xoshiro256StarStar

    public init(masterSeed: UInt64) {
        // Derive unique seeds for each sub-stream using distinct constants
        let physicsSeed = masterSeed &+ 0x123456789ABCDEF0
        let incidentSeed = masterSeed &+ 0xFEDCBA9876543210
        let decisionSeed = masterSeed &+ 0x5555AAAA5555AAAA

        self.physicsStream = Xoshiro256StarStar(seed: physicsSeed)
        self.incidentStream = Xoshiro256StarStar(seed: incidentSeed)
        self.decisionStream = Xoshiro256StarStar(seed: decisionSeed)
    }
}
