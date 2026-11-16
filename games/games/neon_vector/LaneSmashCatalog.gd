class_name LaneSmashCatalog
extends RefCounted
## Generator v9 retains v8's full sections/cadence/mines and selects committed lane handoffs.
## Course v12 selects scoring 11, preserving every older ride snapshot and comparison key.
const LENGTHS := [10, 15, 20, 30]
const NAMES := ["Nightfall", "Vector Run", "Cold Circuit", "Apex Protocol", "Iron Horizon", "Deep Current", "Solar Array", "Black Meridian", "Velocity", "Carbon Ridge", "Arc Reactor", "Zero Gravity", "Afterburn", "Steel Pulse", "Blue Shift", "Outer Ring", "Ion Storm", "Altitude", "Dark Matter", "Redline", "Titan", "Slipstream", "Overdrive", "Summit Relay", "Event Horizon"]
const PATTERNS := ["Rolling", "Cadence", "Power", "Climbing", "Mixed"]
const BACKGROUNDS := ["orbital", "citadel", "asteroid", "reactor"]
const THEMES := ["arctic", "cobalt", "copper", "titanium", "petrol", "amber", "ember", "glacier"]
## Work targets step down every two lanes; warm-up uses an easier spin.
const WORK_CADENCE := [85, 85, 70, 70, 55, 55]
const EASY_CADENCE := 75
## Road time is measured at the speed cap: these cannot be ridden in less than ten seconds.
const HOLD_MS := 10000
const COLLECT_MS := 10000
const BURST_MS := 6000
const GAP_MIN_MS := 2000
const GAP_MAX_MS := 9000
const LANE_GAP_MIN_MS := 6000
const BLOCK_MS := 31000
const WARMUP_ROAD_MS := 29000

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
	var duration := minutes * 60000
	var work_lanes: Array = [2, 3, 4, 5]
	var begin := 0
	var block := 0
	while begin < duration:
		state = (state * 48271) % 2147483647
		if block >= 2 and (block - 2) % 4 == 0:
			work_lanes = [2, 3, 4, 5]
			for i in range(3, 0, -1):
				state = (state * 48271) % 2147483647
				var j := int(state % (i + 1))
				var value: int = work_lanes[i]
				work_lanes[i] = work_lanes[j]
				work_lanes[j] = value
			while work_lanes[0] == previous_lane or absi(int(work_lanes[0]) - previous_lane) > 3:
				work_lanes.append(work_lanes.pop_front())
		var lane := block if block < 2 else int(work_lanes[(block - 2) % 4])
		var warm := block < 2
		# Equal work-block budgets across every lane ordering, with the full allowance
		# for a three-lane adjustment and only two seconds between same-lane sections.
		var opening := 3000 if block == 0 else (6000 if warm else 9000)
		var burst_block := not warm and block % 2 == 0
		# A deterministic 5/6/7-second burst rotation, without a long gap replacing it.
		var burst_length := 5000 + ((block / 2) % 3) * 1000
		var kinds: Array = (["cruise"] if block == 0 else ["hold"]) if warm else (["hold", "burst"] if burst_block else (["cruise", "hold"] if state % 2 == 0 else ["hold", "cruise"]))
		var length_total := 10000 if warm else HOLD_MS + (burst_length if burst_block else COLLECT_MS)
		var block_length := opening + length_total + (0 if warm else 2000)
		if not warm and begin + block_length > duration: kinds = ["hold", "burst" if burst_block else "cruise"]
		var end := mini(duration, begin + block_length)
		phases.append({"name": "Warm up" if warm else ("Ease back" if lane == 2 else "Work"), "role": "warmup" if warm else "work", "startMs": begin, "endMs": end})
		var at := begin + opening
		for part in kinds.size():
			var kind: String = kinds[part]
			var length := burst_length if kind == "burst" else 10000
			if at + length > end: break  # never author a tiny remainder at the end of the road
			var event := {"eventId": "b%03d-%d" % [block, part], "type": kind, "startMs": at, "endMs": at + length, "laneIndex": lane}
			if kind == "hold":
				event.cadenceMin = EASY_CADENCE if warm else WORK_CADENCE[lane]
				event.cadenceMax = int(event.cadenceMin) + 20
			events.append(event)
			at = int(event.endMs) + 2000
		previous_lane = lane
		begin = end
		block += 1
	return {"schemaVersion": 1, "courseVersion": 12, "generatorVersion": 9, "courseId": id,
		"title": "Random / %06d" % (seed_value % 1000000) if random_track else NAMES[index],
		"family": "random" if random_track else "catalog", "durationMs": minutes * 60000,
		"theme": THEMES[(seed_value / 97) % 8] if random_track else THEMES[index % 8],
		"background": BACKGROUNDS[(seed_value / 193) % 4] if random_track else BACKGROUNDS[(index / 3) % 4],
		"presentation": LaneSmashPath.generate(seed_value, minutes * 1000 + 300),
		"hazards": LaneSmashHazards.generate_dense(events),
		"barrages": LaneSmashBarrage.generate(minutes * 60000, seed_value, true),
		"distanceBased": true, "maxSpeedKph": 60, "maxCadenceRpm": 140, "roadLengthMeters": minutes * 1000 + 300, "seed": seed_value, "description": PATTERNS[index % 5], "phases": phases, "events": events}


static func transition_gap(lanes: int) -> int:
	# At the speed cap these are actual seconds; every slower rider has longer.
	return 6000 if lanes <= 1 else (7500 if lanes == 2 else 9000)
