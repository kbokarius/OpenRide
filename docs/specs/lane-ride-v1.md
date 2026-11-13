# Lane Ride: implementation specification v1.0

Date: 2026-11-13. Original Bike. Status: pre-implementation specification.

This document supersedes `docs/research/lanebreak/05-proposal.md` where they differ. Difficulty is a resistance envelope, not obstacle density.

## Product contract

01 / PURPOSE & SCOPE

A silent, six-lane cycling game controlled by the original Bike's resistance knob.

Working name: **Lane Ride**. This is an original Lanebreak-inspired mode inside OpenRide. The implementation must preserve the requested feel: follow a forward-moving track, change lanes by turning resistance, meet cadence/power challenges, and improve a score across repeatable rides.

### Non-negotiable requirements

| ID | Requirement |
| --- | --- |
| R01 | Six lanes, left to right from lowest to highest resistance. |
| R02 | Difficulty sets the resistance envelope across those lanes. Course timing, challenge density, cadence windows and score ceiling stay the same. |
| R03 | All instructions and feedback work with music and effects completely off. No audio timing dependency. |
| R04 | A library of fixed rides at different lengths and difficulties, with points, stars, history and personal bests. |
| R05 | Original Bike sensor integration through OpenRide; no camera, lean steering, subscription or server needed to ride. |

### Document authority

Version **1.0**, November 13, 2026. The user's resistance-envelope requirement supersedes the earlier research proposal's three-tier and difficulty-tuning suggestions. Numbers marked **provisional** are explicit implementation defaults to validate on the Bike; they are not claims about Peloton's current algorithms.

This document defines the build. It does not claim that an APK exists or that the target tablet has been tested. Hardware model, Android version and firmware remain unknown beyond the original, non-rotating-screen Bike family.

Out of the first release: music services, online leaderboards, multiplayer, camera games, automated resistance control and copied Peloton assets or courses. Five optional enhancements are presented separately from the baseline spec.

## Specification map

02 / READING GUIDE

| Page | Section | What it resolves |
| --- | --- | --- |
| 4 | Reference mechanics | What was observed; what is our own design. |
| 5 | Difficulty and resistance | Four presets and every lane's exact range. |
| 6 | Lane control | Boundaries, settling, invalid readings and preview. |
| 7 | Challenge rules | Pickups, cadence holds and power charges. |
| 8 | Scoring | Exact formulas, ceilings, stars and record eligibility. |
| 9 | Ride content | Library, course authoring and a 20-minute structure. |
| 10 | Screen and interaction | An original wireframe and complete user flow. |
| 11 | Session lifecycle | Pause, stop, sensor loss, exit and interruption. |
| 12 | OpenRide integration | Ownership, bridge changes and shared behavior. |
| 13 | Data and persistence | Course schema, result identity and recovery. |
| 14 | Verification | Acceptance tests and hardware targets. |
| 15 | Build and distribution | Implementation sequence and install/update plan. |
| 16 | Evidence register | Direct sources and limits of this research. |

### How to interpret the specification

**Required** means the implementation must satisfy it. **Provisional default** means implement the stated value as configurable data, then adjust only with a documented tuning revision. **Observed** describes the reference product. **Original design** defines our own behavior where Peloton's exact rules are not public.

### Acceptance boundary

Desktop logic and visual tests can establish correctness before the Bike is available. Daily-use readiness additionally requires a full physical ride, real knob-response measurements, saved results, update checks and a verified backup path. An untested tablet cannot be declared compatible from its screen shape alone.

## Reference mechanics

03 / RESEARCH FINDINGS

Research combined Peloton's own explanations, first-hand launch reviews and direct visual inspection of the recorded tutorial. The public footage is historical; it establishes mechanics, not a current ride catalog or exact current scoring formula. [S1-S4]

| Observed behavior | Implication for Lane Ride |
| --- | --- |
| Resistance chooses one of six lanes; higher resistance moves right. | Steering reads resistance, never watts or camera position. |
| Difficulty changes lane resistance ranges. | Preserve the same authored course and point opportunities across tiers. |
| Lane markers, cadence windows and output-charge sections alternate along the track. | Keep all three challenge types in one continuous scene. |
| Upcoming targets are visible before the rider reaches them. | Show at least 8 seconds of course preview by default. |
| Charge sections show a base target and additional overcharge. | Use a bounded 0-200% meter with clearly defined original math. |
| A result screen reports score, stars and challenge performance. | Keep the breakdown available later in ride history. |

### Video observations

The Connect The Watts tutorial was sampled at approximately **0:19** (steering/track), **0:39** (difficulty reminder), **1:38** (pickup completion), **1:58** (cadence section), and **2:37-2:57** (charge section). Its automatic captions contain almost only music labels; the observations came from the frames and written sources, not an informative transcript. [S3]

### Known versus deliberately specified

Historical reviews show four difficulty presets and roughly seven integer resistance values per lane. Exact current charge mathematics, hit tolerance and all star rules are not established. Pages 6-8 therefore define our own deterministic rules rather than implying exact Peloton scoring parity. [S4-S5]

Only names describing the reference product appear in research. The shipped game uses original name, art, code, challenge layouts and UI treatment.

## Difficulty is resistance

04 / REQUIRED CONTROL MODEL

Selecting a difficulty remaps the same six lanes into a different resistance envelope.

The following **provisional presets** reproduce resistance envelopes reported in a 2022 hands-on guide. They are a concrete starting point, not a claim about today's Peloton defaults. The second tier is named Intermediate here. [S4]

| Difficulty | Min-max | Lane 1 | Lane 2 | Lane 3 | Lane 4 | Lane 5 | Lane 6 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Beginner | 20-61 | 20-26 | 27-33 | 34-40 | 41-47 | 48-54 | 55-61 |
| Intermediate | 24-65 | 24-30 | 31-37 | 38-44 | 45-51 | 52-58 | 59-65 |
| Advanced | 30-71 | 30-36 | 37-43 | 44-50 | 51-57 | 58-64 | 65-71 |
| Expert | 34-75 | 34-40 | 41-47 | 48-54 | 55-61 | 62-68 | 69-75 |

(See PDF diagram: bands.)

### What changes, and what stays fixed

**Changes:** the actual resistance needed to occupy each lane. **Fixed:** ride duration, event order, lane assignments, cadence bands, output target ratios, preview times, score ceiling and star thresholds. Difficulty does not secretly narrow the timing window, add obstacles or accelerate the timeline.

Power challenge targets use a separate, visible rider reference-power setting (page 7). It never determines steering or changes the resistance limits. Difficulty and that target setting are locked for the attempt and included in the personal-best comparison key.

Display the full min-max range before Start, each lane's integer band near the rider, and the current resistance. Presets are versioned data; changing them creates a new comparison identity.

## Lane control and preview

05 / DETERMINISTIC INPUT RULES

### R06 - Map integer sensor readings to lanes

OpenRide reports resistance as an integer from 0 to 100. For the initial presets, let lo and hi be the inclusive envelope endpoints. There are hi - lo + 1 = 42 integer values, so each lane contains 7. Internal lanes use zero-based indices; the UI displays 1-6.

lane = floor((resistance - lo) / 7), valid only when lo <= resistance <= hi

Example, Intermediate: 30 is lane 1; 31 is lane 2; 38 is lane 3; 44 is still lane 3; 45 is lane 4; 65 is lane 6. Resistance 23 or 66 is outside the course envelope. Validate that all six bands are contiguous, non-overlapping and cover both endpoints.

### R07 - Do not let visual smoothing change scoring

A new lane becomes score-eligible after its band has remained selected for **150 ms** of fresh samples (provisional). During settling, neither the old nor the candidate lane earns points. Crossing multiple bands can jump directly to the final lane; intermediate lanes do not earn pickups. Animate the rider toward the selected lane over at most 150 ms, independently of the scoring state.

Outside the envelope, park the graphic at the nearest edge and show **Increase resistance** or **Lower resistance** with a number. Score is zero until the rider re-enters a valid lane. Never silently clamp an out-of-range reading into a scoring lane.

### R08 - Give the rider time to respond

Render an **8-second preview** and a clear near-field hit line. Every required lane transition must allow at least max(3 seconds, 1.5 seconds x lane distance). Recovery transitions use at least 4 seconds. These are authored defaults to validate against physical knob latency, not just animation timing.

No lane-switch prompt is audio-only. Show the target lane's resistance band, direction, and seconds until entry. Road curves and camera motion are cosmetic; they cannot alter lane geometry, targets or score eligibility.

Boundary cases are mandatory tests: lo-1, lo, every upper/lower lane boundary, hi, hi+1, rapid crossings, stationary jitter and return from stale data.

## Three challenge types

06 / ORIGINAL GAMEPLAY RULES

| Type | Player action | Scoring behavior |
| --- | --- | --- |
| Pickup | Enter the marked lane as a transverse marker reaches the hit line. | Each marker scores once. A +/-250 ms window accepts the first valid settled-lane sample, with cadence >=20 rpm. |
| Cadence hold | Stay in the target lane and within the displayed inclusive rpm band. | Accrue points for valid time only. Too low/high rpm shows an arrow; returning to range resumes accrual. |
| Power charge | Stay in the target lane while filling a 0-200% charge meter. | Integrate measured watts over the authored zone using the rule below. Higher resistance is still chosen only through lane position. |

### R09 - Shared validity

Every type requires Playing state, fresh valid sensors, in-envelope settled target lane and cadence >=20 rpm. There is no reward for merely holding resistance while stationary. Invalid time earns zero. Pickup tolerance does not extend through a pause; score state and consumed event IDs are retained.

### R10 - Charge definition, independent of music

Use the rider's **reference power F**, initialized from stored FTP when available; otherwise use the clearly labeled provisional 150 W default. FTP is the power reference already used by OpenRide. Before Start, show the actual watt targets and allow adjusting F. No measurement or fitness test is implied by the default.

For a zone of duration D, default P100 = 0.60 x F and P200 = 1.00 x F. Define q(P) = P/P100 below P100; above it, q(P) = 1 + (P-P100)/(P200-P100), capped at 2. Integrate q only during valid time: charge = min(2, integral(q dt)/D). A one-second trailing power average reduces flicker; it resets after sensor loss.

While cadence is above **120 rpm**, charge accumulation is zero and **Ease cadence** appears; previously earned charge is retained. This is a scoring ceiling, not individualized exercise advice. The 0.60/1.00 ratios and 120 rpm limit are provisional tuning constants, unchanged across tiers. Validate that F is positive and finite. Charge stops increasing at 200%.

At F=150 W: 90 W throughout a 10 s zone yields 100%; 150 W throughout yields 200%; 90 W for only 5 valid seconds yields 50%. These are our formulas, not a reverse-engineered Peloton formula.

## Points, stars and records

07 / SCORING CONTRACT

Use deterministic 10 ms simulation steps and fixed-point subpoints (1 point = 100,000 units). Keep fractions until display/finalization. Integrate the same timestamped sensor trace identically at any rendering frame rate. Display floor(total points); never round every frame.

| Event | Original scoring rule | Maximum |
| --- | --- | --- |
| Pickup in lane L | Base = 100 + 20 x (L-1), where L is 1-6. Award once. | 100-200 per marker |
| Cadence hold | 10 points per valid second; no extra score for exceeding the target band. | 10 x D |
| Power charge | Base B = 10 x D. Earn B x min(charge,1), plus 0.5 x B x max(charge-1,0). | 1.5 x B |

### R11 - One published maximum per course

Compute maxScore from the validated event list before Start. The first release uses one prescribed target lane at a time, so there is no unreachable sum of simultaneous alternatives. Shared OpenRide effort multiplication must be **off** for this game; otherwise higher difficulty would change the score ceiling. Do not add combo multipliers in the baseline.

### R12 - Stars measure completion, not overcharge

completion = earned base points / available base points. Exclude the power-charge bonus from both numerator and denominator. Provisional thresholds: **1 star at 25%, 2 at 60%, 3 at 90%**. An early-ended or interrupted ride retains its partial score/history but earns no course-completion stars or personal-best replacement.

### Worked example

One lane-3 pickup is worth 140. A 10 s cadence hold has 100 available points; 8 valid seconds earns 80. A 10 s charge at 150% earns 125: 100 base +25 bonus. Total = **345 / 390 maximum**. Base completion = (140+80+100)/(140+100+100) = **94.1%**, so a fully finished example course earns 3 stars.

### R13 - Compare like with like

Personal best key: rider + course ID/version + difficulty/envelope version + scoring version + reference-power target settings. Save the resolved values, not just a mutable preset name. Changing F or presets starts a separate comparison bucket. Stars and bests are stored per difficulty. There is no online leaderboard in v1.

## Rides are authored data

08 / CONTENT & PROGRESSION

R14 - Ship a 5-minute tutorial plus **nine authored rides**: Steady Flow, Intervals and Rolling Climb, each at 10, 20 and 30 minutes. All ten courses support all four difficulty presets. A duration variant is its own reviewed course, not a random crop of a longer ride.

(See PDF diagram: timeline.)

| Family | Character | Authored constraints |
| --- | --- | --- |
| Steady Flow | Longer cadence holds and predictable lane moves. | Mostly adjacent transitions; frequent pickups; fewer charges. |
| Intervals | Short charge efforts separated by easier riding. | Charges 8-15 s; at least 30 s recovery between charges. |
| Rolling Climb | Gradual movement across resistance lanes. | Longer holds; no high-lane jump directly out of a charge. |

### Course compiler / validator

Each JSON course declares ID, version, duration, phases and event IDs. Each event has type, start/end time, target lane and type-specific parameters. Times use integer milliseconds. Reject missing IDs, overlaps requiring different lanes, events outside duration, invalid cadence bands, unreachable lane transitions, bad target ratios and pickup windows that overlap conflicting challenges.

Warm-up/cool-down are included in the advertised duration; pre-ride countdown is not. Recovery can have low-lane pickups or easy cadence holds, but no charge. No event extends beyond the course end. The course finishes on elapsed active time, not simulated distance or pedaling speed.

### Tutorial sequence

Explain left/right resistance control, practice changing two lanes, collect pickups, hold a cadence band, fill a charge meter, then combine the three. Prompts can pause instruction time before scored play; the tutorial uses its own fixed scored sections and reports practice results separately from full-course records.

The 20-minute example totals exactly 1,200 active seconds: 180 warm-up + 3 x 240 work blocks + 2 x 60 recoveries + 180 cool-down. Content targets remain provisional until real-bike evaluation.

## Screen and interaction

09 / ORIGINAL WIREFRAME

(See PDF diagram: screen.)

Schematic only: original layout guidance, not finished artwork. Reuse OpenRide's typography, large controls, status treatment and pause/results conventions.

### R15 - Start flow

Home/Games > Lane Ride > select course > select Beginner/Intermediate/Advanced/Expert > inspect duration, resistance envelope, target watts and previous result > Start. If sensors are missing, keep Start disabled with a visible reason. A 3-second unscored countdown begins after a valid connection.

### R16 - During the ride

Keep score and elapsed/remaining time stable on screen. Show cadence, watts and resistance near the rider; show all lane bands and emphasize the active band. Above the track, display one upcoming action: direction, target range and countdown. Holds show rpm range plus low/in-range/high feedback. Charges show target watts and a capped 0-200% meter.

Only Pause and End need touch during normal play. End asks to save the incomplete attempt or continue. No menus, camera calibration, music prompts or pop-ups may cover an active challenge.

### R17 - Result flow

Show total/max score, base completion, stars, new-best status, pickup accuracy, time in cadence range, each charge result, elapsed time and ride metrics. Offer Ride again, Choose ride and Exit games. The same breakdown remains available from History.

## Lifecycle and failure behavior

10 / STATE MACHINE

(See PDF diagram: states.)

| Trigger | Required behavior |
| --- | --- |
| Manual pause / app background | Freeze course and scoring immediately. Preserve charge, consumed pickup IDs and timer. Resume with 3 unscored seconds while track stays still. |
| Cadence below 20 rpm | Score zero immediately. If it remains below 20 for 3 s, pause the game clock; the prior 3 s count as missed opportunities. Resume explicitly. |
| Sensor sample older than 1.5 s | Freeze clock and scoring; show Sensors unavailable. Freshness is based on real delivery time, not changed values. |
| Sensor recovery | Require 1 s of fresh valid samples, then show Resume. Clear stale smoothing history and settling state; do not automatically restart effort. |
| Render stall >250 ms | Pause before processing the stalled interval. Do not fabricate missed sensor history or grant accumulated points. |
| End before completion | Save an incomplete attempt. Keep history/metrics; exclude it from completed bests and course stars. |
| Process death / relaunch | Recover the last persisted partial checkpoint as interrupted. Offer a fresh attempt; no mid-course scoring resume in v1. |
| Course timer reaches duration | Finalize exactly once. Commit score and result identity atomically, then show results. |

R18 - Lane Ride uses one pause authority across Kotlin and Godot. A request from Android, the game, stale-data detection or freewheel detection must converge on the same state; a late resume signal cannot override a manual pause. Keep explicit pause reasons until all blocking reasons clear.

The existing app's shared sensor banner can be slower than precision gameplay needs. Lane Ride must add timestamp-based freshness handling rather than infer fresh data from the existing delayed sensors_ok flag. The 1.5 s threshold supports the upstream 1 Hz polling fallback with limited margin and requires on-bike validation.

## OpenRide integration

11 / IMPLEMENTATION DESIGN

(See PDF diagram: architecture.)

### Chosen pattern

A new **Game subclass + pure rules objects + data-driven courses** inside the existing Godot host. Reuse InputBus, Session, HUD, pause/results styling and Android recording. This isolates testable scoring from visuals and preserves OpenRide's existing controls. A second Android app engine or a WebView game would duplicate sensor/lifecycle integration and is outside this design.

| Component | Responsibility |
| --- | --- |
| LaneRideRules / LaneResolver | Pure deterministic lane, event, charge and scoring decisions. |
| CourseLoader / CourseValidator | Parse/version/validate bundled JSON; compute maxima and target schedule. |
| LaneRide scene / TrackRenderer | Project six lanes, previews and event geometry; interpolate visual state only. |
| Kotlin plan + session integration | Load resolved course settings, timing authority, recording and interruption metadata. |
| History / backup integration | Persist breakdown and comparison identity; expose them after the ride. |

### R19 - Bridge and difficulty compatibility

Keep existing shared Easy/Standard/Hard behavior unchanged. Add game-specific laneDifficulty and envelope data; use Standard as the legacy transport value while including the true lane difficulty in variant/plan identity and labels. Never present that legacy value as the selected tier for Lane Ride.

Append versioned optional frame fields: sample_age_ms, sample_sequence and course_elapsed_ms. Add get_lane_ride_input_batch(after_sequence): ordered timestamped samples from a 5 s ring buffer, plus an overflow flag. Repeated reads of only the latest frame cannot satisfy deterministic replay. Overflow pauses scoring. Existing games ignore the extension; Lane Ride requires it. Document the contract in docs/GAMES.md.

Kotlin timestamps actual callback/poll deliveries and owns monotonic active time. Godot processes ordered samples with zero-order hold on fixed ticks and acknowledges its processed time; the host excludes an unprocessed stalled interval when pausing. Disable the generic Effort multiplier and camera. Update clock and bridge tests together.

## Data and persistence

12 / CONTRACTS & STORAGE

### Course contract - required fields

| Object | Fields |
| --- | --- |
| Course | schemaVersion, courseId, courseVersion, title, durationMs, family, phases[], events[] |
| Event | eventId, type, startMs, endMs, laneIndex; pickup hitMs, hold cadenceMin/Max, or charge target ratios |
| Resolved attempt | attemptId, riderId, course hash/version, difficulty ID, six lane bands, envelope version, reference power, scoring version |
| Result | status, activeDurationMs, scoreUnits, maxScoreUnits, earned/available base units, stars, event breakdown, metrics linkage |
| Checkpoint | attemptId, activeDurationMs, cumulative score/metrics, committed event IDs, last write time; never used to award a resumed best |

### Example event fragment

pickup-001: type=pickup; hitMs=15000; laneIndex=2.
hold-001: type=hold; startMs=20000; endMs=30000; laneIndex=2; cadenceMin=70; cadenceMax=90.
charge-001: type=charge; startMs=35000; endMs=45000; laneIndex=2; ratio100=0.60; ratio200=1.00.

### R20 - Results and backward compatibility

Reuse game_results for finalized results and statsJson for versioned breakdowns. Encode course/difficulty/target identity into stable plan/variant keys; use a canonical sorted serialization plus hash to avoid accidental collisions. The visible labels come from persisted metadata, not by parsing a display string.

Add a small durable pending-attempt record if existing storage cannot safely represent checkpoints. Write a checkpoint at least every 5 active seconds and at pause/background boundaries. On successful finish, write the finalized result and clear pending state in one Room transaction. Make the attempt ID idempotent so duplicate finish callbacks cannot double-save.

If schema changes are needed, add Room migration(s), exported schema, migration tests and backup-format compatibility in the same change. This is a Room project, not Drizzle. Old profiles/rides must still load. Backups include completed Lane Ride results; pending records restore as interrupted, never as live scoring sessions.

Record cadence/power/resistance samples locally for workout history. No account credentials, analytics service or network sync are required. Keep data on the device unless the rider explicitly exports it.

## Acceptance and test plan

13 / DEFINITION OF DONE

| Test group | Required acceptance |
| --- | --- |
| T01 - Mapping (R01/02/06/07) | All four lane tables cover exactly their endpoints. Boundaries, out-of-range readings, jitter and rapid crossings obey page 6. |
| T02 - Difficulty (R02/13) | The same course has identical events and maxima at all four tiers. Only envelope changes; saved bests never cross tier/target buckets. |
| T03 - Events (R09/10/11) | A pickup awards once; hold integrals match valid time; charge examples match 50/100/200%. Zero cadence and invalid lanes earn zero. |
| T04 - Determinism (R11) | Replay one timestamped trace at 30/60/120 rendering fps: exactly the same fixed-point score and event outcomes. |
| T05 - Interruptions (R18) | Pause/resume, stale-but-unchanged values, poll fallback, background, stalls and process death obey the state table. |
| T06 - Records (R12/13/20) | Incomplete attempts cannot replace bests. Finish is idempotent. Old Room data and backup round-trips preserve results. |
| T07 - Content (R08/14) | All 10 courses pass structural/transition validation; no contradictory targets or events beyond duration. |
| T08 - UI (R03/15/16/17) | All actions are understandable when muted; lane bands, targets and prompts stay readable at both reference window sizes. |

### Physical Bike targets - measured, not assumed

Target **60 fps**, with at least 95% of frames within 20 ms during a 30-minute ride and no repeated stalls above 100 ms. Test 1920x1008 and 1920x1080 layouts. Budget no more than 300 ms from a new sensor reading arriving at the app to stable lane feedback, including the 150 ms settle rule; separately record knob-to-sensor latency.

Use large text (minimum 28 px at the 1920-wide game reference) and touch targets of at least 48 Android dp / about 72 px at the documented density. Symbols and labels accompany colors. No flashing effects are necessary. Aim for 4.5:1 text contrast; measure final colors.

Ride at least one complete course at each difficulty and all course families before daily-use readiness. Verify that charge targets are reachable without scoring above the cadence ceiling. Tune the reference-power ratios or course content explicitly if not; do not secretly change the resistance envelope.

Until tested on the target Bike, mark performance, tuning and hardware compatibility unverified. A desktop demo is not a hardware pass.

## Build and distribution

14 / EXECUTION SEQUENCE

| Stage | Concrete deliverable | Exit condition |
| --- | --- | --- |
| 1. Rules and course compiler | Lane mapping, fixed-step scoring, tutorial JSON and trace tests. | T01-T04 and course validation pass. |
| 2. Playable tutorial | Original track scene, game card, four-tier selector, pause/results and recording. | End-to-end desktop ride; mute-only usability verified. |
| 3. Bike validation | Real-sensor trial; measured knob latency, frame times and interruption behavior. | Physical ride, persistence and full-course timing verified. |
| 4. Content and polish | Nine authored rides, thumbnails, history breakdown and target tuning. | All course/difficulty combinations validate; representative real rides pass. |
| 5. Installable distribution | Signed real-sensor APK, fork update source, backups and installation guide. | Fresh install and in-place update preserve data. |

### Source integration and conventions

Baseline reviewed: upstream bb8a764; research commit 8fc2a13. Keep implementation on a feature branch in kbokarius/OpenRide. Follow the existing Game/logic separation and review other screens before UI changes. CLAUDE.md requests matching GodotPrompter skills before Godot systems are changed; resolve the available skill/tooling before that implementation step.

### R21 - Installation/update identity

Use a distinct experimental application ID and a durable private signing key. Build with real sensors enabled. Configure updates to kbokarius/OpenRide releases, use increasing Android versionCode values, and preserve the APK filename contract or update its parser together. A fork alone still points to upstream's hardcoded updater.

First install through OpenPelo **Install local APK**. Test a future signed update through the app. Keep upstream available during evaluation; a different package avoids Android signing conflicts. Do not reset the tablet, replace its firmware, change Peloton components or cancel the subscription as part of creating this spec.

### Remaining external information

Before physical deployment, obtain the tablet model, Android version and firmware build from the Bike's About tablet screen. This does not block desktop implementation. The original Bike family is confirmed; exact tablet compatibility is not.

The five optional ideas supplied with this document are a separate product backlog. They are not implicit additions to the baseline or blockers for the first playable tutorial.

## Evidence and decision register

15 / SOURCES & LIMITS

Accessed November 13, 2026. Web sources establish reference behavior; the numbered requirements and all formulas marked original design are decisions for this project.

| Ref | Source / use |
| --- | --- |
| S1 | [Peloton: Lanebreak Bike](https://www.onepeloton.com/bike/lanebreak) - official control and three challenge-type descriptions. |
| S2 | [Peloton: Fitness Meets Gaming](https://www.onepeloton.com/blog/lanebreak) - six lanes, resistance-dependent difficulty, stars and results. Historical launch article. |
| S3 | [Connect The Watts: recorded tutorial](https://www.youtube.com/watch?v=FKLik8i1Oig) - directly inspected selected video frames. Visual track, pickup, cadence and charge examples. |
| S4 | [Peloton Buddy: hands-on guide](https://www.pelobuddy.com/peloton-lanebreak-review-guide/) - historical four difficulty envelopes and observed mechanics. First-hand review, February 2022. |
| S5 | [Connect The Watts: launch review](https://connectthewatts.com/2022/02/17/peloton-lanebreak-review-not-perfect-but-a-great-start/) - first-hand comparison of difficulty variants and score progression. |
| S6 | [OpenRide reviewed source](https://github.com/digitalducktape/OpenRide/tree/bb8a764012972611761c3fc5839436dd1cf4acfc) - game framework, sensor types, bridge, scoring, Room persistence and updater. |
| S7 | [OpenRide research notes](https://github.com/kbokarius/OpenRide/tree/main/docs/research/lanebreak) - architecture, issue inventory, compatibility and installation assessment. |

### Explicit decisions

D01: Four resistance-envelope presets replace the prior three-tier proposal. D02: Continuous course, not a chain of different mini-games. D03: Original deterministic score math, with generic Effort multiplier disabled. D04: No audio or camera dependency. D05: Course versions and target settings separate personal-best records. D06: Power reference is separate from resistance difficulty.

### Evidence limits

Video sampling is not a complete recording of every current Lanebreak feature. The old tutorials do not establish today's exact scoring, bands or library. No proprietary code, course extraction, current Bike UI session or physical hardware test was used. Target ranges, charge ratios, settling, freshness and frame budgets require on-device validation.

Prepared as the implementation specification for the owner's OpenRide fork. No game implementation is represented as complete by this document.
