# Oh! Gnomes — Agent Documentation & Workspace Guide

## 1. Project Overview
- **Project Name:** Oh! Gnomes
- **Genre & Style:** Social, televised race-night party game (Jackbox-style local/hybrid party game).
- **Format:** 2 to 20 players connect via mobile phone browsers (no app install), inspect character cards, and place one virtual-money bet per race (£500 starting balance).
- **Core Loop:** Lobby → Race Introduction → Betting Open (60s) → Betting Close (revealing Gnome Gems) → Authoritative Fixed-Tick Deterministic Simulation → Finish & Replay → Settlement → Standings (Open or Mystery Mode) → Finale.
- **Roster & Courses:** 48 persistent evolving gnomes (8 runners per race); 6 planned courses (3 initial, 1 prototype).
- **Key Modes:** 
  - **Open Mode:** Public standings and updates visible after each race.
  - **Mystery Mode:** Server-side projection policy that strictly hides standings, balances, ranks, and eliminations from phones and the host panel until the finale reveal.

---

## 2. Technical Details & Confirmed Architecture
- **Target Platform & Host:** **Argolis (Apple Silicon M4)** with AirPlay screen mirroring to the living room TV.
- **Architecture Pattern:** Native macOS Host & Broadcast Application (Swift 6 / Metal / SpriteKit) with an embedded HTTP/WebSocket server hosting zero-install web controllers for guest phones over LAN Wi-Fi.
- **Client Interfaces:**
  - **Big-Screen Broadcast (Native macOS):** 1080p/4K 60fps Metal/SpriteKit presentation, custom particle shaders (mud, dust, water), dynamic camera director, floating Gnome Gems, and photo-finish freeze-frame replays.
  - **Neural Audio Commentary:** Native Apple `AVSpeechSynthesizer` (neural Siri voices) and `AVAudioEngine` delivering zero-latency procedural TV commentary and stinger sound effects.
  - **Phone Controllers (Web PWA):** Responsive mobile web app (Vite + React + Tailwind CSS) served by the embedded server on `:8778`; character cards, odds preview, stake slider, and immutable bet receipts.
  - **Host Interface:** Integrated into the macOS host app (with optional web admin route).
- **Determinism & Replay Engine:**
  - Fixed-tick (30Hz) physics engine written in pure Swift with seedable PRNG sub-streams (`Xoshiro256` / `Mulberry32`).
  - Identical inputs + seed = identical event stream and result checksum.
- **Economy & Persistence:**
  - Strict integer-penny banking (`balancePennies`, `stakePennies`, `payoutPennies`).
  - **Stake + Profit** winning returns convention (ADR-001 confirmed).
  - Installation-local **SQLite database** (via `GRDB.swift`) on Argolis persisting the 48-gnome evolving career roster and append-only event store (ADR-002 confirmed).
- **Target Repository Structure:**
  - `Package.swift`: Swift Package Manager manifest.
  - `Sources/OhGnomesApp`: SwiftUI host application entry point.
  - `Sources/GnomesCore`: Pure domain models and state machines.
  - `Sources/GnomesSimulation`: 30Hz deterministic physics engine, PRNG, and incident system.
  - `Sources/GnomesEconomy`: Bookmaker odds quotes, Stake+Profit payouts, and form decay.
  - `Sources/GnomesPersistence`: SQLite event log, checkpoints, and 48-gnome roster storage.
  - `Sources/GnomesPresentation`: Metal / SpriteKit scene rendering, particle shaders, and camera director.
  - `Sources/GnomesAudio`: `AVSpeechSynthesizer` procedural commentary and spatial audio.
  - `Sources/GnomesServer`: Embedded HTTP / WebSocket server (`FlyingFox`).
  - `WebController/`: Mobile phone web client (Vite + React) embedded into the macOS bundle.
  - `Content/`: 48 gnome character profiles, 3 course route graphs, and audio assets.

---

## 3. Confluence & Jira Cross-References
- **Atlassian Site:** `https://echopost.atlassian.net`
- **Confluence Space:** `TCG`
- **Jira Project:** `EVD` (Entertainment, Workstations & General Dev)
- **Active Epic & Work Breakdown:**
  - [EVD-262](https://echopost.atlassian.net/browse/EVD-262): **[Oh! Gnomes] Native Swift & Metal Race-Night Platform** (Epic)
    - [EVD-261](https://echopost.atlassian.net/browse/EVD-261): *Architect & Plan Implementation for Oh! Gnomes Platform* (Task, `In Progress`)
    - [EVD-265](https://echopost.atlassian.net/browse/EVD-265): *M0: Swift Package Scaffolding, Core Domain Models & Wire Contracts* (Story, `Done`)
      - [EVD-266](https://echopost.atlassian.net/browse/EVD-266): *Initialize Swift 6 Package with modular library targets* (Subtask, `Done`)
      - [EVD-267](https://echopost.atlassian.net/browse/EVD-267): *Model core domain entities and state machines in GnomesCore* (Subtask, `Done`)
      - [EVD-268](https://echopost.atlassian.net/browse/EVD-268): *Define JSON schema wire contracts for WebSocket client communication* (Subtask, `Done`)
    - [EVD-269](https://echopost.atlassian.net/browse/EVD-269): *M1: Deterministic Swift Simulation Engine Prototype* (Story, `Done`)
      - [EVD-270](https://echopost.atlassian.net/browse/EVD-270): *Implement deterministic PRNG with named sub-streams in GnomesSimulation* (Subtask, `Done`)
      - [EVD-271](https://echopost.atlassian.net/browse/EVD-271): *Build 30Hz fixed-tick physics loop, route waypoints, and surface friction models* (Subtask, `Done`)
      - [EVD-272](https://echopost.atlassian.net/browse/EVD-272): *Implement cartoon incident model (stumbles, launches, surges) with chain-reaction limiters* (Subtask, `Done`)
      - [EVD-273](https://echopost.atlassian.net/browse/EVD-273): *Create automated 1,000-run replay determinism test suite* (Subtask, `Done`)
    - [EVD-274](https://echopost.atlassian.net/browse/EVD-274): *M2: Integer-Penny Economy, Bookmaker Odds & SQLite Career Persistence* (Story, `Done`)
      - [EVD-275](https://echopost.atlassian.net/browse/EVD-275): *Implement integer-penny banking ledger and Stake+Profit payout calculator* (Subtask, `Done`)
      - [EVD-276](https://echopost.atlassian.net/browse/EVD-276): *Build explainable bookmaker odds quote engine with trait and weather weighting* (Subtask, `Done`)
      - [EVD-277](https://echopost.atlassian.net/browse/EVD-277): *Develop idempotent settlement engine and bounded post-race form decay* (Subtask, `Done`)
      - [EVD-278](https://echopost.atlassian.net/browse/EVD-278): *Setup SQLite schema and GRDB repository for 48-gnome persistent records* (Subtask, `Done`)
    - [EVD-279](https://echopost.atlassian.net/browse/EVD-279): *M3: Embedded WebSocket Gateway & Realtime Session Lifecycle* (Story, `To Do`)
    - [EVD-279](https://echopost.atlassian.net/browse/EVD-279): *M3: Embedded WebSocket Gateway & Realtime Session Lifecycle* (Story, `To Do`)
    - [EVD-283](https://echopost.atlassian.net/browse/EVD-283): *M4: Mobile Phone Web Controller (PWA)* (Story, `To Do`)
    - [EVD-287](https://echopost.atlassian.net/browse/EVD-287): *M5: Metal Broadcast Presentation & Neural Voice Commentary* (Story, `To Do`)
    - [EVD-292](https://echopost.atlassian.net/browse/EVD-292): *M6: Content Authoring (48 Gnomes, 3 Courses & Commentary Cues)* (Story, `To Do`)
    - [EVD-296](https://echopost.atlassian.net/browse/EVD-296): *M7: Hardening, AirPlay Verification & Social Playtest RC* (Story, `To Do`)

---

## 4. Activity & Discovery Log
- **2026-11-15:** Read and digested `input/oh-gnomes-game-design-and-technical-architecture.md`. Initialized `AGENT_README.md` and `JIRA_TICKETS.md`.
- **2026-11-15:** Created Jira planning task `EVD-261` and transitioned to `In Progress`.
- **2026-11-15:** User confirmed key decisions: (1) Stake + Profit payout convention, (2) Local SQLite persistence for 48-gnome career tracking, and (3) Native Swift 6 + Metal / SpriteKit architecture on **Argolis (Apple Silicon M4)** with AirPlay screen mirroring and embedded WebSocket server for zero-install mobile phone web controllers. Updated implementation plan to Version 2.0.0.
- **2026-11-15:** Established complete Jira hierarchy under Epic [EVD-262](https://echopost.atlassian.net/browse/EVD-262), generating 8 Milestone Stories (`EVD-265` to `EVD-296`) and 27 actionable Subtasks (`EVD-266` to `EVD-299`). Synchronized registries across workspace `JIRA_TICKETS.md` and master `jira_tickets_map.md`.
- **2026-11-15:** Completed **Milestone 0 (M0)**: Implemented modular Swift 6 `Package.swift`, authored all domain models in `GnomesCore`, implemented JSON schema wire contracts and Mystery Mode server projection filters in `GnomesContracts`, and executed `swift test` with 7 automated unit tests passing in 0.001s. Closed `EVD-265`, `EVD-266`, `EVD-267`, and `EVD-268` in Jira.
- **2026-11-15:** Completed **Milestone 1 (M1)**: Implemented `Xoshiro256StarStar` deterministic PRNG with named sub-streams, 30Hz fixed-tick physics simulation engine (`SimulationEngine`), surface friction and obstacle models, and `IncidentLimiter` cascade controls. Passed all 11 test suites including the 1,000-run bit-exact replay determinism verification test in 17.09s. Closed `EVD-269`, `EVD-270`, `EVD-271`, `EVD-272`, and `EVD-273` in Jira.
- **2026-11-15:** Completed **Milestone 2 (M2)**: Implemented `BankingLedger` actor with integer pennies, `BookmakerService` fractional ladder quotes, `SettlementService` Stake+Profit settlement with strict idempotency and dead-heat tie rules, `FormEvolutionService` with bounded decay and clamping, and native Darwin `SQLiteDatabase` with `GnomeRepository` (WAL mode enabled). Passed all 18 automated tests in 16.69s. Closed `EVD-274`, `EVD-275`, `EVD-276`, `EVD-277`, and `EVD-278` in Jira.
