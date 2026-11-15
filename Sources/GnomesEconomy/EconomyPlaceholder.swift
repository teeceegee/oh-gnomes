import Foundation
import GnomesCore

public struct EconomyEngineInfo: Sendable {
    public static let initialBalancePennies: Int = Player.initialStartingBalancePennies
    public static let minimumStakePennies: Int = Bet.minimumStakePennies
}
