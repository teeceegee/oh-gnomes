import Foundation
import GnomesCore
import GnomesSimulation

public struct ProceduralCommentaryGenerator: Sendable {
    public init() {}

    public func commentaryForStart(courseName: String, entrantsCount: Int) -> String {
        return "And they're off! \(entrantsCount) gnomes charge down the \(courseName)!"
    }

    public func commentaryForIncident(runnerName: String, incidentType: IncidentType, reason: String) -> String {
        switch incidentType {
        case .stumble:
            return "Disaster for \(runnerName)! A terrible stumble on the course!"
        case .airborneLaunch:
            return "Good heavens! \(runnerName) hit a spring launcher and is soaring through the air!"
        case .mudSplash:
            return "\(runnerName) takes a face full of mud and gets completely bogged down!"
        case .sprinklerDaze:
            return "A sprinkler catches \(runnerName) cold! Water everywhere!"
        case .sprintSurge:
            return "Look at \(runnerName) fly! A late burst of speed down the final stretch!"
        case .gnomeCollision:
            return "Heavy contact! \(runnerName) bounces off a rival runner!"
        }
    }

    public func commentaryForOvertake(leaderName: String, chaserName: String) -> String {
        return "\(leaderName) pulls ahead of \(chaserName) into the lead!"
    }

    public func commentaryForPhotoFinish() -> String {
        return "It's neck and neck! We have a photo finish at the line!"
    }

    public func commentaryForWinner(winnerName: String) -> String {
        return "\(winnerName) storms across the line to take the glory!"
    }
}
