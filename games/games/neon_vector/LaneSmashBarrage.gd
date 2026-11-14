class_name LaneSmashBarrage
extends RefCounted
## Pure active-time attacks. Locked targets never read render frames or chase a rider.
const DURATION_MS := 35000
const LOCK_OFFSETS := [6000, 21000]
const CHARGE_MS := 2000
const WARNING_MS := 11000
const HALF_LENGTH := 20.0
const RIDER_RADIUS := 1.5
const POINTS := 100
const SCREEN_SLOTS := [Vector2(0.23, 0.43), Vector2(0.80, 0.43), Vector2(0.37, 0.32), Vector2(0.65, 0.32), Vector2(0.18, 0.50), Vector2(0.82, 0.50)]
var schedule: Array = []
var shots: Array[Dictionary] = []
var cursor := 0
var active := false
var section: Dictionary = {}
var _cadence: Array[float] = []
var _cadence_sum := 0.0
var _next_shot := 0

static func generate(duration: int, seed_value: int) -> Array:
	var result: Array = []
	var state := seed_value
	for index in 10:
		state = (state * 48271) % 2147483647
		var start := 75000 + index * 180000 + (int(state % 17) - 8) * 1000
		if start + DURATION_MS > duration - 60000: break
		var first := int(state % SCREEN_SLOTS.size())
		var second := (first + 1 + int(state % 3)) % SCREEN_SLOTS.size()
		result.append({"barrageId": "barrage-%02d" % index, "startMs": start, "endMs": start + DURATION_MS, "slots": [first, second]})
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
		last_end = int(row.endMs)
	return true

func configure(course: Dictionary) -> void:
	schedule = course.get("barrages", [])
	shots.clear()
	cursor = 0
	active = false
	section = {}
	_cadence.clear()
	_cadence_sum = 0
	_next_shot = 0

static func target_cadence(baseline: float, ordinal: int) -> int:
	if baseline < 80 or (baseline <= 85 and ordinal % 2 == 0): return clampi(roundi(baseline + 40), 70, 120)
	return clampi(roundi(baseline - 40), 45, 100)

func update(rules: RefCounted) -> void:
	if schedule.is_empty(): return
	var now: int = rules.elapsed_ms + NeonRules.TICK
	var rpm := clampf(float(rules.latest.cadence), 0, NeonRules.MAX_CADENCE)
	_cadence.append(rpm)
	_cadence_sum += rpm
	if _cadence.size() > 200: _cadence_sum -= _cadence.pop_front()
	while cursor < schedule.size() and now >= int(schedule[cursor].endMs):
		cursor += 1
		_next_shot = 0
	active = cursor < schedule.size() and now >= int(schedule[cursor].startMs)
	section = schedule[cursor] if active else {}
	if not active: return
	while _next_shot < LOCK_OFFSETS.size() and now >= int(section.startMs) + int(LOCK_OFFSETS[_next_shot]):
		var baseline := _cadence_sum / _cadence.size()
		var target := target_cadence(baseline, cursor + _next_shot)
		var lock_ms := int(section.startMs) + int(LOCK_OFFSETS[_next_shot])
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
		if bool(shot.resolved) or now < int(shot.impactMs): continue
		shot.resolved = true
		shot.impactRiderMeters = rules.road_distance()
		shot.hit = absf(float(shot.impactRiderMeters) - float(shot.targetMeters)) <= HALF_LENGTH + RIDER_RADIUS
		rules.max_base_units += POINTS * NeonRules.UNIT
		rules.max_units += POINTS * NeonRules.UNIT
		if bool(shot.hit):
			shot.points = -rules.lose_points(POINTS)
		else:
			shot.points = POINTS
			rules.score_units += POINTS * NeonRules.UNIT
			rules.base_units += POINTS * NeonRules.UNIT

func current_shot() -> Dictionary:
	if not active or shots.is_empty(): return {}
	var shot: Dictionary = shots[-1]
	return shot if shot.sectionId == section.barrageId else {}

func normal_alpha(now: int) -> float:
	if cursor > 0 and now < int(schedule[cursor - 1].endMs) + 300:
		return smoothstep(float(schedule[cursor - 1].endMs) - 400.0, float(schedule[cursor - 1].endMs) + 300.0, now)
	if cursor >= schedule.size(): return 1.0
	var row: Dictionary = schedule[cursor]
	return 1.0 - smoothstep(float(row.startMs) - 700.0, float(row.startMs) + 300.0, now) * (1.0 - smoothstep(float(row.endMs) - 400.0, float(row.endMs) + 300.0, now))

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
