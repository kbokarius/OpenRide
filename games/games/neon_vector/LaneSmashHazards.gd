class_name LaneSmashHazards
extends RefCounted
## Deterministic hazards leave the scoring lane clear. Distances use the course clock.
const PENALTY_POINTS := 100

static func generate(events: Array, seed_value: int) -> Array:
	var hazards: Array = []
	var last := -30000
	var state := seed_value
	for event: Dictionary in events:
		if event.type != "cruise" or int(event.startMs) < 60000 or int(event.endMs) - int(event.startMs) < 3000: continue
		var at := ((int(event.startMs) + int(event.endMs)) / 20) * 10
		if at - last < 45000: continue
		state = (state * 48271) % 2147483647
		var lane := int(event.laneIndex) + (-1 if state % 2 == 0 else 1)
		if lane < 0 or lane > 5: lane = int(event.laneIndex) + (1 if lane < 0 else -1)
		hazards.append({"hazardId": "bomb-%03d" % hazards.size(), "hitMs": at, "laneIndex": lane, "penaltyPoints": PENALTY_POINTS})
		last = at
	return hazards

static func valid(hazards: Variant, events: Array, duration: int) -> bool:
	if not hazards is Array or hazards.size() > 128: return false
	var ids := {}
	var previous := -30000
	for hazard: Variant in hazards:
		if not hazard is Dictionary or not hazard.get("hazardId") is String: return false
		if str(hazard.hazardId).is_empty() or ids.has(hazard.hazardId): return false
		ids[hazard.hazardId] = true
		for key in ["hitMs", "laneIndex", "penaltyPoints"]:
			var value: Variant = hazard.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)): return false
		var hit := int(hazard.hitMs)
		if hit < 60000 or hit >= duration or hit % 10 != 0 or hit - previous < 30000: return false
		if int(hazard.laneIndex) not in range(6) or int(hazard.penaltyPoints) != PENALTY_POINTS: return false
		var clear := false
		for event: Dictionary in events:
			if hit >= int(event.startMs) and hit < int(event.endMs):
				clear = event.type == "cruise" and int(event.laneIndex) != int(hazard.laneIndex)
				break
		if not clear: return false
		previous = hit
	return true


const DENSE_LIMIT := 4096
const FIRST_MINE_MS := 1800
const MINE_SPACING_MS := 3000
const EXIT_CLEAR_MS := 1800

static func generate_dense(events: Array) -> Array:
	var hazards: Array = []
	for event: Dictionary in events:
		if event.type not in ["cruise", "hold", "burst"]: continue
		for at in range(int(event.startMs) + FIRST_MINE_MS, int(event.endMs) - EXIT_CLEAR_MS + 1, MINE_SPACING_MS):
			for lane in 6:
				if lane == int(event.laneIndex): continue
				hazards.append({"hazardId": "%s-mine-%d-%d" % [event.eventId, at - int(event.startMs), lane], "hitMs": at, "laneIndex": lane, "penaltyPoints": PENALTY_POINTS})
	return hazards

static func valid_dense(hazards: Variant, events: Array) -> bool:
	if not hazards is Array or hazards.size() > DENSE_LIMIT: return false
	var ids := {}
	var last_time := -1
	var last_lane := -1
	var event_index := 0
	for hazard: Variant in hazards:
		if not hazard is Dictionary or not hazard.get("hazardId") is String or str(hazard.hazardId).is_empty(): return false
		if ids.has(hazard.hazardId): return false
		ids[hazard.hazardId] = true
		for key in ["hitMs", "laneIndex", "penaltyPoints"]:
			if not NeonCourse._integer(hazard.get(key)): return false
		var at := int(hazard.hitMs)
		var lane := int(hazard.laneIndex)
		if at % 10 != 0 or at < last_time or lane not in range(6) or int(hazard.penaltyPoints) != PENALTY_POINTS: return false
		if at == last_time and lane <= last_lane: return false
		while event_index < events.size() and int(events[event_index].endMs) <= at: event_index += 1
		if event_index >= events.size(): return false
		var event: Dictionary = events[event_index]
		if at < int(event.startMs) + FIRST_MINE_MS or at > int(event.endMs) - EXIT_CLEAR_MS or lane == int(event.laneIndex): return false
		if event.type not in ["cruise", "hold", "burst"]: return false
		last_time = at
		last_lane = lane
	return true
