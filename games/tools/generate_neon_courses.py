"""Reproduce the reviewed NEON VECTOR v1 library (runtime reads the committed JSON).

Explicit family patterns and duration-specific phase plans; no runtime random truncation.
Generated files are deliberately readable and can be authored further by hand/version bump.
"""
from pathlib import Path
import json

OUT = Path(__file__).resolve().parents[1] / "games/neon_vector/courses"
PATTERNS = {
    "steady_flow": [1, 2, 2, 3, 2, 1, 2, 3, 3, 2],
    "intervals": [1, 2, 1, 3, 1, 4, 2, 3, 1, 2],
    "rolling_climb": [0, 1, 2, 3, 4, 5, 4, 3, 2, 1],
    "tutorial": [0, 1, 2, 3, 0],
}
PHASES = {
    5: [("Orientation", "warmup", 1), ("Learn the signal", "work", 3), ("Cool down", "cooldown", 1)],
    10: [("Warm up", "warmup", 2), ("Find your line", "work", 2), ("Recover", "recovery", 1),
         ("Build your score", "work", 3), ("Cool down", "cooldown", 2)],
    20: [("Warm up", "warmup", 3), ("Sector one", "work", 4), ("Recover", "recovery", 1),
         ("Sector two", "work", 4), ("Recover", "recovery", 1), ("Sector three", "work", 4), ("Cool down", "cooldown", 3)],
    30: [("Warm up", "warmup", 4), ("Sector one", "work", 6), ("Recover", "recovery", 2),
         ("Sector two", "work", 6), ("Recover", "recovery", 2), ("Sector three", "work", 6), ("Cool down", "cooldown", 4)],
}


def build(family: str, minutes: int) -> dict:
    course = dict(schemaVersion=1, courseId="tutorial" if family == "tutorial" else f"{family}_{minutes}",
                  courseVersion=1, title="First contact" if family == "tutorial" else family.replace("_", " ").title(),
                  family=family, durationMs=minutes * 60000, phases=[], events=[])
    start = 0
    for name, role, length in PHASES[minutes]:
        course["phases"].append(dict(name=name, role=role, startMs=start, endMs=start + length * 60000))
        start += length * 60000
    assert start == course["durationMs"]
    for minute in range(minutes):
        offset = minute * 60000
        phase = next(p for p in course["phases"] if p["startMs"] <= offset < p["endMs"])
        role = phase["role"]
        lane = PATTERNS[family][minute % len(PATTERNS[family])]
        if role != "work":
            lane = min(lane, 1)
        charge = role == "work" and (minute % (2 if family == "intervals" else 4) == 1 or family == "tutorial" and minute == 3)
        if family == "tutorial" and minute < 3:
            charge = False
        prefix = f"m{minute + 1:02d}"

        def pickup(suffix: str, second: int) -> dict:
            return dict(eventId=f"{prefix}-{suffix}", type="pickup", startMs=offset + second * 1000,
                        endMs=offset + second * 1000 + 510, hitMs=offset + second * 1000 + 250, laneIndex=lane)

        event = dict(eventId=f"{prefix}-b", type="charge" if charge else "hold", startMs=offset + 16000,
                     endMs=offset + (26000 if charge else 34000), laneIndex=lane)
        if charge:
            event.update(ratio100=0.6, ratio200=1.0)
        else:
            event.update(cadenceMin=60 if role != "work" else 70, cadenceMax=85 if role != "work" else 90)
            if role == "work" and family != "tutorial" and minute % 3 == 2 and lane < 5:
                event["alternatives"] = [dict(laneIndex=lane, rewardPercent=100), dict(laneIndex=lane + 1, rewardPercent=125)]
        course["events"].extend([pickup("a", 8), event, pickup("c", 44), pickup("d", 48), pickup("e", 52)])
    return course


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    courses = [build("tutorial", 5)] + [build(f, m) for f in PATTERNS if f != "tutorial" for m in (10, 20, 30)]
    for course in courses:
        (OUT / (course["courseId"] + ".json")).write_text(json.dumps(course, indent=2) + "\n")
    print(f"Wrote {len(courses)} authored courses")
