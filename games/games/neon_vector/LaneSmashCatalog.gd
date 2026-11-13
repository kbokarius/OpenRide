class_name LaneSmashCatalog
extends RefCounted
## Frozen generator v1. IDs fully describe reproducible content; snapshots preserve replays.
const LENGTHS := [10, 15, 20, 30]
const NAMES := ["Nightfall", "Vector Run", "Cold Circuit", "Apex Protocol", "Iron Horizon", "Deep Current", "Solar Array", "Black Meridian", "Velocity", "Carbon Ridge", "Arc Reactor", "Zero Gravity", "Afterburn", "Steel Pulse", "Blue Shift", "Outer Ring", "Ion Storm", "Altitude", "Dark Matter", "Redline", "Titan", "Slipstream", "Overdrive", "Summit Relay", "Event Horizon"]
const PATTERNS := ["Rolling", "Cadence", "Power", "Climbing", "Mixed"]
const BACKGROUNDS := ["orbital", "citadel", "asteroid", "reactor"]
const THEMES := ["arctic", "cobalt", "copper", "titanium", "petrol", "amber", "ember", "glacier"]

static func tracks(minutes: int) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if minutes not in LENGTHS:
		return list
	for i in 25:
		list.append({"id": "ls_%d_%02d" % [minutes, i + 1], "title": NAMES[i], "description": "%s · %s" % [PATTERNS[i % 5], NeonWorlds.world(THEMES[i % 8]).title], "theme": THEMES[i % 8], "background": BACKGROUNDS[(i / 3) % 4]})
	return list

static func random_id(minutes: int, seed_value: int) -> String:
	return "ls_r_%d_%d" % [minutes, clampi(seed_value, 1, 2147483646)]

static func load_track(id: String) -> Dictionary:
	var parts := id.split("_")
	if parts.size() == 3 and parts[0] == "ls" and parts[1].is_valid_int() and parts[2].is_valid_int():
		var minutes := int(parts[1])
		var index := int(parts[2]) - 1
		if minutes in LENGTHS and index in range(25) and id == "ls_%d_%02d" % [minutes, index + 1]:
			return generate(minutes, 104729 * (index + 1) + minutes * 1543, index, id)
	if parts.size() == 4 and parts[0] == "ls" and parts[1] == "r" and parts[2].is_valid_int() and parts[3].is_valid_int():
		var minutes := int(parts[2])
		var seed_value := int(parts[3])
		if minutes in LENGTHS and (seed_value >= 1 and seed_value <= 2147483646) and id == random_id(minutes, seed_value):
			return generate(minutes, seed_value, seed_value % 25, id, true)
	return {}

static func generate(minutes: int, seed_value: int, index: int, id: String, random_track := false) -> Dictionary:
	var state := seed_value
	var events: Array = []
	var phases: Array = []
	var previous_lane := 0
	var pattern: int = index % 5
	for minute in minutes:
		state = (state * 48271) % 2147483647
		var role := "warmup" if minute == 0 else ("cooldown" if minute == minutes - 1 else ("recovery" if minute % 5 == 4 else "work"))
		var desired := 0
		if role == "work":
			match pattern:
				0: desired = [0, 1, 2, 3, 2, 1][minute % 6]
				1: desired = 1 + int(state % 3)
				2: desired = 2 + int(state % 4)
				3: desired = mini(5, (minute % 8))
				_: desired = int(state % 6)
		var lane := clampi(desired, maxi(0, previous_lane - 2), mini(5, previous_lane + 2))
		# Smoothly return to low lanes in recovery/cooldown without impossible knob jumps.
		if role != "work": lane = maxi(0, previous_lane - 2)
		var next_lane := clampi(lane + int((state / 11) % 3) - 1, 0, 5) if role == "work" else maxi(0, lane - 1)
		phases.append({"name": {"warmup": "Warm up", "work": "Main ride", "recovery": "Recovery", "cooldown": "Cool down"}[role], "role": role, "startMs": minute * 60000, "endMs": (minute + 1) * 60000})
		var burst := role == "work" and (minute % (2 if pattern == 2 else 3) == 1)
		var cadence := 65 + int(state % 5) * 5
		for part in 5:
			var spans := [[3000, 16000], [16000, 30000], [30000, 36000], [39000, 51000], [54000, 60000]]
			var kind := "cruise" if part in [0, 2, 4] else ("burst" if part == 1 and burst else "hold")
			var target_lane := lane if part < 3 else next_lane
			var event := {"eventId": "m%02d-%d" % [minute + 1, part], "type": kind, "startMs": minute * 60000 + spans[part][0], "endMs": minute * 60000 + spans[part][1], "laneIndex": target_lane}
			if kind == "hold":
				event.cadenceMin = cadence if role == "work" else 55
				event.cadenceMax = int(event.cadenceMin) + 20
			events.append(event)
		previous_lane = next_lane
	return {"schemaVersion": 1, "courseVersion": 3, "generatorVersion": 1, "courseId": id,
		"title": "Random / %06d" % (seed_value % 1000000) if random_track else NAMES[index],
		"family": "random" if random_track else "catalog", "durationMs": minutes * 60000,
		"theme": THEMES[(seed_value / 97) % 8] if random_track else THEMES[index % 8],
		"background": BACKGROUNDS[(seed_value / 193) % 4] if random_track else BACKGROUNDS[(index / 3) % 4],
		"distanceBased": true, "maxSpeedKph": 60, "maxCadenceRpm": 140, "roadLengthMeters": minutes * 1000 + 300, "seed": seed_value, "description": PATTERNS[pattern], "phases": phases, "events": events}
