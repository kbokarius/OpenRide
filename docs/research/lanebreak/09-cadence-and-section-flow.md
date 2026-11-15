# Cadence bands and section flow — November 15, 2026

## Sources inspected

- [Tech Couch: Peloton Lanebreak Demo](https://www.youtube.com/watch?v=Ysu39oG-wk4). Inspected the video in Chrome around 1:29, 1:51 and 2:13 for visible lane and section cues. These frames alone do not establish a complete cadence table.
- [TheChanClanLife: Lanebreak ride demonstration](https://www.youtube.com/watch?v=g7JDWk4cw_0). November 2021 beta footage, not proof of every current course. Inspected video frames and the available auto-generated transcript. Around 2:33–2:48 the rider identifies lane 3 and a 70–90 rpm range. At 7:08 the on-wheel range visibly reads 52–72 with resistance 72 and cadence 61 in a high lane. At 1:36 the narration describes 55–75. The numbers vary by authored section; the footage does not prove a universal one-to-one lane table.
- [Peloton's official Lanebreak description](https://www.onepeloton.com/bike/lanebreak) and [launch article](https://www.onepeloton.com/blog/lanebreak): six resistance-controlled lanes; Streams use sustained cadence, Breakers use output; levels have different workout types and flows. Neither publishes a complete lane/cadence mapping.

## Implementation decision

Use a simple, predictable 20-rpm-wide work band that drops every two lanes: 85–105, 70–90, 55–75. Warm-up stays at 75–95. These are our chosen targets inspired by the footage, not an assertion that all Lanebreak rides use those exact values. Keep the five difficulty resistance ranges unchanged.

The user's revised ten-second minimum for Collect and Pedal speed is measured at maximum game speed. Power Burst lengths vary 5/6/7 road-seconds. Lane-change gaps stay clear of mines. These are Lane Smash design requirements, not copied claims about Peloton's timing.
