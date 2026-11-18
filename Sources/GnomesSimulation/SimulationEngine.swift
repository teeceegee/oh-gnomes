import Foundation
import GnomesCore

public struct SimulationResult: Sendable, Equatable {
    public let raceId: String
    public let seed: UInt64
    public let totalTicks: Int
    public let finishOrder: [RunnerState] // Ordered by finishRank
    public let eventLog: [RaceEvent]
    public let resultChecksum: String
}

public final class SimulationEngine: @unchecked Sendable {
    public static let tickRateHz: Int = 30
    public static let timeStepSeconds: Double = 1.0 / Double(tickRateHz)
    public static let maxSimulationTicks: Int = 30 * 90 // 90 seconds timeout

    public let raceId: String
    public let masterSeed: UInt64
    public let course: Course
    public let gnomes: [Gnome]
    public private(set) var prng: DeterministicPRNGStreams
    public private(set) var limiter: IncidentLimiter

    public private(set) var currentTick: Int = 0
    public private(set) var runners: [RunnerState]
    public private(set) var eventLog: [RaceEvent]
    public private(set) var incidents: [IncidentRecord]
    private var eventSequence: Int = 0
    private var triggeredObstacles: Set<String> = []

    public var isComplete: Bool {
        return runners.allSatisfy { $0.isFinished } || currentTick >= Self.maxSimulationTicks
    }

    public init(raceId: String = UUID().uuidString, masterSeed: UInt64, course: Course, gnomes: [Gnome]) {
        precondition(gnomes.count == 8, "Simulation requires exactly 8 gnomes")
        self.raceId = raceId
        self.masterSeed = masterSeed
        self.course = course
        self.gnomes = gnomes
        self.prng = DeterministicPRNGStreams(masterSeed: masterSeed)
        self.limiter = IncidentLimiter()
        self.eventLog = []
        self.incidents = []

        // Initialize 8 runners across lanes 1..8
        self.runners = gnomes.enumerated().map { idx, gnome in
            RunnerState(
                gnomeId: gnome.id,
                gnomeName: gnome.name,
                lane: idx + 1
            )
        }
    }

    /// Emits an append-only event into the simulation log
    private func recordEvent(type: RaceEvent.RaceEventType, payload: String) {
        eventSequence += 1
        let checksumComponent = "\(raceId):\(eventSequence):\(currentTick):\(type.rawValue):\(payload)"
        let eventChecksum = String(format: "%016llx", Self.fnv1a64(checksumComponent))

        let event = RaceEvent(
            raceId: raceId,
            sequence: eventSequence,
            tick: currentTick,
            eventType: type,
            payloadJSON: payload,
            checksum: eventChecksum,
            idempotencyKey: "\(raceId)_\(eventSequence)"
        )
        eventLog.append(event)
    }

    /// Advances the simulation by exactly one 30Hz tick
    public func step() {
        guard !isComplete else { return }

        if currentTick == 0 {
            recordEvent(type: .raceStarted, payload: "{\"courseId\":\"\(course.id)\",\"entrants\":\(runners.count)}")
        }

        currentTick += 1
        let dt = Self.timeStepSeconds
        var currentFinishersCount = runners.filter { $0.isFinished }.count

        // Process each runner
        for i in 0..<runners.count {
            guard !runners[i].isFinished else { continue }
            let gnome = gnomes[i]
            let attrs = gnome.baselineAttributes

            // 1. Status recovery handling
            if runners[i].recoveryTimerTicks > 0 {
                runners[i].recoveryTimerTicks -= 1
                if runners[i].recoveryTimerTicks == 0 {
                    runners[i].statusEffect = .running
                    runners[i].balance = max(0.5, attrs.balance * 0.8)
                }
            }

            // 2. Incident state handling
            if runners[i].statusEffect == .stumbled {
                runners[i].velocityMps = max(0.0, runners[i].velocityMps - (15.0 * dt))
                runners[i].distanceMeters += runners[i].velocityMps * dt
                continue
            }

            // 3. Current surface parameters
            let currentDist = runners[i].distanceMeters
            let surface = course.surfaceZones.first { currentDist >= $0.startMeter && currentDist < $0.endMeter }
            let baseSurfaceMultiplier = surface?.speedMultiplier ?? 1.0
            let slipRisk = surface?.slipRiskPerTick ?? 0.001

            // Surface modifiers & trait affinities
            var effectiveSurfaceMultiplier = baseSurfaceMultiplier
            if surface?.surfaceType == .mud {
                if gnome.traits.contains(where: { $0.effectCategory == .mudAffinity }) {
                    effectiveSurfaceMultiplier = 0.95 // Mud Affinity trait ignores most mud drag
                }
            }

            // 4. Calculate target velocity
            // Base speed range: 5.5 m/s to 9.5 m/s based on speed attribute (0.0 to 1.0)
            var targetSpeed = (5.5 + (attrs.speed * 4.0)) * effectiveSurfaceMultiplier

            // Trait effects
            // Start Boost: extra 2.2 m/s during the first 3 seconds (90 ticks)
            if currentTick <= 90 && gnome.traits.contains(where: { $0.effectCategory == .startBoost }) {
                targetSpeed += 2.2
            }

            // Stamina Surge: final 20% stretch speed burst
            let distanceRatio = currentDist / course.totalDistanceMeters
            if distanceRatio >= 0.80 && gnome.traits.contains(where: { $0.effectCategory == .staminaSurge }) {
                runners[i].statusEffect = .sprinting
                targetSpeed += 2.5
            }

            // Stamina depletion penalty: tired gnomes run 25% slower
            if runners[i].stamina < 0.25 {
                targetSpeed *= 0.75
            }

            // Airborne launch burst
            if runners[i].statusEffect == .airborneLaunch {
                targetSpeed = 12.0
            }

            // Acceleration interpolation
            let accelRate = 4.0 + (attrs.acceleration * 6.0)
            if runners[i].velocityMps < targetSpeed {
                runners[i].velocityMps = min(targetSpeed, runners[i].velocityMps + (accelRate * dt))
            } else {
                runners[i].velocityMps = max(targetSpeed, runners[i].velocityMps - (accelRate * dt))
            }

            // 5. Check surface slip risk
            let slipChance = slipRisk * (1.3 - attrs.balance)
            if prng.incidentStream.rollProbability(slipChance) && limiter.canTriggerIncident(atTick: currentTick, cascadeDepth: 1) {
                triggerStumble(runnerIndex: i, reason: "slipped on \(surface?.surfaceType.rawValue ?? "track")")
                continue
            }

            // 6. Check obstacle zones
            for obs in course.obstacleZones {
                let obsKey = "\(obs.id)_\(runners[i].gnomeId)"
                if !triggeredObstacles.contains(obsKey) {
                    let distToObs = abs(runners[i].distanceMeters - obs.locationMeter)
                    if distToObs <= obs.triggerRadiusMeters {
                        triggeredObstacles.insert(obsKey)
                        if prng.incidentStream.rollProbability(obs.baseTriggerChance) && limiter.canTriggerIncident(atTick: currentTick, cascadeDepth: 1) {
                            handleObstacleCollision(runnerIndex: i, obstacle: obs)
                        }
                    }
                }
            }

            // 7. Update stamina & progress
            runners[i].stamina = max(0.05, runners[i].stamina - (0.00025 * (runners[i].velocityMps / 6.0)))
            runners[i].distanceMeters += runners[i].velocityMps * dt

            // 8. Finish line detection
            if runners[i].distanceMeters >= course.totalDistanceMeters {
                currentFinishersCount += 1
                runners[i].finishTick = currentTick
                runners[i].finishRank = currentFinishersCount
                runners[i].statusEffect = .finished
                runners[i].distanceMeters = course.totalDistanceMeters
                runners[i].velocityMps = 0.0

                recordEvent(
                    type: .runnerCrossedFinish,
                    payload: "{\"gnomeId\":\"\(runners[i].gnomeId)\",\"rank\":\(currentFinishersCount),\"tick\":\(currentTick)}"
                )
            }
        }

        // Periodic tick broadcast (every 15 ticks / 0.5 sec)
        if currentTick % 15 == 0 || isComplete {
            emitTickUpdate()
        }

        if isComplete {
            recordEvent(
                type: .raceCompleted,
                payload: "{\"totalTicks\":\(currentTick),\"winnerId\":\"\(runners.first(where: { $0.finishRank == 1 })?.gnomeId ?? "")\"}"
            )
        }
    }

    private func triggerStumble(runnerIndex: Int, reason: String) {
        let gnome = gnomes[runnerIndex]
        runners[runnerIndex].statusEffect = .stumbled
        runners[runnerIndex].totalIncidents += 1
        // Recovery duration: 20 to 45 ticks (0.6s - 1.5s) inversely proportional to recovery attribute
        let recoveryTicks = 45 - Int(gnome.baselineAttributes.recovery * 25.0)
        runners[runnerIndex].recoveryTimerTicks = max(15, recoveryTicks)

        let incident = IncidentRecord(
            tick: currentTick,
            runnerId: runners[runnerIndex].gnomeId,
            runnerName: runners[runnerIndex].gnomeName,
            incidentType: .stumble,
            description: reason,
            distanceMeter: runners[runnerIndex].distanceMeters
        )
        incidents.append(incident)

        recordEvent(
            type: .incidentOccurred,
            payload: "{\"gnomeId\":\"\(runners[runnerIndex].gnomeId)\",\"type\":\"stumble\",\"reason\":\"\(reason)\",\"recoveryTicks\":\(recoveryTicks)}"
        )
    }

    private func handleObstacleCollision(runnerIndex: Int, obstacle: ObstacleZone) {
        switch obstacle.obstacleType {
        case .springLauncher:
            // High spring launch forward
            runners[runnerIndex].statusEffect = .airborneLaunch
            runners[runnerIndex].recoveryTimerTicks = 35 // Airborne duration
            let incident = IncidentRecord(
                tick: currentTick,
                runnerId: runners[runnerIndex].gnomeId,
                runnerName: runners[runnerIndex].gnomeName,
                incidentType: .airborneLaunch,
                description: "hit a spring launcher and went airborne!",
                distanceMeter: runners[runnerIndex].distanceMeters
            )
            incidents.append(incident)
            recordEvent(type: .obstacleTriggered, payload: "{\"gnomeId\":\"\(runners[runnerIndex].gnomeId)\",\"obstacle\":\"springLauncher\"}")

        case .mudPuddle:
            runners[runnerIndex].statusEffect = .mudStuck
            runners[runnerIndex].velocityMps *= 0.4
            triggerStumble(runnerIndex: runnerIndex, reason: "splattered into a deep mud puddle")

        case .waterSprinkler, .movingSprinkler:
            runners[runnerIndex].balance = max(0.1, runners[runnerIndex].balance - 0.5)
            runners[runnerIndex].velocityMps *= 0.75
            let incident = IncidentRecord(
                tick: currentTick,
                runnerId: runners[runnerIndex].gnomeId,
                runnerName: runners[runnerIndex].gnomeName,
                incidentType: .sprinklerDaze,
                description: "got blasted sideways by an oscillating garden sprinkler!",
                distanceMeter: runners[runnerIndex].distanceMeters
            )
            incidents.append(incident)
            recordEvent(type: .obstacleTriggered, payload: "{\"gnomeId\":\"\(runners[runnerIndex].gnomeId)\",\"obstacle\":\"\(obstacle.obstacleType.rawValue)\"}")

        case .catapultTrap:
            runners[runnerIndex].statusEffect = .airborneLaunch
            runners[runnerIndex].recoveryTimerTicks = 42
            let incident = IncidentRecord(
                tick: currentTick,
                runnerId: runners[runnerIndex].gnomeId,
                runnerName: runners[runnerIndex].gnomeName,
                incidentType: .airborneLaunch,
                description: "stepped on a concealed trowel catapult and achieved low Earth orbit!",
                distanceMeter: runners[runnerIndex].distanceMeters
            )
            incidents.append(incident)
            recordEvent(type: .obstacleTriggered, payload: "{\"gnomeId\":\"\(runners[runnerIndex].gnomeId)\",\"obstacle\":\"catapultTrap\"}")

        case .snailDistraction:
            runners[runnerIndex].velocityMps *= 0.55
            let incident = IncidentRecord(
                tick: currentTick,
                runnerId: runners[runnerIndex].gnomeId,
                runnerName: runners[runnerIndex].gnomeName,
                incidentType: .snailDistraction,
                description: "stopped to politely negotiate right-of-way with a giant prize snail!",
                distanceMeter: runners[runnerIndex].distanceMeters
            )
            incidents.append(incident)
            recordEvent(type: .obstacleTriggered, payload: "{\"gnomeId\":\"\(runners[runnerIndex].gnomeId)\",\"obstacle\":\"snailDistraction\"}")

        case .flowerpotDomino:
            runners[runnerIndex].velocityMps *= 0.6
            let incident = IncidentRecord(
                tick: currentTick,
                runnerId: runners[runnerIndex].gnomeId,
                runnerName: runners[runnerIndex].gnomeName,
                incidentType: .gnomePileup,
                description: "knocked over a row of terracotta flowerpots in spectacular domino chaos!",
                distanceMeter: runners[runnerIndex].distanceMeters
            )
            incidents.append(incident)
            triggerStumble(runnerIndex: runnerIndex, reason: "tangled in shattered terracotta flowerpots")

        case .lowHedge:
            if gnomes[runnerIndex].baselineAttributes.balance > 0.72 {
                // Nimble gnomes dive through a hedge shortcut!
                runners[runnerIndex].velocityMps *= 1.25
                let incident = IncidentRecord(
                    tick: currentTick,
                    runnerId: runners[runnerIndex].gnomeId,
                    runnerName: runners[runnerIndex].gnomeName,
                    incidentType: .hedgeShortcut,
                    description: "dived straight through a privet hedge shortcut!",
                    distanceMeter: runners[runnerIndex].distanceMeters
                )
                incidents.append(incident)
            } else {
                triggerStumble(runnerIndex: runnerIndex, reason: "got wedged upside down in the privet hedge")
            }

        case .moleHill:
            triggerStumble(runnerIndex: runnerIndex, reason: "stepped into a fresh molehill excavation")
        }
    }

    private func emitTickUpdate() {
        let summary = runners.map { "{\"id\":\"\($0.gnomeId)\",\"dist\":\(String(format: "%.1f", $0.distanceMeters)),\"vel\":\(String(format: "%.1f", $0.velocityMps)),\"status\":\"\($0.statusEffect.rawValue)\"}" }.joined(separator: ",")
        recordEvent(type: .tickUpdate, payload: "{\"runners\":[\(summary)]}")
    }

    /// Executes the entire simulation loop to completion and returns the verified result
    @discardableResult
    public func runToCompletion() -> SimulationResult {
        while !isComplete {
            step()
        }

        // Sort runners by finish rank, then distance
        let sortedFinishers = runners.sorted {
            if let r1 = $0.finishRank, let r2 = $1.finishRank {
                return r1 < r2
            }
            if $0.finishRank != nil { return true }
            if $1.finishRank != nil { return false }
            return $0.distanceMeters > $1.distanceMeters
        }

        // Calculate cryptographic 64-bit checksum
        var digestString = "race:\(raceId):seed:\(masterSeed)"
        for r in sortedFinishers {
            digestString += "|\(r.gnomeId):\(r.finishRank ?? 99):\(r.finishTick ?? 9999):\(r.totalIncidents)"
        }
        let checksum = String(format: "%016llx", Self.fnv1a64(digestString))

        return SimulationResult(
            raceId: raceId,
            seed: masterSeed,
            totalTicks: currentTick,
            finishOrder: sortedFinishers,
            eventLog: eventLog,
            resultChecksum: checksum
        )
    }

    /// Pure 64-bit FNV-1a non-cryptographic checksum
    public static func fnv1a64(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF29CE484222325
        let prime: UInt64 = 0x100000001B3
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        return hash
    }
}
