import Foundation
import SQLite3
import GnomesCore

public final class GnomeRepository: @unchecked Sendable {
    private let db: SQLiteDatabase

    public init(database: SQLiteDatabase) {
        self.db = database
    }

    public func upsertGnome(_ gnome: Gnome) throws {
        try db.withLock {
            let sql = """
            INSERT INTO gnomes (id, name, archetype, portrait_asset, biography, traits_json, speed, acceleration, stamina, balance, recovery)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                archetype = excluded.archetype,
                portrait_asset = excluded.portrait_asset,
                biography = excluded.biography,
                traits_json = excluded.traits_json,
                speed = excluded.speed,
                acceleration = excluded.acceleration,
                stamina = excluded.stamina,
                balance = excluded.balance,
                recovery = excluded.recovery;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db.getRawPointer(), sql, -1, &stmt, nil) != SQLITE_OK {
                throw DatabaseError.prepareFailed("Failed to prepare gnome upsert")
            }
            defer { sqlite3_finalize(stmt) }

            let encoder = JSONEncoder()
            let traitsData = try encoder.encode(gnome.traits)
            let traitsJSON = String(decoding: traitsData, as: UTF8.self)

            sqlite3_bind_text(stmt, 1, (gnome.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (gnome.name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (gnome.archetype as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (gnome.portraitAsset as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 5, (gnome.biography as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 6, (traitsJSON as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 7, gnome.baselineAttributes.speed)
            sqlite3_bind_double(stmt, 8, gnome.baselineAttributes.acceleration)
            sqlite3_bind_double(stmt, 9, gnome.baselineAttributes.stamina)
            sqlite3_bind_double(stmt, 10, gnome.baselineAttributes.balance)
            sqlite3_bind_double(stmt, 11, gnome.baselineAttributes.recovery)

            if sqlite3_step(stmt) != SQLITE_DONE {
                throw DatabaseError.stepFailed("Failed to step gnome upsert")
            }

            try updateGnomeCareer(gnomeId: gnome.id, career: gnome.career)
        }
    }

    public func updateGnomeCareer(gnomeId: String, career: CareerRecord) throws {
        let sql = """
        INSERT INTO career_records (gnome_id, races_run, wins, podiums, incidents_encountered, form_rating)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(gnome_id) DO UPDATE SET
            races_run = excluded.races_run,
            wins = excluded.wins,
            podiums = excluded.podiums,
            incidents_encountered = excluded.incidents_encountered,
            form_rating = excluded.form_rating;
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db.getRawPointer(), sql, -1, &stmt, nil) != SQLITE_OK {
            throw DatabaseError.prepareFailed("Failed to prepare career upsert")
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (gnomeId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(career.racesRun))
        sqlite3_bind_int(stmt, 3, Int32(career.wins))
        sqlite3_bind_int(stmt, 4, Int32(career.podiums))
        sqlite3_bind_int(stmt, 5, Int32(career.incidentsEncountered))
        sqlite3_bind_double(stmt, 6, career.formRating)

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw DatabaseError.stepFailed("Failed to step career upsert")
        }
    }

    public func loadGnome(id: String) throws -> Gnome? {
        return try db.withLock {
            let sql = """
            SELECT g.id, g.name, g.archetype, g.portrait_asset, g.biography, g.traits_json,
                   g.speed, g.acceleration, g.stamina, g.balance, g.recovery,
                   c.races_run, c.wins, c.podiums, c.incidents_encountered, c.form_rating
            FROM gnomes g
            LEFT JOIN career_records c ON g.id = c.gnome_id
            WHERE g.id = ?;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db.getRawPointer(), sql, -1, &stmt, nil) != SQLITE_OK {
                throw DatabaseError.prepareFailed("Failed to prepare gnome select")
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)

            if sqlite3_step(stmt) == SQLITE_ROW {
                return parseGnomeRow(stmt: stmt!)
            }
            return nil
        }
    }

    public func loadAllGnomes() throws -> [Gnome] {
        return try db.withLock {
            let sql = """
            SELECT g.id, g.name, g.archetype, g.portrait_asset, g.biography, g.traits_json,
                   g.speed, g.acceleration, g.stamina, g.balance, g.recovery,
                   c.races_run, c.wins, c.podiums, c.incidents_encountered, c.form_rating
            FROM gnomes g
            LEFT JOIN career_records c ON g.id = c.gnome_id
            ORDER BY g.name ASC;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db.getRawPointer(), sql, -1, &stmt, nil) != SQLITE_OK {
                throw DatabaseError.prepareFailed("Failed to prepare all gnomes select")
            }
            defer { sqlite3_finalize(stmt) }

            var gnomes: [Gnome] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let g = parseGnomeRow(stmt: stmt!) {
                    gnomes.append(g)
                }
            }
            return gnomes
        }
    }

    private func parseGnomeRow(stmt: OpaquePointer) -> Gnome? {
        guard let idC = sqlite3_column_text(stmt, 0),
              let nameC = sqlite3_column_text(stmt, 1),
              let archC = sqlite3_column_text(stmt, 2),
              let portC = sqlite3_column_text(stmt, 3),
              let bioC = sqlite3_column_text(stmt, 4),
              let traitsC = sqlite3_column_text(stmt, 5) else {
            return nil
        }

        let id = String(cString: idC)
        let name = String(cString: nameC)
        let arch = String(cString: archC)
        let port = String(cString: portC)
        let bio = String(cString: bioC)
        let traitsJSON = String(cString: traitsC)

        let speed = sqlite3_column_double(stmt, 6)
        let accel = sqlite3_column_double(stmt, 7)
        let stamina = sqlite3_column_double(stmt, 8)
        let balance = sqlite3_column_double(stmt, 9)
        let recovery = sqlite3_column_double(stmt, 10)

        let racesRun = Int(sqlite3_column_int(stmt, 11))
        let wins = Int(sqlite3_column_int(stmt, 12))
        let podiums = Int(sqlite3_column_int(stmt, 13))
        let incidents = Int(sqlite3_column_int(stmt, 14))
        let form = sqlite3_column_double(stmt, 15)

        let decoder = JSONDecoder()
        let traits = (try? decoder.decode([GnomeTrait].self, from: Data(traitsJSON.utf8))) ?? []

        return Gnome(
            id: id,
            name: name,
            archetype: arch,
            portraitAsset: port,
            biography: bio,
            traits: traits,
            baselineAttributes: GnomeAttributes(
                speed: speed,
                acceleration: accel,
                stamina: stamina,
                balance: balance,
                recovery: recovery
            ),
            career: CareerRecord(
                racesRun: racesRun,
                wins: wins,
                podiums: podiums,
                incidentsEncountered: incidents,
                formRating: form
            )
        )
    }

    public func saveSettlement(_ s: Settlement) throws {
        try db.withLock {
            let sql = """
            INSERT INTO settlements (id, race_id, player_id, bet_id, result, payout_pennies, balance_before, balance_after, settled_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db.getRawPointer(), sql, -1, &stmt, nil) != SQLITE_OK {
                throw DatabaseError.prepareFailed("Failed to prepare settlement insert")
            }
            defer { sqlite3_finalize(stmt) }

            let isoDate = ISO8601DateFormatter().string(from: s.settledAt)
            sqlite3_bind_text(stmt, 1, (s.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (s.raceId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (s.playerId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (s.betId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 5, (s.result.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 6, Int32(s.payoutPennies))
            sqlite3_bind_int(stmt, 7, Int32(s.balanceBeforePennies))
            sqlite3_bind_int(stmt, 8, Int32(s.balanceAfterPennies))
            sqlite3_bind_text(stmt, 9, (isoDate as NSString).utf8String, -1, nil)

            if sqlite3_step(stmt) != SQLITE_DONE {
                throw DatabaseError.stepFailed("Failed to step settlement insert")
            }
        }
    }
}
