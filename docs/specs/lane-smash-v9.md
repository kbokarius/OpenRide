# Lane Smash revision 9 — incoming-fire sections

## Intent

Add a distinct section in which armored science-fiction attackers materialize above the road and fire visible arcing projectiles at marked landing zones. The rider evades by making a substantial cadence change, with time to react and ramp gradually. Maintain the fixed roller-coaster route, responsive cyclist, readable professional HUD and bounded rendering costs.

Visual reference: Halo's broad armored silhouette, segmented shoulder/chest plates, metallic visor, compact energy weapon and luminous projectile language. Build original geometry and effects for Lane Smash. Reference: [official Spartan Mark VII guide](https://content.halocdn.com/media/Default/community/CosplayGuides/mk7_cosplayguide_mobile-c9b71de988af42f9b6f6010ef44a2417.pdf).

## Implemented play sequence

- Authored, seeded **35-second active-time sections**, first around 75 seconds into the ride, then every three minutes. Their schedule and attacker screen positions are saved in the course snapshot. The final minute remains clear.
- The first six seconds introduce INCOMING FIRE and recommend the lowest resistance lane. Normal lane/cadence targets fade during the attack so the rider receives one clear instruction at a time.
- Two shots lock at section seconds 6 and 21. Each has two seconds of visible charging and nine seconds in flight, for **11 seconds total warning**. There are four seconds between the first impact and the next lock.
- At lock, record the prior two-second average cadence and project its forward travel over eleven seconds. That establishes a fixed road location. The projectile never chases the rider after lock.
- Mark the complete blast footprint across the six-lane road. A visible trajectory connects the weapon to its destination; the projectile follows that arc. A HUD prediction remains readable when the road curves out of view.
- Recommend a substantial increase or decrease, usually **35–40 rpm**, within **45–120 rpm**. At low cadence recommend accelerating; near the cap recommend slowing. A rider may evade on either side of the footprint.
- The longitudinal danger half-length is 20 metres, plus a 1.5-metre rider allowance. A 15 rpm change alone cannot clear it in eleven seconds. A 35–40 rpm response after a two-second reaction and a four-second ramp can. No instantaneous stop or reversal is required.
- Resolve once at impact using actual traveled distance. The footprint covers all lanes, so moving the resistance knob alone is not an escape.
- A hit costs up to 100 existing points. A successful evade earns 100 points and matching base target credit. Show a red loss or teal EVADED popup and a road-anchored blast. One hundred available base-credit points are added per resolved shot.

## Architecture

A pure fixed-tick barrage controller reads the authoritative active clock, cadence history and distance. It creates immutable shot targets and records outcomes. Rendering reads those states but cannot determine collisions. Sensor interruption freezes the same clock; all existing storage/recovery behavior remains in force.

One reusable armored attacker rig, bounded projectile/trail pools, and one landing-zone mesh cover the sequential shots. Smooth material fades, charge/recoil animation and staged impact effects replace node spawning per frame. Curved landing strips use the existing course frame sampler and remain fixed in world space. Compatibility renderer support is required; do not depend on Forward+ trails or decals.

Ordinary score sections and static bombs yield during the attack. Skipped ordinary targets add neither points nor available base credit; their offscreen cursors keep progressing with road distance. Normal targets return smoothly afterward. Last/best scores, ghosts and stars use the updated scoring identity. Legacy course snapshots remain playable without attacks.

## Acceptance criteria

1. All 100 named tracks and random seeds have deterministic, bounded, nonoverlapping attack schedules; no attack overlaps the final minute.
2. Gradual acceleration and deceleration after a realistic delay evade; small changes, unchanged cadence and lane-only changes are hit. Near-zero and capped cadence always receive an attainable recommendation.
3. Identical input at 30/60/120 fps gives identical targets, outcomes, scores and traces. Interruptions do not let attack time or projectiles advance.
4. Targets stay fixed after lock, the displayed trajectory lands in the actual collision footprint, and both safe and hit popups match saved points.
5. No ordinary scoring objects/instructions compete with an attack; normal gameplay resumes afterward.
6. Real rendered review shows recognizable detailed armored attackers, random positions clear of metrics, readable fades, muzzle charge/recoil, an arc/trail and ground warning, plus both evade directions and a hit.
7. Save/ghost compatibility, full track audit, lifecycle/memory checks, performance probe and signed Android build pass. Produce an updated video and validation report, then commit and push.

The values above passed simulation and rendered review. The ordinary 20–47-second lane pattern resumes after each 35-second pace challenge; there is no lane-scoring target during Incoming Fire. Physical Peloton reaction feel and sustained performance remain unverified until device testing.

## Compatibility and validation

New courses use course version 6, generator version 4 and scoring version 5. Original bomb courses retain scoring version 4; legacy snapshots keep their comparison identity. Room remains schema 9. Summary history omits the detailed shot trace while replay records preserve it. See [validation](lane-smash-v9-validation.md) for executable checks, measurements and remaining device limitations.
