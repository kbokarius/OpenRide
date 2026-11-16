class_name LaneSmashBarrage
extends RefCounted
## Pure active-time attacks. Locked targets never read render frames or chase a rider.
const DURATION_MS := 35000
const LOCK_OFFSETS := [6000, 21000]
const CHARGE_MS := 2000
const PREPARE_MS := 9000
const RAPID_DROP_MS := 450
const GATED_LOCK_OFFSETS := [-2000, 16000]
const WARNING_MS := 11000
const HALF_LENGTH := 20.0
const RIDER_RADIUS := 1.5
const POINTS := 100
const SCREEN_SLOTS := [Vector2(0.23, 0.43), Vector2(0.80, 0.43), Vector2(0.37, 0.32), Vector2(0.65, 0.32), Vector2(0.18, 0.50), Vector2(0.82, 0.50)]
var schedule: Array = []
var shots: Array[Dictionary] = []
var cursor := 0
var active := false
## Keep the completed lane during its final-marker fade; do not announce a skipped section.
var completing_section := false
var section: Dictionary = {}
var _cadence: Array[float] = []
var _cadence_sum := 0.0
var _next_shot := 0

static func generate(duration: int, seed_value: int, lane_checked := false) -> Array:
	var result: Array = []
	var state := seed_value
	var previous_lane := -1
	for index in 10:
		state = (state * 48271) % 2147483647
		var start := 75000 + index * 180000 + (int(state % 17) - 8) * 1000
		if start + DURATION_MS > duration - 60000: break
		var first := int(state % SCREEN_SLOTS.size())
		var second := (first + 1 + int(state % 3)) % SCREEN_SLOTS.size()
		var row := {"barrageId": "barrage-%02d" % index, "startMs": start, "endMs": start + DURATION_MS, "slots": [first, second]}
		if lane_checked:
			var lane := 2 + int(state % 4)
			if lane == previous_lane: lane = 2 + ((lane - 2 + 1) % 4)
			row.laneIndex = lane
			row.prepareMs = start - PREPARE_MS
			previous_lane = lane
		result.append(row)
	return result

static func valid(data: Variant, duration: int) -> bool:
	if not data is Array or data.size() > 10: return false
	var last_end := -60000
	var ids := {}
	for row: Variant in data:
		if not row is Dictionary or not row.get("barrageId") is String: return false
		if str(row.barrageId).is_empty() or ids.has(row.barrageId): return false
		ids[row.barrageId] = true
		if not NeonCourse._integer(row.get("startMs")) or not NeonCourse._integer(row.get("endMs")): return false
		if int(row.startMs) < 60000 or int(row.startMs) % 10 != 0 or int(row.endMs) - int(row.startMs) != DURATION_MS: return false
		if int(row.startMs) - last_end < 60000 or int(row.endMs) > duration - 60000: return false
		if not row.get("slots") is Array or row.slots.size() != 2: return false
		for slot: Variant in row.slots:
			if not NeonCourse._integer(slot) or int(slot) not in range(SCREEN_SLOTS.size()): return false
		if int(row.slots[0]) == int(row.slots[1]): return false
		if row.has("laneIndex") or row.has("prepareMs"):
			if not NeonCourse._integer(row.get("laneIndex")) or int(row.laneIndex) not in range(2, 6): return false
			if not NeonCourse._integer(row.get("prepareMs")) or int(row.prepareMs) != int(row.startMs) - PREPARE_MS: return false
		last_end = int(row.endMs)
	return true

func configure(course: Dictionary) -> void:
	schedule = course.get("barrages", []).duplicate(true)
	shots.clear()
	cursor = 0
	active = false
	completing_section = false
	section = {}
	_cadence.clear()
	_cadence_sum = 0
	_next_shot = 0

static func target_cadence(baseline: float, ordinal: int) -> int:
	if baseline < 80 or (baseline <= 85 and ordinal % 2 == 0): return clampi(roundi(baseline + 40), 70, 120)
	return clampi(roundi(baseline - 40), 45, 100)

func update(rules: RefCounted) -> void:
	completing_section = false
	if schedule.is_empty(): return
	var now: int = rules.elapsed_ms + NeonRules.TICK
	var rpm := clampf(float(rules.latest.cadence), 0, NeonRules.MAX_CADENCE)
	_cadence.append(rpm)
	_cadence_sum += rpm
	if _cadence.size() > 200: _cadence_sum -= _cadence.pop_front()
	if rules.scoring_version >= 10 and active and _next_shot == 2:
		var last := current_shot()
		if not last.is_empty() and bool(last.resolved) and now >= int(last.impactMs) + 1200:
			# Return when the final explosion fades, rather than eight empty seconds later.
			schedule[cursor].endMs = now
	if rules.scoring_version >= 10 and not active and cursor < schedule.size():
		var row: Dictionary = schedule[cursor]
		var event: Dictionary = rules.current_event()
		var position: int = rules.road_time_ms()
		if now >= int(row.prepareMs) - 700 and not event.is_empty() and position < int(event.endMs) and (rules.scoring_version >= 11 or position >= int(event.startMs)):
			# Finish the last marker before switching to incoming fire. No tiny section
			# fragments when a fixed attack time happens to land just after its start.
			# From scoring 11 this includes the approach: the highlighted lane is already
			# a commitment, even before its first point arrives.
			row.waitingForSection = true
			for key in ["prepareMs", "startMs", "endMs"]: row[key] = int(row[key]) + NeonRules.TICK
			if int(row.endMs) > int(rules.course.durationMs) - 60000:
				row.cancelled = true
				cursor += 1  # leave the final minute for the cooldown
		elif row.get("waitingForSection", false):
			# Give the final marker its contact/recap, then fade the road naturally before
			# preparation. Continually postponing a fade must not dim the entire section.
			row.waitingForSection = false
			if rules.scoring_version >= 11: row.handoff = true
		if rules.scoring_version >= 11 and row.get("handoff", false):
			completing_section = now < int(row.prepareMs)
	while cursor < schedule.size() and now >= int(schedule[cursor].endMs):
		cursor += 1
		_next_shot = 0
	active = cursor < schedule.size() and now >= int(schedule[cursor].get("prepareMs", schedule[cursor].startMs))
	if active and section.get("barrageId", "") != schedule[cursor].barrageId:
		section = schedule[cursor].duplicate(true)
		if section.has("laneIndex"):
			# Clamp the first attack after a slow warm-up to a reachable work lane.
			section.laneIndex = clampi(int(section.laneIndex), maxi(2, rules.last_target_lane - 3), mini(5, rules.last_target_lane + 3))
	elif not active:
		section = {}
	if not active: return
	var offsets: Array = GATED_LOCK_OFFSETS if section.has("laneIndex") else LOCK_OFFSETS
	while _next_shot < offsets.size() and now >= int(section.startMs) + int(offsets[_next_shot]):
		var baseline := _cadence_sum / _cadence.size()
		var target := target_cadence(baseline, cursor + _next_shot)
		var lock_ms := int(section.startMs) + int(offsets[_next_shot])
		var distance: float = rules.road_distance()
		shots.append({"shotId": "%s-%d" % [section.barrageId, _next_shot], "sectionId": section.barrageId,
			"lockMs": lock_ms, "fireMs": lock_ms + CHARGE_MS, "impactMs": lock_ms + WARNING_MS,
			"baselineRpm": baseline, "targetRpm": target, "direction": "faster" if target > baseline else "slower",
			"targetMeters": distance + baseline / NeonRules.MAX_CADENCE * NeonRules.MAX_SPEED_MPS * WARNING_MS / 1000.0,
			"fireRiderMeters": -1.0, "slot": int(section.slots[_next_shot]), "resolved": false, "hit": false, "points": 0, "impactRiderMeters": 0.0})
		_next_shot += 1
	# At most two pending shots. Completed records never re-enter collision checks.
	for i in range(maxi(0, shots.size() - 2), shots.size()):
		var shot: Dictionary = shots[i]
		if float(shot.fireRiderMeters) < 0 and now >= int(shot.fireMs): shot.fireRiderMeters = rules.road_distance()
		if rules.scoring_version >= 10 and now >= int(shot.impactMs) and not shot.get("impactRecorded", false):
			shot.impactRiderMeters = rules.road_distance()
			shot.impactRecorded = true
		if bool(shot.resolved): continue
		if rules.scoring_version >= 9 and section.has("laneIndex") and now >= int(shot.fireMs) and now < int(shot.impactMs) and not shot.get("rapid", false):
			var entering := now == int(shot.fireMs)
			var in_zone := absf(rules.road_distance() - float(shot.targetMeters)) <= HALF_LENGTH + RIDER_RADIUS
			if (entering or in_zone) and rules.selected_lane != target_lane():
				shot.rapid = true
				shot.rapidMs = now
				shot.rapidLaneIndex = NeonRules.clamped_lane_for(float(rules.latest.resistance), rules.tier)
				shot.rapidProgress = flight_progress(float(now - int(shot.fireMs)) / (int(shot.impactMs) - int(shot.fireMs)))
				shot.originalTargetMeters = shot.targetMeters
				# Lock a short strike at the rider's predicted position. A later lane change
				# cannot undo entering the marked zone incorrectly; one penalty per shot.
				var remaining := mini(RAPID_DROP_MS, int(shot.impactMs) - now)
				shot.targetMeters = rules.road_distance() + rules.speed_kph / 3.6 * remaining / 1000.0
				shot.impactMs = now + remaining
		var cleared: bool = rules.scoring_version >= 10 and now >= int(shot.fireMs) and not shot.get("rapid", false) and rules.road_distance() > float(shot.targetMeters) + HALF_LENGTH + RIDER_RADIUS
		if now < int(shot.impactMs) and not cleared: continue
		shot.resolved = true
		if rules.scoring_version >= 10:
			shot.resolvedMs = now
			shot.resolvedRiderMeters = rules.road_distance()
		else: shot.impactRiderMeters = rules.road_distance()
		shot.hit = not cleared and (bool(shot.get("rapid", false)) or absf(rules.road_distance() - float(shot.targetMeters)) <= HALF_LENGTH + RIDER_RADIUS)
		var points: int = POINTS * rules.score_scale
		rules.max_base_units += points * NeonRules.UNIT
		rules.max_units += points * NeonRules.UNIT
		if bool(shot.hit):
			shot.points = -rules.lose_points(points)
			shot.outcome = "hit"
		else:
			var passed: bool = rules.road_distance() > float(shot.targetMeters)
			shot.outcome = "passed" if passed else "held_back"
			shot.points = points if passed or rules.scoring_version < 6 else 0
			rules.score_units += int(shot.points) * NeonRules.UNIT
			# Stars measure successful avoidance; the points reward only passing in v6.
			rules.base_units += points * NeonRules.UNIT

func current_shot() -> Dictionary:
	if not active or shots.is_empty(): return {}
	var shot: Dictionary = shots[-1]
	return shot if shot.sectionId == section.barrageId else {}

func normal_alpha(now: int) -> float:
	if cursor > 0 and not schedule[cursor - 1].get("cancelled", false) and now < int(schedule[cursor - 1].endMs) + 300:
		return smoothstep(float(schedule[cursor - 1].endMs) - 400.0, float(schedule[cursor - 1].endMs) + 300.0, now)
	if cursor >= schedule.size(): return 1.0
	var row: Dictionary = schedule[cursor]
	if row.get("waitingForSection", false): return 1.0
	var start := int(row.get("prepareMs", row.startMs))
	return 1.0 - smoothstep(float(start) - 700.0, float(start) + 300.0, now) * (1.0 - smoothstep(float(row.endMs) - 400.0, float(row.endMs) + 300.0, now))

func projected_offset(rules: RefCounted) -> float:
	var shot := current_shot()
	if shot.is_empty(): return 0.0
	var seconds := maxf(0, (int(shot.impactMs) - int(rules.elapsed_ms)) / 1000.0)
	return float(rules.road_distance()) + float(rules.speed_kph) / 3.6 * seconds - float(shot.targetMeters)

func result() -> Dictionary:
	var hits := 0
	var dodges := 0
	for shot: Dictionary in shots:
		if not bool(shot.resolved): continue
		if bool(shot.hit): hits += 1
		else: dodges += 1
	return {"hits": hits, "dodges": dodges, "shots": shots.duplicate(true)}


func target_lane() -> int:
	return int(section.get("laneIndex", 0)) if active else -1


static func flight_progress(phase: float) -> float:
	var t := clampf(phase, 0.0, 1.0)
	return t + 1.2 * t * (1.0 - t) * (1.0 - t)
