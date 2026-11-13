# Difficulty ranges — November 13, 2026

## Evidence

- [Peloton: Lanebreak](https://www.onepeloton.com/blog/lanebreak) describes six resistance-controlled lanes and difficulty selection.
- [Pelo Buddy: June 22, 2023 difficulty update](https://www.pelobuddy.com/new-lanebreak-levels-bike/) includes a screenshot of the Peloton selector and reports five Bike levels: Light 15–56, Moderate 20–61, Hard 25–66, Challenging 30–71, Extreme 35–76.
- [Pelo Buddy: target metrics](https://www.pelobuddy.com/target-metrics-lanebreak/) also lists five difficulty options.

These are the published Bike ranges found during research, not an assertion that every current Peloton account has identical software. No source establishing six difficulty presets was found. Six refers to the road's lanes in the official description.

## User decision

The user initially requested six difficulties. After seeing the five published ranges and an optional sixth-level proposal, they clarified: use those five. They normally ride Challenging or Extreme. Lane Smash therefore defaults to **Challenging**, with no added Recovery or Elite level.

## Implementation

Each inclusive 42-value range is partitioned evenly into six lanes of seven integer resistance values. The outer bounds are sourced; the equal per-lane subdivision is our explicit design choice, not a separately verified Peloton specification.

| Level | Overall | Lane 1 | Lane 2 | Lane 3 | Lane 4 | Lane 5 | Lane 6 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Light | 15–56 | 15–21 | 22–28 | 29–35 | 36–42 | 43–49 | 50–56 |
| Moderate | 20–61 | 20–26 | 27–33 | 34–40 | 41–47 | 48–54 | 55–61 |
| Hard | 25–66 | 25–31 | 32–38 | 39–45 | 46–52 | 53–59 | 60–66 |
| Challenging | 30–71 | 30–36 | 37–43 | 44–50 | 51–57 | 58–64 | 65–71 |
| Extreme | 35–76 | 35–41 | 42–48 | 49–55 | 56–62 | 63–69 | 70–76 |

Historical beginner/intermediate/advanced/expert keys retain 20/24/30/34 lower bounds for stored replays. New keys have separate comparison identities, so a previous score cannot silently move to a different resistance envelope.
