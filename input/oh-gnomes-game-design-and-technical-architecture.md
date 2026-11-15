# Oh! Gnomes

## Game Design Document and Technical Architecture

Consolidated review draft • Version 1.0 consolidation • 14 November 2026

Purpose: provide a single, editable specification for design review before coding begins. The document separates confirmed design decisions from recommendations, assumptions, open questions and deferred features.


| Document field | Value |
| --- | --- |
| Status | Review draft; not an implementation commitment |
| Audience | Game designer, technical lead, coding agent, host and playtest reviewers |
| Scope | Core race-night loop, simulation, betting, multiplayer, presentation, persistence and delivery plan |
| Provenance | OpenAI ChatGPT (GPT-6); created/revised 14 November 2026 |
| Originating conversation | Game Structure Planning; conversation ID 6af89630-6e28-83ed-9915-df99957a8357; direct URL not available in the source |

Review request: approve or amend the marked open issues and recommendations before implementation is authorised.


## 1 Executive summary

Oh! Gnomes is a social, televised race-night game. Two to twenty people join from phones, inspect character cards, place one virtual-money bet per race, and watch a shared big-screen race presentation. Eight persistent gnomes compete in each race drawn from a roster of 48. The simulation is deterministic and replayable, while the presentation layers cartoon physics, incidents, commentary, cameras and Gnome Gems over the authoritative result.

The first playable release should prioritise a trustworthy simulation and complete race-night loop over visual breadth: one prototype course, three initial courses planned, six courses in the extensible catalogue, persistent race history, private player balances, two championship modes and recoverable session state. Full 3D production quality, voice commentary and additional courses can follow once the core is proven.


## 2 Decision register

Labels used throughout: Approved means explicitly established in the referenced planning conversation or in the user brief. Recommendation means a concrete proposal to review. Assumption is used only where a technical shape is needed to make the specification implementable. Open issue requires a product decision. Deferred is deliberately outside the first playable release.


| ID | Decision | Status | Notes |
| --- | --- | --- | --- |
| D-01 | Race-night capacity is 2–20 phone players. | Approved | Gnome Gems and session services must support all 20. |
| D-02 | Each race offers one bet per player; minimum £1; initial balance £500; zero balance is eliminated. | Approved | The exact winning-return convention remains an open issue unless confirmed during review. |
| D-03 | There are 48 persistent, evolving gnome characters. | Approved | Eight runners are selected for each race. |
| D-04 | There are two championship modes: Open and Mystery. | Approved | Mystery hides championship standings and balances, including from the host panel. |
| D-05 | Gnome Gems identify bettors and float over their selected runners after betting closes. | Approved | Use colour plus distinct shape/symbol; gems do not affect outcomes. |
| D-06 | Every character card includes portrait, comedy biography, traits, history and a prominent Bet button. | Approved | Bet button opens stake selection with the gnome preselected. |
| D-07 | Six courses are planned; three are initial content; one is the prototype. | Approved | Course names and final content specification are still open. |
| D-08 | Race outcomes are deterministic, seedable and recoverable. | Approved | The same committed inputs must reproduce the same result. |
| D-09 | A shared big screen, player phones and a separate host control panel are the primary interfaces. | Approved | Phone interface is browser-based; no installation required. |
| D-10 | Players may reconnect without receiving a second starting balance. | Approved | Registration closes when the first race begins is a recommendation from the source. |
| D-11 | Exact odds, payout formula, tie handling and long-term persistence scope. | Open | Do not implement silently; see Section 15. |


## 3 Game vision and design pillars

- A miniature televised sporting event: introductions, odds, live positions, incidents, replays and a theatrical finale.

- Comedy from simulation and presentation, never from hidden manipulation of a player’s bet or a race result.

- Personal investment without financial stakes: each player can instantly identify their runner through a distinctive Gnome Gem.

- Trust through deterministic results, locked phases, auditable event logs and interruption recovery.

- Readable at a distance and on a phone, with shape/symbol redundancy, subtitles and privacy-aware displays.


## 4 Core race-night loop


| Phase | Default behaviour | Authoritative outputs |
| --- | --- | --- |
| Lobby | Display QR code and short session code; players join, choose display name and receive a unique gem identity. | Session, players, gem assignments, £500 starting balance |
| Race introduction | Announce course, weather and entrants; show portraits, odds and selected history moments. | Entrant list and presentation cues |
| Betting open | Default 60 seconds; player browses cards and places one stake of at least £1 up to balance. | Accepted bet or explicit no-bet; immutable bet receipt |
| Betting close | Lock bets and odds; reveal Gnome Gems above backed runners. | Betting-closed event; gem mapping |
| Race | Run deterministic simulation; present physics, incidents, camera changes, commentary and live order. | Race result and event stream |
| Finish and replay | Celebrate winner; optionally replay a notable incident or photo finish. | Presentation completion marker |
| Settlement | Calculate winnings/losses; update balance and form only after official completion. | Settlement, new balance, updated history |
| Standings / next race | Open updates standings; Mystery keeps them hidden. Host pauses or advances. | Published view model; next-race readiness |
| Finale | Reveal championship outcome; recognise ties if confirmed. | Final standings and championship completion |


## 5 Rules and economy


### 5.1 Betting rules

- Each eligible player may place at most one bet for each race.

- The minimum stake is £1. The maximum stake is the player’s available balance.

- A player with a zero balance is eliminated from future betting and championship competition; the exact display and whether they remain a spectator require no new money and are recommended to remain visible.

- Betting is accepted only in the BettingOpen phase. Closing is atomic: no bet arriving after the close event may be accepted.

- Odds shown at bet time are locked into the bet receipt. The bookmaker may expose only the published odds and the potential return allowed by the final payout rule.


### 5.2 Payout and odds

The bookmaker should produce imperfect but explainable odds from runner capability, traits, course fit, weather and bounded recent form. It should allow occasional outsiders without making them common enough to feel scripted. Odds are a player-facing estimate, not a promise of fairness or a second randomiser.

Recommendation: represent odds as a versioned quote with numerator, denominator, display string and implied probability. Keep the payout calculator pure and testable. Do not round money through floating-point arithmetic; use integer pennies internally and display whole pounds unless a later decision requires pence.

Open issue: confirm whether a winning bet returns stake plus profit, profit only, or another convention. This specification intentionally does not choose one.


## 6 Gnome universe and character cards

The roster contains 48 persistent gnome identities. Each gnome has a stable ID, portrait asset, name, comedic biography, traits, base attributes, career state, bounded form history and race results. Eight gnomes are entered per race; selection should provide course variety without making player choice meaningless.


| Card element | Required behaviour |
| --- | --- |
| Identity | Name, portrait, stable ID and short role/archetype. |
| Biography | Comedic, non-authoritative flavour text that does not promise outcomes. |
| Traits | Readable tags such as Fast Starter, Poor Balance or Mud Magnet; each maps to documented simulation effects. |
| Odds | Current published quote, timestamp/version and potential return preview. |
| Race history | Recent finishes, incidents, course/weather context and bounded form indicator. |
| Bet button | Prominent “Bet on [Name]”; enabled only when betting is open and the player is eligible. |
| Accessibility | Text labels and iconography supplement colour; portrait and data remain usable without animation. |

Form/performance evolution must be bounded. A recommended model is a slow-moving latent form value updated from recent results and incidents with decay toward the gnome’s baseline, plus a hard clamp on the effect size. Form updates occur only after official race completion and are included in the next race’s seed inputs.


## 7 Courses and race simulation

The course system is data-driven. Six courses are planned, three are initial content, and one is the prototype used to validate the simulation and presentation pipeline. Each course defines a route graph, surfaces, obstacles, hazard zones, weather affordances, camera markers, finish geometry and physics tuning parameters.


| Course asset | Purpose | Prototype requirement |
| --- | --- | --- |
| Route graph | Waypoints, lanes, shortcuts and finish line. | One loop or point-to-point route with deterministic progress. |
| Surface profile | Mud, grass, stone, water or other friction / slip effects. | At least two surfaces. |
| Obstacle set | Springs, ramps, puddles, barriers and recovery zones. | At least three obstacle types. |
| Weather profile | Wind, rain or other modifiers. | One weather state plus seeded variation. |
| Presentation anchors | Start, incident, close-up and finish camera regions. | Enough anchors for a complete race broadcast. |


### 7.1 Simulation model

The simulation advances in fixed ticks. Each tick resolves intent, movement, collision/constraint checks, incidents and event emission. Physics should be cartoon-like rather than physically exact: readable exaggeration is preferred, but every state transition is deterministic under the same seed and input snapshot.

- Runner state: position, velocity, progress, stamina/effort, balance, current surface, status effects and recovery timer.

- Modifiers: base attributes, traits, course fit, weather, bounded form and current incident state.

- Incidents: stumble, collision, mud splash, airborne launch, recovery, shortcut, blocked path and finish surge; each has preconditions and a bounded effect.

- Chain reactions: explicitly limited by depth, duration and per-tick budget to avoid runaway cascades.

- No presentation element, camera choice, gem, commentary line or replay may alter authoritative runner state.


## 8 Determinism, seed and event log

The server creates a race seed only after the entrant list, course, weather, ruleset version and locked bets are committed. The seed is not exposed to players before betting closes. All random choices use a named deterministic PRNG stream or derived sub-seed so that adding a cosmetic effect cannot change the race outcome.


| Input / record | Contents |
| --- | --- |
| Session seed | Server-generated identifier for the race night; not sufficient alone to reproduce a race. |
| Race seed | Derived from session seed, race index, ruleset version, course ID, entrant snapshot and locked weather/input hashes. |
| Ruleset version | Simulation, odds, payout and settlement versions used for the race. |
| Input snapshot | Entrants, attributes, form, course configuration, accepted bets, odds quotes and eligibility state. |
| Event log | Ordered, append-only events with sequence, tick, event type, payload, hash and idempotency key. |
| Checkpoint | Periodic simulation state plus event sequence for interruption recovery and efficient replay. |
| Result commitment | Final order, incidents, settlement inputs and checksum; published only according to lifecycle rules. |

Replay contract: given the same ruleset, input snapshot and race seed, the simulator produces the same event sequence and result checksum. The presentation client may select a different camera path or commentary wording, but it must consume rather than mutate the event stream.


## 9 Architecture

A server-authoritative, browser-client architecture is recommended. The server owns eligibility, bets, odds quotes, seeds, simulation, settlement, persistence and privacy filtering. The big-screen and phone clients subscribe to authorised projections. The host panel uses the same session API but receives a deliberately filtered view in Mystery mode.


| Component | Responsibilities | Trust boundary |
| --- | --- | --- |
| Session service | Create/join/close session, player identity, gem assignment, phase transitions. | Authoritative server |
| Rules and bookmaker service | Eligibility, odds generation, quote locking, payout calculation. | Authoritative server; pure calculation modules |
| Race engine | Fixed-tick simulation, event emission, checkpoints, replay checksum. | Authoritative server or isolated worker |
| Persistence layer | Sessions, players, bets, races, event logs, checkpoints, history, standings. | Server-side database/object storage |
| Projection service | Build phone, big-screen and host views; filter mystery information. | Server-side policy boundary |
| Realtime gateway | WebSocket/SSE events, acknowledgements, reconnect and cursor replay. | Authenticated session channel |
| Big-screen client | Broadcast scenes, cameras, gems, captions, result and finale. | Presentation only |
| Phone client | Cards, Bet button, stake confirmation, balance, history and status. | Player-scoped view |
| Host client | Session control, pause/advance, timings and health. | Host role; mystery-filtered |


### 9.1 Suggested deployment shape

- One web application serving responsive phone, host and big-screen routes, or separately bundled clients sharing typed contracts.

- One authoritative API and realtime channel behind a reverse proxy with TLS in production.

- A relational database for transactional game state and an append-only event store or event table for audit/replay.

- Optional worker process for simulation so a browser or presentation client never becomes authoritative.

- Asset storage/CDN for portraits, course data, sound and replay-friendly media.


## 10 Domain and data model


| Entity | Key fields | Invariants |
| --- | --- | --- |
| Session | id, joinCode, mode, status, rulesetVersion, createdAt, currentRaceId | Join code unique while active; mode immutable after start. |
| Player | id, sessionId, displayName, gemId, balancePennies, status, deviceCredentialHash | One player per session identity; no second starting balance on reconnect. |
| Gnome | id, name, portraitAsset, biography, traits, baselineAttributes, careerState | Stable identity; history append-only; current state derived from completed races. |
| Race | id, sessionId, index, courseId, entrantIds, phase, seed, inputHash, resultHash | Phase transitions monotonic; seed locked before simulation. |
| OddsQuote | id, raceId, gnomeId, quote, impliedProbability, rulesetVersion, quotedAt | Quote immutable once a bet references it. |
| Bet | id, raceId, playerId, gnomeId, stakePennies, oddsQuoteId, status, acceptedAt | At most one accepted bet per player/race; accepted only while open. |
| RaceEvent | raceId, sequence, tick, type, payload, checksum, idempotencyKey | Sequence strictly increasing; payload immutable. |
| Settlement | raceId, playerId, betId, result, payoutPennies, balanceBefore, balanceAfter | Idempotent; cannot apply twice. |
| StandingsSnapshot | sessionId, raceIndex, playerId, points/balance/rank | Not sent to unauthorised clients in Mystery mode. |


## 11 Interface contracts

The following are logical contracts, not a final transport choice. JSON examples should be formalised in an OpenAPI and event-schema package during implementation.


| Contract | Request / event | Response / guarantee |
| --- | --- | --- |
| Join | session code, display name, client nonce | player ID, reconnect credential, gem identity, current public state |
| GetRaceView | session auth, race ID, client role | role-filtered entrants, cards, odds, phase, timer and authorised history |
| PlaceBet | race ID, gnome ID, stake, client idempotency key | accepted receipt or explicit rejection; atomic balance reservation |
| PhaseChanged | race ID, phase, server time, sequence | Clients update UI; no client may advance authoritative phase without host/server rule. |
| RaceEventBatch | race ID, from sequence | Ordered events or checkpoint plus events; replay-safe. |
| Reconnect | player credential, last seen sequence | Current authorised projection and missing events; no duplicate join or balance grant. |
| HostCommand | pause, resume, extend betting, next race, replay | Role-checked state transition or rejection reason; mystery policy preserved. |


## 12 Privacy and security

- Never trust client-supplied balance, eligibility, odds, phase or result data.

- Use short-lived session/player credentials, rotate or revoke recovery credentials, and bind sensitive actions to a player/session identity.

- Mystery mode is a server-side projection policy, not a UI convention. Do not send balances, standings, ranks, eliminations or hidden aggregates to clients that should not see them.

- Gnome Gems are intentionally public after betting closes; stake size, exact payout and balance remain private unless Open mode explicitly publishes a summary.

- Do not expose race seeds, future event streams or post-race form updates before the relevant lifecycle boundary.

- Log administrative actions and settlement idempotency outcomes without logging secrets or unnecessary personal data.

- Use display names only; avoid collecting real names, email addresses or phone numbers in the first release.


## 13 Lifecycle and state machines


### 13.1 Session

Lobby → RegistrationClosed → InProgress → PausedBetweenRaces → Completed. A session may enter Interrupted from any presentation state and return to the correct authoritative state after recovery. Terminal Completed cannot accept bets or new players.


### 13.2 Race

Preparing → Introduction → BettingOpen → BettingClosed → Simulating → PresentationFinished → Settling → Published → Archived. Each transition is server-authorised, recorded once and idempotent. A crash during Simulating resumes from the latest checkpoint or restarts from the committed input snapshot and verifies the same result hash.


### 13.3 Bet

Draft on phone → Submitted → Accepted or Rejected. Accepted → Won, Lost, Void or Refunded only through the settlement service. A client retry with the same idempotency key returns the original decision.


## 14 Presentation and accessibility


| Interface | Required content |
| --- | --- |
| Big screen | Course/title, countdown, entrants, odds during betting, race view, live order strip, Gnome Gems, finish, replay, result and finale. |
| Phone | Join, gem identity, balance, cards, portrait/biography/traits/history/odds, Bet button, stake confirmation, receipt, settlement and personal history. |
| Host | Session setup, connected players, phase, race progress, pause/resume, betting extension before close, next race and recovery status. |

- Use distinct gem colours plus shapes/symbols; never rely on colour alone.

- Provide optional subtitles and ensure the big-screen UI remains legible from several metres away.

- Keep player identity and balance private on phones; use only the public gem mapping on the big screen.

- Camera selection responds to race events and action, not the number or value of backers.


## 15 Open issues, recommendations and deferred features


| Topic | Classification | Decision needed / proposed handling |
| --- | --- | --- |
| Winning return convention | Open issue | Choose stake-plus-profit, profit-only or another rule; encode as a versioned payout policy. |
| No-bet / skipped race | Open issue | Decide whether an eligible player may skip without penalty and whether this affects standings. |
| Tie handling | Open issue | Define championship and race tie rules; source suggests joint champions as a possible outcome. |
| Career persistence scope | Open issue | Decide whether the 48-gnome roster is global, installation-local or session-seeded; first release can use installation-local persistence if approved. |
| Course names and themes | Open issue | Approve six-course catalogue and initial three; prototype only needs one complete course. |
| Host as competitor | Recommendation | Allow host to play through a separate player identity, but apply the same mystery filtering and no extra privileges. |
| Automatic advance | Recommendation | Off by default; allow host to enable after a stable first release. |
| Anonymous betting | Deferred | Could hide gem identities after close; conflicts with the current social Gnome Gems decision and should be optional later. |
| Voice synthesis and advanced cinematic 3D | Deferred | Add after simulation, contracts and presentation state are stable. |
| Cross-household online play | Deferred | Initial scope is a local/social session with a hosted server boundary; broader accounts and matchmaking require a separate privacy design. |


## 16 Tests and acceptance criteria


### 16.1 Simulation and fairness

- Same seed plus identical input snapshot produces the same result checksum and ordered event log.

- Changing only the presentation camera or commentary cannot change the result checksum.

- Every accepted bet has exactly one settlement outcome; retries do not double-spend or double-pay.

- No bet is accepted after the atomic BettingClosed event.

- Form changes are bounded, versioned and applied only after official completion.

- Chain reactions terminate within configured depth/time budgets.

- Odds generation is reproducible from its declared inputs and does not reveal the race seed before betting closes.


### 16.2 Multiplayer and privacy

- A session supports 2–20 players with unique gem identities, including multiple backers on one gnome.

- Reconnect restores the same player, balance, bet and gem without granting a second £500.

- Mystery clients and host views contain no standings, rank, balance or elimination data before the finale.

- Open mode shows the agreed public standings while keeping personal phone details coherent.

- All host commands are role-checked, auditable and safe to retry.


### 16.3 Presentation and usability

- All major race phases render on a 16:9 1080p display and remain understandable with sound off.

- Gnome Gems remain associated with the correct runner through movement, incidents, off-screen repositioning and replay.

- Cards expose the required fields and Bet button; after placing one bet, further bet attempts are visibly disabled.

- The host can pause between races and recover from a closed big-screen browser without generating a new race.

- Subtitles and non-colour gem identifiers are available.


## 17 Milestones and agent-ready task breakdown


| Milestone | Outcome | Agent-ready work packages |
| --- | --- | --- |
| M0 Specification lock | Approved rules, unresolved decisions recorded, schema conventions chosen. | Create ADRs; resolve payout, ties, skip and persistence; define ruleset versioning. |
| M1 Simulation prototype | One course, eight runners, deterministic fixed-tick engine and replay checksum. | Implement domain types; PRNG streams; runner state; obstacles; incidents; event log; checkpoint/replay tests. |
| M2 Economy and persistence | Players, balances, odds, one-bet rule, settlement and 48-gnome history. | Implement transactional repositories; bookmaker; payout policy interface; idempotent settlement; form update; migration/seed data. |
| M3 Session and realtime | 2–20 joins, gem assignment, phase machine and reconnect. | Implement auth/session credentials; join/reconnect; phase transitions; WebSocket/SSE cursor protocol; role filters. |
| M4 Phone experience | Cards, Bet button, stake confirmation, receipt, balance and history. | Build responsive routes; accessibility; optimistic UI only where safe; error and reconnect states. |
| M5 Host and big screen | Race-night loop and recovery controls. | Build host panel; broadcast scenes; timer; live order; Gnome Gems; captions; pause/recovery. |
| M6 Content and polish | Prototype course to playable quality; three initial courses and first 48-character content pass. | Author course data; portraits; biographies; traits; camera anchors; sound/commentary hooks. |
| M7 Hardening | Release candidate suitable for social playtests. | Load test 20 players; privacy review; fault injection; replay audit; visual QA; runbook; acceptance sign-off. |


### 17.1 Suggested repository boundaries

- packages/domain: pure types, invariants and state machines.

- packages/simulation: deterministic engine, PRNG, incidents, checkpoints and replay.

- packages/economy: odds, quotes, payout policy and settlement.

- packages/contracts: API schemas, event schemas and generated client types.

- services/session: authentication, session lifecycle, persistence and realtime.

- apps/phone, apps/host, apps/broadcast: role-specific clients sharing design tokens.

- content/gnomes, content/courses, content/commentary: versioned data assets.


## 18 Operational considerations

- Expose health and readiness for API, database, realtime gateway and simulation worker.

- Keep race-night logs correlated by session ID, race ID and event sequence.

- Provide a host-facing recovery banner with current authoritative phase and last committed sequence.

- Retain event logs long enough for a race-night replay and support export of a human-readable result summary.

- Back up persistent gnome history separately from ephemeral session state if career persistence is approved.


## 19 Provenance and related resources

This document consolidates the design decisions established in the referenced ChatGPT conversation and the requirements in the accompanying request. It is credited to OpenAI ChatGPT (GPT-6). Created and revised 14 November 2026.


| Resource | Reference |
| --- | --- |
| Originating conversation | Game Structure Planning — conversation ID 6af89630-6e28-83ed-9915-df99957a8357; direct conversation URL was not available in the source. |
| Available related resources | No external design files, code repositories, image assets or approved course catalogue were supplied with the referenced conversation. |
| Design source coverage | Conversation material reviewed through version 1.0 presentation/host design and the preceding Gnome Gems and character-card decisions; this document marks any remaining uncertainty explicitly. |

End of review draft.
