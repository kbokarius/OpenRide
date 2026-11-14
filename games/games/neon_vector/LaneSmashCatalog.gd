class_name LaneSmashCatalog
extends RefCounted
## Generator v5 (layout). Course version 8 adds machine-gun fire to cadence sections
## (scoring 7). IDs fully describe reproducible content; snapshots preserve replays.
##
## v5 is the workout pass: cadence targets follow the kind of effort instead of rising with
## the lane, cadence sections are longer, the hardest minute has two power bursts, and the
## recovery minute really drops to the lightest lanes.
const LENGTHS := [10, 15, 20, 30]
const NAMES := ["Nightfall", "Vector Run", "Cold Circuit", "Apex Protocol", "Iron Horizon", "Deep Current", "Solar Array", "Black Meridian", "Velocity", "Carbon Ridge", "Arc Reactor", "Zero Gravity", "Afterburn", "Steel Pulse", "Blue Shift", "Outer Ring", "Ion Storm", "Altitude", "Dark Matter", "Redline", "Titan", "Slipstream", "Overdrive", "Summit Relay", "Event Horizon"]
const PATTERNS := ["Rolling", "Cadence", "Power", "Climbing", "Mixed"]
const BACKGROUNDS := ["orbital", "citadel", "asteroid", "reactor"]
const THEMES := ["arctic", "cobalt", "copper", "titanium", "petrol", "amber", "ember", "glacier"]
## Cadence a work section asks for, by lane, lightest first. Each band is 20 rpm wide. Light
## lanes are fast spins and heavy lanes are climbs, so effort rises with the lane without
## asking for a sprint cadence against the heaviest resistance.
const WORK_CADENCE := [95, 90, 85, 80, 70, 65]
## Warm-up and recovery sections: an easy spin whatever the lane.
const EASY_CADENCE := 75
## Road-milliseconds a cadence section lasts: 10–15 real seconds across the bands above.
const HOLD_MS := 8000

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
		var routes := [[[0, 1, 2]], [[3, 4, 5], [3, 5, 4], [4, 3, 5], [4, 5, 3]], [[4, 3, 2], [3, 4, 2], [4, 2, 3]], [[1, 0, 1]]]
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
			var block_role := "warmup" if minute == 0 and block == 0 else ("recovery" if wave == 3 else "work")
			# One power burst a minute, two in the hardest minute, none while recovering: one every
			# 40 road-seconds through the work, which also keeps the validator's 30 s between
			# bursts. A burst block runs its cadence section straight into the burst: hold the
			# pace, then empty the tank.
			var burst_block := wave != 3 and (block != 1 if wave == 1 else block == 1)
			var hold_start := 4500 if burst_block else 4500 + int(state % 9) * 500
			var hold_end := hold_start + HOLD_MS
			phases.append({"name": phase_name if minute > 0 or block == 0 else "Build", "role": block_role, "startMs": begin, "endMs": begin + 20000})
			var parts := [["cruise", 1500, hold_start], ["hold", hold_start, hold_end]]
			if burst_block: parts.append(["burst", 12500, 18500])
			else: parts.append(["cruise", hold_end, 18500])
			for part in parts.size():
				var kind: String = parts[part][0]
				# Event ids keep their slot numbers: 0 lead-in, 1 cadence, 2 run-out, 3 burst.
				var slot := 3 if kind == "burst" else part
				var event := {"eventId": "m%02d-b%d-%d" % [minute + 1, block, slot], "type": kind, "startMs": begin + int(parts[part][1]), "endMs": begin + int(parts[part][2]), "laneIndex": lane}
				if kind == "hold":
					event.cadenceMin = WORK_CADENCE[lane] if block_role == "work" else EASY_CADENCE
					event.cadenceMax = int(event.cadenceMin) + 20
				events.append(event)
			previous_lane = lane
	return {"schemaVersion": 1, "courseVersion": 8, "generatorVersion": 5, "courseId": id,
		"title": "Random / %06d" % (seed_value % 1000000) if random_track else NAMES[index],
		"family": "random" if random_track else "catalog", "durationMs": minutes * 60000,
		"theme": THEMES[(seed_value / 97) % 8] if random_track else THEMES[index % 8],
		"background": BACKGROUNDS[(seed_value / 193) % 4] if random_track else BACKGROUNDS[(index / 3) % 4],
		"presentation": LaneSmashPath.generate(seed_value, minutes * 1000 + 300),
		"hazards": LaneSmashHazards.generate(events, seed_value),
		"barrages": LaneSmashBarrage.generate(minutes * 60000, seed_value),
		"distanceBased": true, "maxSpeedKph": 60, "maxCadenceRpm": 140, "roadLengthMeters": minutes * 1000 + 300, "seed": seed_value, "description": PATTERNS[index % 5], "phases": phases, "events": events}
