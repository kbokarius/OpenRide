class_name LaneSmashCatalog
extends RefCounted
## Frozen generator v4. IDs fully describe reproducible content; snapshots preserve replays.
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
	var previous_lane := -1
	# Every minute has the same lane histogram for every track. Permutations vary the
	# climb/recovery shape without changing resistance exposure or target durations.
	for minute in minutes:
		state = (state * 48271) % 2147483647
		var wave := minute % 4
		var routes := [[[0, 1, 2]], [[3, 4, 5], [3, 5, 4], [4, 3, 5], [4, 5, 3]], [[4, 3, 2], [3, 4, 2], [4, 2, 3]], [[1, 2, 1]]]
		var variants: Array = routes[wave]
		var pick := int((state + index) % variants.size())
		var lanes: Array = variants[pick]
		while int(lanes[0]) == previous_lane:
			pick = (pick + 1) % variants.size()
			lanes = variants[pick]
		var phase_name := "Warm up" if minute == 0 else ("Recovery" if wave == 3 else ("Build" if wave in [0, 1] else "Ease back"))
		for block in 3:
			state = (state * 48271) % 2147483647
			var lane := int(lanes[block])
			var begin := minute * 60000 + block * 20000
			var hold_start := 4500 + int(state % 5) * 500
			var block_role := "warmup" if minute == 0 and block == 0 else ("recovery" if wave == 3 else "work")
			phases.append({"name": phase_name if minute > 0 or block == 0 else "Build", "role": block_role, "startMs": begin, "endMs": begin + 20000})
			# Six road-seconds: 6–14 real seconds across the normal 60–140 rpm range.
			var spans := [[1500, hold_start], [hold_start, hold_start + 6000], [hold_start + 6000, 12500], [12500, 18500]]
			for part in 4:
				if spans[part][0] == spans[part][1]: continue
				var kind := "hold" if part == 1 else ("burst" if part == 3 and block == 1 and wave != 3 else "cruise")
				var event := {"eventId": "m%02d-b%d-%d" % [minute + 1, block, part], "type": kind, "startMs": begin + spans[part][0], "endMs": begin + spans[part][1], "laneIndex": lane}
				if kind == "hold":
					event.cadenceMin = 60 + lane * 4
					event.cadenceMax = int(event.cadenceMin) + 20
				if not events.is_empty() and kind == "cruise" and events[-1].type == kind and events[-1].laneIndex == lane and events[-1].endMs == event.startMs:
					events[-1].endMs = event.endMs
				else:
					events.append(event)
			previous_lane = lane
	return {"schemaVersion": 1, "courseVersion": 6, "generatorVersion": 4, "courseId": id,
		"title": "Random / %06d" % (seed_value % 1000000) if random_track else NAMES[index],
		"family": "random" if random_track else "catalog", "durationMs": minutes * 60000,
		"theme": THEMES[(seed_value / 97) % 8] if random_track else THEMES[index % 8],
		"background": BACKGROUNDS[(seed_value / 193) % 4] if random_track else BACKGROUNDS[(index / 3) % 4],
		"presentation": LaneSmashPath.generate(seed_value, minutes * 1000 + 300),
		"hazards": LaneSmashHazards.generate(events, seed_value),
		"barrages": LaneSmashBarrage.generate(minutes * 60000, seed_value),
		"distanceBased": true, "maxSpeedKph": 60, "maxCadenceRpm": 140, "roadLengthMeters": minutes * 1000 + 300, "seed": seed_value, "description": PATTERNS[index % 5], "phases": phases, "events": events}
