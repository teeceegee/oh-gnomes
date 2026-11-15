import Testing
import Foundation
@testable import GnomesCore
@testable import GnomesPersistence

@Suite("GnomesPersistence Tests")
struct GnomesPersistenceTests {

    @Test("SQLite In-Memory Initialization & Table Creation")
    func testSQLiteInitialization() throws {
        let db = try SQLiteDatabase(path: ":memory:")
        #expect(db.getRawPointer() != nil)
    }

    @Test("Gnome Repository Upsert, Query & Career Persistence")
    func testGnomeRepositoryOperations() throws {
        let db = try SQLiteDatabase(path: ":memory:")
        let repo = GnomeRepository(database: db)

        let gnome = Gnome(
            id: "gnome_persist_1",
            name: "Cedric Thunderbeard",
            archetype: "Sprinter",
            portraitAsset: "cedric.png",
            biography: "Fastest gnome in the county.",
            traits: [GnomeTrait(id: "t_boost", displayName: "Start Boost", description: "Blasts off", effectCategory: .startBoost)],
            baselineAttributes: GnomeAttributes(speed: 0.85, acceleration: 0.80, stamina: 0.70, balance: 0.75, recovery: 0.80),
            career: CareerRecord(racesRun: 12, wins: 4, podiums: 8, incidentsEncountered: 3, formRating: 0.42)
        )

        // 1. Upsert
        try repo.upsertGnome(gnome)

        // 2. Query
        let loaded = try repo.loadGnome(id: "gnome_persist_1")
        #expect(loaded != nil)
        #expect(loaded?.name == "Cedric Thunderbeard")
        #expect(loaded?.traits.count == 1)
        #expect(loaded?.traits.first?.id == "t_boost")
        #expect(loaded?.career.racesRun == 12)
        #expect(loaded?.career.wins == 4)
        #expect(abs((loaded?.career.formRating ?? 0.0) - 0.42) < 0.001)

        // 3. Update career
        let updatedCareer = CareerRecord(racesRun: 13, wins: 5, podiums: 9, incidentsEncountered: 3, formRating: 0.60)
        try repo.updateGnomeCareer(gnomeId: "gnome_persist_1", career: updatedCareer)

        let reloaded = try repo.loadGnome(id: "gnome_persist_1")
        #expect(reloaded?.career.racesRun == 13)
        #expect(reloaded?.career.wins == 5)
        #expect(abs((reloaded?.career.formRating ?? 0.0) - 0.60) < 0.001)

        // 4. Load all
        let allGnomes = try repo.loadAllGnomes()
        #expect(allGnomes.count == 1)
        #expect(allGnomes.first?.id == "gnome_persist_1")
    }

    @Test("Settlement Record Persistence")
    func testSettlementPersistence() throws {
        let db = try SQLiteDatabase(path: ":memory:")
        let repo = GnomeRepository(database: db)

        let settlement = Settlement(
            id: "settle_test_1",
            raceId: "race_test_10",
            playerId: "player_alice",
            betId: "bet_test_99",
            result: .win,
            payoutPennies: 8_000,
            balanceBeforePennies: 48_000,
            balanceAfterPennies: 56_000
        )

        try repo.saveSettlement(settlement)
    }
}
