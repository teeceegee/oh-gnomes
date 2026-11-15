import Foundation

public enum RacePhase: String, Codable, Sendable, CaseIterable, Comparable {
    case preparing
    case introduction
    case bettingOpen
    case bettingClosed
    case simulating
    case presentationFinished
    case settling
    case published
    case archived

    private var rank: Int {
        switch self {
        case .preparing: return 0
        case .introduction: return 1
        case .bettingOpen: return 2
        case .bettingClosed: return 3
        case .simulating: return 4
        case .presentationFinished: return 5
        case .settling: return 6
        case .published: return 7
        case .archived: return 8
        }
    }

    public static func < (lhs: RacePhase, rhs: RacePhase) -> Bool {
        return lhs.rank < rhs.rank
    }

    public func canTransition(to next: RacePhase) -> Bool {
        switch (self, next) {
        case (.preparing, .introduction): return true
        case (.introduction, .bettingOpen): return true
        case (.bettingOpen, .bettingClosed): return true
        case (.bettingClosed, .simulating): return true
        case (.simulating, .presentationFinished): return true
        case (.presentationFinished, .settling): return true
        case (.settling, .published): return true
        case (.published, .archived): return true
        default: return false
        }
    }
}
