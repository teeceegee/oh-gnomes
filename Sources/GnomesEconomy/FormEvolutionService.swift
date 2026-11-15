import Foundation
import GnomesCore

public struct FormEvolutionService: Sendable {
    public init() {}

    /// Updates gnome career records and computes bounded form rating after an official race
    public func evolveForm(
        currentCareer: CareerRecord,
        finishRank: Int,
        incidentsCount: Int
    ) -> CareerRecord {
        var updated = currentCareer
        updated.racesRun += 1
        if finishRank == 1 {
            updated.wins += 1
        }
        if finishRank <= 3 {
            updated.podiums += 1
        }
        updated.incidentsEncountered += incidentsCount

        // 1. Base rank performance delta
        let rankDelta: Double
        switch finishRank {
        case 1: rankDelta = 0.25
        case 2: rankDelta = 0.15
        case 3: rankDelta = 0.08
        case 4...5: rankDelta = 0.00
        case 6...7: rankDelta = -0.10
        default: rankDelta = -0.20
        }

        // 2. Incident penalty (-0.05 per incident)
        let incidentPenalty = Double(incidentsCount) * -0.05

        // 3. 15% decay toward baseline (0.0) plus net delta
        let decayedForm = updated.formRating * 0.85
        let rawNewForm = decayedForm + rankDelta + incidentPenalty

        // 4. Strict hard clamp between -1.0 and +1.0
        updated.formRating = max(-1.0, min(1.0, rawNewForm))

        return updated
    }
}
