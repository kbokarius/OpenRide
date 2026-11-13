# NEON VECTOR — implementation ledger

Started 2026-11-13. Branch `feat/neon-vector`. Implements the approved Lane Ride v1 specification and enhancements 1–4. The product name is **NEON VECTOR**; game ID `neon_vector`.

## Architecture decisions

- Existing `Game` host, composed pure rules/course/record classes and a separate track renderer. Rejected a second Android engine/WebView because it would duplicate sensor and lifecycle work.
- Fixed 10 ms scoring ticks fed by timestamped samples. Rendering only interpolates presentation. Rejected latest-frame integration because a render stall would apply a later reading to earlier time.
- Small explicit lifecycle state, composed with shared Session pause authority. Rejected a scene per state: there are no independently animated character behaviors to justify that complexity.
- Original procedural 2D perspective environments, GL Compatibility. Rejected a dense 3D city: readability and sustained frame time on the original Bike matter more than geometry.
- Branches are mutually exclusive alternatives within one event window. The first eligible lane locks the choice. Maximums count the best alternative once, and transition validation considers every possible exit/entry lane. This supersedes v1 R11's single-path restriction. A comfortable route deliberately offers fewer points; the published star denominator remains the course's reachable base maximum.
- Offline daily generator has an explicit version and stored seed/course hash. No server clock or global random generator.
- Reuse GdUnit4 and Kotlin tests, plus timestamped full-course simulations and rendered inspection. Hardware results remain separate from local evidence.

## Delivery checklist

- [ ] Pure lane, scoring, lifecycle and identity rules; focused edge-case tests
- [ ] Ten authored courses; deterministic daily courses; branching validation
- [ ] Shared sensor timestamps, buffered input and timing bridge
- [ ] Course/tier/power setup; gameplay; pause/resume; results/history
- [ ] Best-ride ghosts and score delta, correctly isolated by comparison key
- [ ] Completion-based worlds/trails and offline persistence
- [ ] Durable checkpoints, idempotent result save, backup compatibility
- [ ] Full local ride simulations at varied rendering rates; existing regression suites
- [ ] Rendered visual QA at 1920×1080 and 1920×1008; performance sampling
- [ ] Android mock/real build, fork update configuration and installation notes
- [ ] Commit/push implementation and publish validation report

## Limits to verify on hardware

Exact tablet model/Android version, affernet sample cadence, knob-to-sensor latency, sustained 30-minute GPU performance, installation and signed-update compatibility. Local tests cannot establish these.
