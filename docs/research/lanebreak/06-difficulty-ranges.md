# Difficulty ranges — November 13, 2026

## Evidence

- [Peloton: Lanebreak](https://www.onepeloton.com/blog/lanebreak) describes six resistance-controlled lanes and difficulty selection.
- [Pelo Buddy: June 22, 2023 difficulty update](https://www.pelobuddy.com/new-lanebreak-levels-bike/) includes a screenshot of the Peloton selector and reports five Bike levels: Light 15–56, Moderate 20–61, Hard 25–66, Challenging 30–71, Extreme 35–76.
- [Pelo Buddy: target metrics](https://www.pelobuddy.com/target-metrics-lanebreak/) also lists five difficulty options.

Rechecked on November 13, 2026 for revision 12 (web search plus the pages below); no newer or conflicting figures were found, and no source gives Peloton's full lane table.

- [Pelo Buddy: hands-on guide, February 23, 2022](https://www.pelobuddy.com/peloton-lanebreak-review-guide/) lists the original four levels as Beginner 20–61, Normal 24–65, Advanced 30–71 and Expert 34–75, says the only difference between levels is that each lane's resistance target is higher, and gives one lane as 38–44 on Intermediate and 48–54 on Expert.
- [Pelo Buddy: beta overview, November 18, 2021](https://www.pelobuddy.com/peloton-lanebreak-beta-video-game-overview/) shows a lane requiring 51–57 (50 moves left, 58 moves right), says the leftmost lane is the easiest and the rightmost the hardest, and shows a cadence target of 85–105.
- [Moore Balanced: design trade-offs, February 2022](https://www.moorebalanced.com/2022/02/trade-offs-in-designing-peloton-lanebreak/) confirms the same 41-point spread on every level.
- The same hands-on guide reports cadence targets ("Streams") as always 20 rpm wide, with 80–100 and 65–85 as examples, and that overcharging a Breaker usually needed 120 rpm or more.

- [Pelo Buddy: review video, February 2022](https://www.youtube.com/watch?v=CrEOhFcpDHE), watched in a browser on November 13, 2026 with frames read at the times given. It is a screen recording of the game, so these are Peloton's own numbers:
  - 2:32 — the difficulty selector, each card labelled "Resistance Range": Beginner 20–61, Intermediate 24–65, Advanced 30–71, Expert 34–75.
  - During play the game prints a number at each edge of the rider's lane. On Expert: **34 | 40** with resistance 38 in the leftmost lane (3:35), **41 | 47** with resistance 44 one lane to the right in the same second of the same ride (6:00), and **48 | 54** with resistance 50 (2:45, where the narration names Expert). The results screen at 5:00 is headed Expert.
  - On Intermediate: **24 | 30** with resistance 28 in the leftmost lane (4:35) and **38 | 44** with resistance 43 (4:12; the narration gives 38 to 44 for Intermediate).
  - The level of each clip is taken from the narration, the results screen and the leftmost lane starting at that level's minimum; the footage does not caption every clip with its level.

**What the lane observations establish.** Six individual lanes, five of them read directly from the game's own display, are all seven values wide and each falls exactly where an equal seven-value split puts it. Expert's first three lanes are 34–40, 41–47 and 48–54: consecutive, no gaps, starting at the level's minimum. Intermediate's first and third are 24–30 and 38–44. The beta screenshot's 51–57 is the fourth lane of 30–71 (no other level contains it on a seven-wide grid). That is `minimum + 7 × (lane − 1)` to six higher on three levels. The footage predates the June 2023 rename to five levels, so the current levels' lanes are inferred, not seen: the rename kept the same 42-value span on every level, and nothing found suggests the lane mechanic changed.

These are the published Bike ranges found during research, not an assertion that every current Peloton account has identical software. No source establishing six difficulty presets was found. Six refers to the road's lanes in the official description.

## User decision

The user initially requested six difficulties. After seeing the five published ranges and an optional sixth-level proposal, they clarified: use those five. They normally ride Challenging or Extreme. Lane Smash therefore defaults to **Challenging**, with no added Recovery or Elite level.

## Implementation

Each inclusive 42-value range is partitioned evenly into six lanes of seven integer resistance values. The outer bounds are sourced. The equal per-lane subdivision began as our design choice; the six lane observations above agree with it, and `lane_smash_catalog_test.gd` (`test_resistance_lanes_match_the_published_lanebreak_ranges`) pins the whole table and those three lanes.

| Level | Overall | Lane 1 | Lane 2 | Lane 3 | Lane 4 | Lane 5 | Lane 6 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Light | 15–56 | 15–21 | 22–28 | 29–35 | 36–42 | 43–49 | 50–56 |
| Moderate | 20–61 | 20–26 | 27–33 | 34–40 | 41–47 | 48–54 | 55–61 |
| Hard | 25–66 | 25–31 | 32–38 | 39–45 | 46–52 | 53–59 | 60–66 |
| Challenging | 30–71 | 30–36 | 37–43 | 44–50 | 51–57 | 58–64 | 65–71 |
| Extreme | 35–76 | 35–41 | 42–48 | 49–55 | 56–62 | 63–69 | 70–76 |

Historical beginner/intermediate/advanced/expert keys retain 20/24/30/34 lower bounds for stored replays. New keys have separate comparison identities, so a previous score cannot silently move to a different resistance envelope.

## Cadence targets (revision 12)

Lanebreak's reported cadence targets are 20 rpm wide and span 65–105 in the examples found (65–85, 80–100, 85–105). Which lane each belonged to is not recorded anywhere we could find. Lane Smash generator 5 uses 20-wide bands that fall with the lane: 95–115, 90–110, 85–105, 80–100, 70–90 and 65–85 for lanes 1–6, and 75–95 while warming up and recovering. The pairing of light lanes with fast cadence and heavy lanes with slow cadence is our choice, made so that effort rises steadily with the lane; the lightest lane's 95–115 is above anything reported for Lanebreak and is deliberate, for pace.
