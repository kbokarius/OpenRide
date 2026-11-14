# Challenging resistance comparison

Checked November 14, 2026 after the owner's ride on the Original Bike. Research only: no difficulty ranges, resistance decoding, physical calibration or cadence bands were changed for this investigation.

## What is established

- Lane Smash's Challenging range remains **30–71**. Its six inclusive lanes are 30–36, 37–43, 44–50, 51–57, 58–64 and 65–71. Lane 6 accepts **65**; there is no requirement to center the motorcycle at 68 or to turn up to 71.
- `BikeDataMapping.kt` reads `currentResistance` directly, clamped to 0–100. No multiplier or difficulty offset is added to the displayed sensor value. `NeonRules.band()` uses the difficulty only to map that value to a lane. Lane Smash does not call the native resistance setter. The internal 150 W reference affects scoring/star credit, not the resistance knob.
- Peloton describes the original Bike's brake as a **manual magnetic resistance system**. On the same Bike at the same physical knob position, switching apps does not itself increase the brake load. See [Peloton's calibration guidance](https://support.onepeloton.com/s/article/115005204826-Calibrating-Your-Peloton-Bike?language=en_AU). The searchable official excerpt was available; the US article's page renderer returned a CSS/loading error.
- Peloton's own difficulty selector, captured in the June 2023 update, shows Challenging 30–71: [selector screenshot](https://www.pelobuddy.com/wp-content/uploads/2023/06/NewLanebreakDifficulty.jpg), [publication context](https://www.pelobuddy.com/new-lanebreak-levels-bike/). The [official Lanebreak explanation](https://www.onepeloton.com/blog/lanebreak) confirms that difficulty determines lane resistance ranges.

## What is still inferred

The current six individual Challenging lane boundaries have not been read directly from this owner's current Lanebreak installation. Our equal seven-value split is supported by older footage showing Peloton's actual Expert and Intermediate lane boundaries, detailed in [the range research](06-difficulty-ranges.md). The overall 30–71 range is directly documented; carrying the historical subdivision into today's Challenging mode remains an inference. No newly found official table establishes every current lane endpoint.

## Plausible reasons it feels harder

1. **Cadence paired with resistance.** Lane Smash asks for 70–90 rpm in lane 5 and 65–85 in lane 6, and its 20% sweet-spot bonus encourages the middle of those bands. Matching the overall resistance range does not match a Lanebreak ride's exact cadence/resistance pairings or time spent there. Peloton's [cadence/resistance explanation](https://www.onepeloton.com/blog/cadence-or-resistance-which-is-more-important) supports the general point that increasing both raises output. The specific difference from the owner's usual Lanebreak rides is a hypothesis, not a measured result.
2. **Where inside the lane the rider settles.** Aiming for the visual center can mean 68 instead of the qualifying minimum 65. Both qualify for the lane. The game does not require the higher value or give ordinary collect/cadence points for it; measured watts can increase Power Burst earnings.
3. **Different workout exposure.** A lane's physical resistance can match while longer holds, different recoveries and repeated bursts make the ride feel harder overall. Revision 16's separately requested move toward work in lanes 3–6 changes exposure, not the resistance ranges.
4. **A current per-lane mapping difference.** Still possible because the full current Lanebreak lane table has not been verified on this tablet. This is a reason to compare before changing the game, not evidence that either table is wrong.
5. **Calibration or hardware change.** Relevant if the same resistance and cadence also feel different in the stock Peloton app. It is not a strong explanation for a difference caused solely by switching apps on the same unchanged manually adjusted Bike. No recalibration is recommended or performed based on this report.

## Narrow verification that would resolve the uncertainty

Read the current Lanebreak Challenging lane-5 and lane-6 endpoints, and compare the two apps' displayed resistance without moving the knob. Then compare cadence at that same resistance. Matching readings would point toward workout demands/within-band position; mismatching readings or endpoints would identify the exact mapping to investigate. That physical comparison has not been performed in this task.
