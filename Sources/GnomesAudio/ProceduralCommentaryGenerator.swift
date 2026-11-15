import Foundation
import GnomesCore
import GnomesSimulation

public struct ProceduralCommentaryGenerator: Sendable {
    public let corpus: CommentaryCorpus?

    public init(corpus: CommentaryCorpus? = nil) {
        if let provided = corpus {
            self.corpus = provided
        } else {
            self.corpus = try? ContentLoader.loadCommentaryCorpus()
        }
    }

    public func commentaryForStart(courseName: String, entrantsCount: Int, seed: Int = 0) -> String {
        if let phrases = corpus?.openings, !phrases.isEmpty {
            let idx = abs(seed) % phrases.count
            return phrases[idx].replacingOccurrences(of: "{course}", with: courseName)
        }
        return "And they're off! \(entrantsCount) gnomes charge down the \(courseName)!"
    }

    public func commentaryForIncident(runnerName: String, incidentType: IncidentType, reason: String, seed: Int = 0) -> String {
        guard let corpus = corpus else {
            return fallbackIncidentCommentary(runnerName: runnerName, incidentType: incidentType)
        }

        let phrases: [String]
        switch incidentType {
        case .stumble:
            phrases = corpus.stumbles
        case .airborneLaunch:
            phrases = corpus.springLaunchers
        case .mudSplash:
            phrases = corpus.mudSplashes
        case .sprinklerDaze:
            phrases = corpus.sprinklers
        case .sprintSurge:
            return "Look at \(runnerName) fly! A late burst of speed down the final stretch!"
        case .gnomeCollision:
            phrases = corpus.collisions
        }

        if !phrases.isEmpty {
            let idx = abs(seed) % phrases.count
            return phrases[idx].replacingOccurrences(of: "{runner}", with: runnerName)
        }
        return fallbackIncidentCommentary(runnerName: runnerName, incidentType: incidentType)
    }

    public func commentaryForOvertake(leaderName: String, chaserName: String, seed: Int = 0) -> String {
        if let phrases = corpus?.overtakes, !phrases.isEmpty {
            let idx = abs(seed) % phrases.count
            return phrases[idx]
                .replacingOccurrences(of: "{leader}", with: leaderName)
                .replacingOccurrences(of: "{chaser}", with: chaserName)
        }
        return "\(leaderName) pulls ahead of \(chaserName) into the lead!"
    }

    public func commentaryForPhotoFinish(seed: Int = 0) -> String {
        if let phrases = corpus?.photoFinishes, !phrases.isEmpty {
            let idx = abs(seed) % phrases.count
            return phrases[idx]
        }
        return "It's neck and neck! We have a photo finish at the line!"
    }

    public func commentaryForWinner(winnerName: String, seed: Int = 0) -> String {
        if let phrases = corpus?.winnerCelebrations, !phrases.isEmpty {
            let idx = abs(seed) % phrases.count
            return phrases[idx].replacingOccurrences(of: "{winner}", with: winnerName)
        }
        return "\(winnerName) storms across the line to take the glory!"
    }

    private func fallbackIncidentCommentary(runnerName: String, incidentType: IncidentType) -> String {
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
}
