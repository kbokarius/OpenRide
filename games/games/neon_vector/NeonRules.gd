class_name NeonRules
extends RefCounted
## Pure rules: ordered timestamped input, 10 ms ticks, integer subpoints. No nodes or clocks.

const UNIT := 100000
const TICK := 10
# Kid is our low-resistance option; the five adult ranges match the published Bike levels.
# Historical keys remain immutable for saved ride comparison.
const CURRENT_TIERS := {"kid": 0, "light": 15, "moderate": 20, "hard": 25, "challenging": 30, "extreme": 35}
const TIERS := {"kid": 0, "light": 15, "moderate": 20, "hard": 25, "challenging": 30, "extreme": 35,
	"beginner": 20, "intermediate": 24, "advanced": 30, "expert": 34}
const LANE_STEP := 7.0
const KID_LANE_STEP := LANE_STEP * 0.5
const SCORING_VERSION := 10
const CURRENT_SCORE_SCALE := 18
## Machine-gun fire over cadence sections (scoring version 7). Attackers strafe the road ahead
## of and behind the rider; holding the section's cadence band keeps the rider in the gap.
## Outside the band the fire closes in and rounds land, each costing whole points.
const GUN_GRACE_MS := 2000        ## after a cadence section begins, before any round can land
const GUN_FIRST_HIT_MS := 600     ## time outside the band before the first round lands
const GUN_HIT_INTERVAL_MS := 500  ## then one round every half second while still outside
const GUN_HIT_POINTS := 60        ## whole points lost per round; the score never goes below zero
const GUN_MAX_HITS := 15          ## rounds that can land in one section, so a stop cannot drain a ride
## The cadence sweet spot (scoring version 8). Riding within this many rpm of the middle of a
## cadence section's band earns a bonus on top of the section's points, as a share of them.
## It never counts toward stars: those rate hitting the band, and the bonus rewards precision.
const SWEET_HALF_RPM := 3.0
const SWEET_BONUS_PERCENT := 20
var score_scale := 1
const MAX_SPEED_MPS := 60.0 / 3.6
const MAX_CADENCE := 140.0
var distance_units := 0 # micrometres, integer integration independent of render rate
var distance_based := false
var speed_kph := 0.0
var _distance_remainder := 0.0
var scoring_version := 1
const ENVELOPE_VERSION := 1

var course: Dictionary = {}
## Realized play layout; course remains immutable for hashes and replay comparisons.
var events: Array = []
var cooldown := false
var last_target_lane := 0
var tier := "challenging"
var reference_power := 150.0
var elapsed_ms := 0
var score_units := 0
var barrage := LaneSmashBarrage.new()
var penalty_units := 0
var gun_hits := 0            ## rounds that have hit the rider this ride
var gun_penalty_units := 0   ## their share of penalty_units
var sweet_bonus_units := 0   ## points earned in cadence sweet spots this ride (part of score_units)
var _gun_event := -1         ## the cadence section under fire on this tick, or -1
var hazard_states: Array[Dictionary] = []
var hazards: Array = []
var _hazard_cursor := 0
var base_units := 0
var max_units := 0
var max_base_units := 0
var selected_lane := -1
var settled_lane := -1
var pause_reason := ""
var event_states: Array[Dictionary] = []
var ghost_trace: Array = []
var latest: Dictionary = {}
var smoothed_power := 0.0
var _samples: Array[Dictionary] = []
var _sample_cursor := 0
var _last_sequence := -1
var _last_timestamp := -1
var _candidate_since := 0
var _stopped_ms := 0
var _power: Array[float] = []
var _power_sum := 0.0
var _event_cursor := 0
var _configured := false


static func lane_for(resistance: float, difficulty_id: String) -> int:
	if not TIERS.has(difficulty_id) or not is_finite(resistance) or resistance != floorf(resistance):
		return -1
	if resistance < band(0, difficulty_id).x or resistance > band(5, difficulty_id).y:
		return -1
	return clamped_lane_for(resistance, difficulty_id)


static func lane_step(difficulty_id: String) -> float:
	return KID_LANE_STEP if difficulty_id == "kid" else LANE_STEP


## Presentation / rapid-hit placement only: clamp an out-of-range reading to the road.
## Scoring must use lane_for so invalid, fractional and out-of-range input cannot earn points.
static func clamped_lane_for(resistance: float, difficulty_id: String) -> int:
	if not is_finite(resistance): return 2
	return clampi(floori((resistance - TIERS.get(difficulty_id, 24)) / lane_step(difficulty_id)), 0, 5)


static func band(lane: int, difficulty_id: String) -> Vector2i:
	var start: int = TIERS.get(difficulty_id, 24)
	var index := clampi(lane, 0, 5)
	var step := lane_step(difficulty_id)
	# Whole-number sensors split the 3.5-wide Kid bands into alternating four/three values.
	return Vector2i(start + ceili(index * step), start + ceili((index + 1) * step) - 1)


static func band_center(lane: int, difficulty_id: String) -> int:
	var limits := band(lane, difficulty_id)
	return (limits.x + limits.y) / 2


func configure(data: Dictionary, difficulty_id: String, watts: float) -> Array[String]:
	_configured = false
	var errors := NeonCourse.validate(data)
	if not TIERS.has(difficulty_id):
		errors.append("Unknown resistance difficulty")
	if not is_finite(watts) or watts < 1.0 or watts > 2000.0:
		errors.append("Reference power must be between 1 and 2000 W")
	if not errors.is_empty():
		return errors
	course = data.duplicate(true)
	events = course.events.duplicate(true)
	cooldown = false
	last_target_lane = 0
	barrage.configure(course)
	tier = difficulty_id
	reference_power = watts
	elapsed_ms = 0
	distance_units = 0
	_distance_remainder = 0.0
	speed_kph = 0
	distance_based = bool(course.get("distanceBased", false))
	score_units = 0
	penalty_units = 0
	gun_hits = 0
	gun_penalty_units = 0
	sweet_bonus_units = 0
	_gun_event = -1
	_hazard_cursor = 0
	hazard_states.clear()
	hazards = course.get("hazards", []).duplicate(true)
	for hazard: Dictionary in hazards:
		hazard_states.append({"hit": false, "resolved": false, "penaltyUnits": 0})
	base_units = 0
	score_scale = CURRENT_SCORE_SCALE if int(course.courseVersion) >= 7 else 1
	# Course version selects the rules: 11 adds immediate passes/full-section flow (10),
	# 10 adds lane-checked bombs/cooldown (9),
	# 9 adds the cadence sweet spot (8), 8 machine-gun
	# fire (7), 7 the 18x scale (6); older snapshots keep the rules they were ridden under.
	var version := int(course.courseVersion)
	if distance_based:
		scoring_version = SCORING_VERSION if version >= 11 else (9 if version == 10 else (8 if version == 9 else (7 if version == 8 else (6 if version == 7 else (5 if version >= 6 else (4 if version >= 5 else 3))))))
	else:
		scoring_version = 1 if version == 1 else 2
	max_units = NeonCourse.maximum(course, false, reference_power)
	max_base_units = NeonCourse.maximum(course, true, reference_power)
	if distance_based:
		max_units = 0
		max_base_units = 0
	selected_lane = -1
	settled_lane = -1
	pause_reason = ""
	_samples.clear()
	_sample_cursor = 0
	_last_sequence = -1
	_last_timestamp = -1
	_candidate_since = 0
	_stopped_ms = 0
	_event_cursor = 0
	latest = {}
	_clear_power()
	ghost_trace.clear()
	event_states.clear()
	for event: Dictionary in events:
		var state := {"eventId": event.eventId, "choice": -1, "scoreUnits": 0, "baseUnits": 0, "validMs": 0, "chargeIntegral": 0, "energyMilliJoules": 0, "validTravelUnits": 0, "possibleTravelUnits": 0, "possibleMs": 0, "possibleBaseUnits": 0, "hit": false}
		# Only new-scoring cadence sections carry gunfire state; older snapshots stay byte-identical.
		if scoring_version >= 7 and event.type == "hold":
			state.merge({"gunMs": 0, "gunExposedMs": 0, "gunNextHitMs": GUN_FIRST_HIT_MS, "gunHits": 0, "gunPenaltyUnits": 0})
		if scoring_version >= 8 and event.type == "hold":
			state.merge({"sweetTravelUnits": 0, "bonusUnits": 0})
		event_states.append(state)
	_configured = true
	return errors


func comparison_key(rider_id: String) -> String:
	return JSON.stringify([rider_id, NeonCourse.fingerprint(course), tier, ENVELOPE_VERSION,
		scoring_version, reference_power], "", true, true).sha256_text()


func push_sample(sample: Dictionary) -> bool:
	if not _configured or not sample.has_all(["t", "seq", "cadence", "power", "resistance"]):
		return false
	for key in ["t", "seq", "cadence", "power", "resistance"]:
		if not (sample[key] is int or sample[key] is float) or not is_finite(float(sample[key])):
			pause("sensor")
			return false
	var timestamp := int(sample.t)
	var sequence := int(sample.seq)
	if sequence <= _last_sequence:
		return false  # duplicate reads never renew freshness
	if timestamp < _last_timestamp or timestamp < elapsed_ms:
		pause("input_order")
		return false
	if float(sample.cadence) < 0 or float(sample.cadence) > 250 or float(sample.power) < 0 or float(sample.power) > 5000 or float(sample.resistance) < 0 or float(sample.resistance) > 100:
		pause("sensor")
		return false
	_last_sequence = sequence
	_last_timestamp = timestamp
	_samples.append(sample.duplicate())
	return true


func advance(target_ms: int) -> void:
	if not _configured or not pause_reason.is_empty():
		return
	var end := mini(int(course.durationMs), target_ms - posmod(target_ms, TICK))
	while elapsed_ms < end:
		while _sample_cursor < _samples.size() and int(_samples[_sample_cursor].t) <= elapsed_ms:
			latest = _samples[_sample_cursor]
			_sample_cursor += 1
		if latest.is_empty() or elapsed_ms - int(latest.t) > 1500:
			pause("sensor")
			break
		_tick()
		elapsed_ms += TICK
		if elapsed_ms % 100 == 0:
			ghost_trace.append([elapsed_ms, selected_lane, score_units, distance_units / 1000] if distance_based else [elapsed_ms, selected_lane, score_units])
		if not pause_reason.is_empty():
			break
	# Bound memory without changing sequence/timestamp validation.
	if _sample_cursor > 128:
		_samples = _samples.slice(_sample_cursor)
		_sample_cursor = 0


func pause(reason: String = "manual") -> void:
	pause_reason = reason
	settled_lane = -1
	selected_lane = -1
	_clear_power()


func resume() -> void:
	# Caller must establish 1 s of new samples and a 3 s countdown first. Old buffered input
	# cannot leak into the resumed course; its first fresh sample starts at elapsed_ms.
	pause_reason = ""
	_samples.clear()
	_sample_cursor = 0
	latest = {}
	_last_timestamp = elapsed_ms - 1
	_stopped_ms = 0
	selected_lane = -1
	settled_lane = -1
	_candidate_since = elapsed_ms
	_clear_power()


func _clear_power() -> void:
	_power.clear()
	_power_sum = 0.0
	smoothed_power = 0.0


func _tick() -> void:
	var lane := lane_for(float(latest.resistance), tier)
	if lane != selected_lane:
		selected_lane = lane
		_candidate_since = elapsed_ms
		settled_lane = -1
	elif lane >= 0 and elapsed_ms - _candidate_since >= 150:
		settled_lane = lane
	var rpm := float(latest.cadence)
	_stopped_ms = _stopped_ms + TICK if rpm < 20 else 0
	_power.append(float(latest.power))
	_power_sum += float(latest.power)
	if _power.size() > 100:
		_power_sum -= _power.pop_front()
	smoothed_power = _power_sum / _power.size()
	if _stopped_ms >= 3000 and not distance_based:
		pause("pedalling")
		return
	var travel_step := 0
	if distance_based:
		speed_kph = clampf(rpm / MAX_CADENCE * 60.0, 0, 60)
		var exact_travel := speed_kph / 3.6 * TICK * 1000 + _distance_remainder
		travel_step = floori(exact_travel)
		_distance_remainder = exact_travel - travel_step
		distance_units += travel_step
	if scoring_version >= 9 and not cooldown and elapsed_ms + TICK >= int(course.durationMs) - 60000:
		_begin_cooldown()
	var was_attacking := barrage.active
	barrage.update(self)
	if scoring_version >= 10 and was_attacking and not barrage.active:
		_restart_after_barrage()
	elif scoring_version >= 9 and was_attacking and not barrage.active:
		# A time-based attack can end in the middle of a spatial section. Skip to a full
		# section with enough empty road to turn the knob; never resume halfway through it.
		while _event_cursor < events.size():
			var next: Dictionary = events[_event_cursor]
			var gap := LaneSmashCatalog.transition_gap(absi(int(next.laneIndex) - last_target_lane))
			var ready := road_time_ms() + gap
			if int(next.startMs) >= ready: break
			var minimum := 6000 if next.type == "burst" else 3000
			if int(next.endMs) - ready >= minimum:
				# Retain a useful, clearly bounded remainder instead of adding a whole
				# extra block of empty approach, especially in the heavy/slow lanes.
				next.startMs = ready
				break
			event_states[_event_cursor]["skipped"] = true
			_event_cursor += 1
	_apply_hazards()
	_gun_event = -1
	var position_ms := road_time_ms()
	while _event_cursor < events.size() and int(events[_event_cursor].endMs) <= position_ms:
		_event_cursor += 1
	if barrage.active:
		last_target_lane = barrage.target_lane()
		return
	if _event_cursor >= events.size():
		return
	var event: Dictionary = events[_event_cursor]
	last_target_lane = int(event.laneIndex)
	if position_ms < int(event.startMs):
		return
	var state: Dictionary = event_states[_event_cursor]
	if distance_based:
		state.possibleTravelUnits += travel_step
		state.possibleMs += TICK
		var possible := roundi(reference_power) * int(state.possibleMs) * UNIT / 5000 if event.type == "burst" else _distance_credit(NeonCourse.base_units(event, {"laneIndex": event.laneIndex}, reference_power), int(state.possibleTravelUnits), roundi((int(event.endMs) - int(event.startMs)) * MAX_SPEED_MPS * 1000))
		possible *= score_scale
		max_base_units += possible - int(state.possibleBaseUnits)
		state.possibleBaseUnits = possible
		max_units = max_base_units
	if scoring_version >= 7 and event.type == "hold":
		_apply_gunfire(event, state, rpm)
	if settled_lane < 0 or rpm < 20:
		return
	var options := NeonCourse.choices(event)
	if int(state.choice) < 0:
		for i in options.size():
			if int(options[i].laneIndex) == settled_lane:
				state.choice = i
				break
	if int(state.choice) < 0:
		return
	var choice: Dictionary = options[int(state.choice)]
	if int(choice.laneIndex) != settled_lane:
		return
	var base_max := NeonCourse.base_units(event, choice, reference_power) * score_scale
	var old_score := int(state.scoreUnits)
	var old_base := int(state.baseUnits)
	match str(event.type):
		"pickup":
			state.hit = true
			state.baseUnits = base_max
			state.scoreUnits = base_max
		"cruise":
			state.validMs += TICK
			state.baseUnits = _section_credit(state, event, base_max, travel_step)
			state.scoreUnits = state.baseUnits
		"burst":
			state.validMs += TICK
			state.energyMilliJoules += roundi(float(latest.power)) * TICK
			state.scoreUnits = int(state.energyMilliJoules) * UNIT / 5000 * int(choice.get("rewardPercent", 100)) / 100 * score_scale
			state.baseUnits = mini(roundi(reference_power) * int(state.validMs) * UNIT / 5000 * score_scale if distance_based else base_max, int(state.scoreUnits))
		"hold":
			if rpm >= float(event.cadenceMin) and rpm <= float(event.cadenceMax):
				state.validMs += TICK
				state.baseUnits = _section_credit(state, event, base_max, travel_step)
				state.scoreUnits = state.baseUnits
				if scoring_version >= 8:
					# The sweet spot: the same distance credit again, at a fifth of the rate, for
					# the road covered within a few rpm of the middle of the band.
					var sweet := sweet_spot(event)
					if rpm >= sweet.x and rpm <= sweet.y: state.sweetTravelUnits += travel_step
					var length_units := roundi((int(event.endMs) - int(event.startMs)) * MAX_SPEED_MPS * 1000)
					var bonus := mini(base_max, _distance_credit(base_max, int(state.sweetTravelUnits), length_units)) * SWEET_BONUS_PERCENT / 100
					sweet_bonus_units += bonus - int(state.bonusUnits)
					state.bonusUnits = bonus
					state.scoreUnits = int(state.baseUnits) + bonus
		"charge":
			if rpm <= 120:
				var p100 := 0.6 * reference_power
				var q := smoothed_power / p100 if smoothed_power < p100 else 1.0 + (smoothed_power - p100) / (reference_power - p100)
				state.chargeIntegral += roundi(clampf(q, 0.0, 2.0) * UNIT) * TICK
				state.validMs += TICK
				var duration := int(event.endMs) - int(event.startMs)
				var integral := mini(int(state.chargeIntegral), 2 * UNIT * duration)
				state.baseUnits = base_max * mini(integral, UNIT * duration) / (UNIT * duration)
				state.scoreUnits = int(state.baseUnits) + base_max * maxi(0, integral - UNIT * duration) / (2 * UNIT * duration)
	base_units += int(state.baseUnits) - old_base
	score_units += int(state.scoreUnits) - old_score


## One tick of machine-gun fire over an active cadence section. Lane does not matter: the fire
## rakes the whole road, and only cadence keeps the rider in the gap. Exposure builds while the
## rider is outside the band and drains twice as fast once back inside, so brushing the edge is
## forgiven but riding outside it is not.
func _apply_gunfire(event: Dictionary, state: Dictionary, rpm: float) -> void:
	_gun_event = _event_cursor
	state.gunMs += TICK
	if int(state.gunMs) <= GUN_GRACE_MS or int(state.gunHits) >= GUN_MAX_HITS:
		return
	if rpm >= float(event.cadenceMin) and rpm <= float(event.cadenceMax):
		state.gunExposedMs = maxi(0, int(state.gunExposedMs) - TICK * 2)
		if int(state.gunExposedMs) == 0: state.gunNextHitMs = GUN_FIRST_HIT_MS
		return
	state.gunExposedMs += TICK
	if int(state.gunExposedMs) < int(state.gunNextHitMs):
		return
	state.gunNextHitMs += GUN_HIT_INTERVAL_MS
	state.gunHits += 1
	gun_hits += 1
	var loss := lose_points(GUN_HIT_POINTS) * UNIT
	state.gunPenaltyUnits += loss
	gun_penalty_units += loss


## The machine-gun fire over the rider right now, for presentation and sound; empty when no
## cadence section is under fire. Reading it never changes the rules.
func gunfire() -> Dictionary:
	if _gun_event < 0 or _gun_event >= events.size() or not pause_reason.is_empty():
		return {}
	var event: Dictionary = events[_gun_event]
	var state: Dictionary = event_states[_gun_event]
	var rpm := float(latest.get("cadence", 0))
	return {"eventId": event.eventId, "cadenceMin": int(event.cadenceMin), "cadenceMax": int(event.cadenceMax),
		"graceLeftMs": maxi(0, GUN_GRACE_MS - int(state.gunMs)),
		"exposed": int(state.gunMs) > GUN_GRACE_MS and (rpm < float(event.cadenceMin) or rpm > float(event.cadenceMax)),
		"exposedMs": int(state.gunExposedMs), "hits": int(state.gunHits), "spent": int(state.gunHits) >= GUN_MAX_HITS}


## The rpm range of a cadence section's sweet spot: the middle of its band, plus and minus
## SWEET_HALF_RPM.
static func sweet_spot(event: Dictionary) -> Vector2:
	var middle := (float(event.cadenceMin) + float(event.cadenceMax)) * 0.5
	return Vector2(middle - SWEET_HALF_RPM, middle + SWEET_HALF_RPM)


## The cadence section the rider is in, or the next one if it starts within `lead_ms` of road,
## for the cadence gauge; empty otherwise. `active` is false while it is still ahead. Reading
## it never changes the rules.
func cadence_target(lead_ms := 3000) -> Dictionary:
	if not _configured or barrage.active: return {}
	var now := road_time_ms()
	for index in range(_event_cursor, mini(events.size(), _event_cursor + 2)):
		var event: Dictionary = events[index]
		if event.type != "hold": continue
		if int(event.startMs) - now > lead_ms or now >= int(event.endMs): continue
		var sweet := sweet_spot(event)
		var rpm := float(latest.get("cadence", 0))
		var active := now >= int(event.startMs)
		return {"eventId": event.eventId, "laneIndex": int(event.laneIndex), "cadenceMin": int(event.cadenceMin), "cadenceMax": int(event.cadenceMax),
			"sweetMin": sweet.x, "sweetMax": sweet.y, "active": active, "rpm": rpm,
			"inBand": rpm >= float(event.cadenceMin) and rpm <= float(event.cadenceMax),
			"inSweet": scoring_version >= 8 and rpm >= sweet.x and rpm <= sweet.y,
			"bonus": scoring_version >= 8, "startsInMs": maxi(0, int(event.startMs) - now)}
	return {}


func current_event() -> Dictionary:
	return events[_event_cursor] if _event_cursor < events.size() else {}


func result(status: String = "completed") -> Dictionary:
	var complete := status == "completed" and _configured and elapsed_ms >= int(course.durationMs)
	var stars := 0
	if complete and max_base_units > 0:
		for threshold in [25, 60, 90]:
			if base_units * 100 >= max_base_units * threshold:
				stars += 1
	return {"status": "completed" if complete else ("ended" if status == "completed" else status),
		"activeDurationMs": elapsed_ms, "distanceMm": distance_units / 1000, "scoreUnits": score_units, "maxScoreUnits": max_units,
		"baseUnits": base_units, "maxBaseUnits": max_base_units, "stars": stars,
		"earnedScoreUnits": score_units + penalty_units, "penaltyUnits": penalty_units, "barrage": barrage.result(),
		"gunfire": {"hits": gun_hits, "penaltyUnits": gun_penalty_units},
		"sweetSpot": {"bonusUnits": sweet_bonus_units},
		"events": event_states.duplicate(true), "courseId": course.get("courseId", ""),
		"courseVersion": course.get("courseVersion", 1), "courseHash": NeonCourse.fingerprint(course),
		"difficulty": tier, "referencePower": reference_power, "scoringVersion": scoring_version, "scoreScale": score_scale,
		"envelopeVersion": ENVELOPE_VERSION, "laneBands": range(6).map(func(lane: int): var limits := band(lane, tier); return [limits.x, limits.y]), "title": course.get("title", "")}


func road_time_ms() -> int:
	return floori(distance_units / (MAX_SPEED_MPS * 1000.0)) if distance_based else elapsed_ms

func road_distance() -> float:
	return distance_units / 1000000.0 if distance_based else elapsed_ms / 1000.0 * 18.0

func road_speed_scale() -> float:
	return MAX_SPEED_MPS if distance_based else 18.0

func _section_credit(state: Dictionary, event: Dictionary, maximum: int, travel_step: int) -> int:
	if not distance_based:
		return maximum * int(state.validMs) / (int(event.endMs) - int(event.startMs))
	state.validTravelUnits += travel_step
	var length_units := roundi((int(event.endMs) - int(event.startMs)) * MAX_SPEED_MPS * 1000)
	return mini(maximum, _distance_credit(maximum, int(state.validTravelUnits), length_units))

func _apply_hazards() -> void:
	while _hazard_cursor < hazards.size() and road_time_ms() >= int(hazards[_hazard_cursor].hitMs):
		var hazard: Dictionary = hazards[_hazard_cursor]
		var state: Dictionary = hazard_states[_hazard_cursor]
		state.resolved = true
		if not barrage.active and not cooldown and selected_lane == int(hazard.laneIndex):
			state.hit = true
			# Whole visible points only; score never drops below zero.
			var loss := lose_points(int(hazard.penaltyPoints) * score_scale) * UNIT
			state.penaltyUnits = loss
		_hazard_cursor += 1

func lose_points(points: int) -> int:
	var loss := mini(points, maxi(0, score_units / UNIT))
	penalty_units += loss * UNIT
	score_units -= loss * UNIT
	return loss


func _distance_credit(base: int, travel: int, length: int) -> int:
	# v6's larger subpoint totals can overflow an integer intermediate on long saved sections.
	# Input integers remain authoritative; the deterministic ratio is independent of frame rate.
	return floori(float(base) * float(travel) / float(length)) if scoring_version >= 6 else base * travel / length


func _begin_cooldown() -> void:
	cooldown = true
	var at := road_time_ms()
	# Close the active section at this contact plane and keep its earned recap. Future
	# authored sections are replaced only in the runtime list, never in the saved course.
	while _event_cursor < events.size() and int(events[_event_cursor].endMs) <= at:
		_event_cursor += 1
	var keep := _event_cursor
	if keep < events.size() and int(events[keep].startMs) < at:
		events[keep].endMs = at
		event_states[keep]["closed"] = true
		keep += 1
	events.resize(keep)
	event_states.resize(keep)
	_event_cursor = keep
	var previous := last_target_lane
	# First return is never more than three lanes, then step down into lanes 1–2.
	var lane := maxi(0, previous - 3)
	for i in 10:
		var gap := LaneSmashCatalog.transition_gap(absi(lane - previous)) if lane != previous else 2000
		at += gap
		var event := {"eventId": "cooldown-%02d" % i, "type": "cruise", "startMs": at, "endMs": at + (10000 if scoring_version >= 10 else 4000), "laneIndex": lane}
		events.append(event)
		event_states.append({"eventId": event.eventId, "choice": -1, "scoreUnits": 0, "baseUnits": 0, "validMs": 0, "chargeIntegral": 0, "energyMilliJoules": 0, "validTravelUnits": 0, "possibleTravelUnits": 0, "possibleMs": 0, "possibleBaseUnits": 0, "hit": false})
		at = int(event.endMs)
		previous = lane
		lane = maxi(0, lane - 1)


func _restart_after_barrage() -> void:
	# Never resume a three-second fragment or skip an entire block's worth of road.
	# Keep a full, unplayed section and reflow its successors while the attack fades away.
	var at := road_time_ms()
	while _event_cursor < events.size():
		var event: Dictionary = events[_event_cursor]
		if int(event.endMs) > at and int(event_states[_event_cursor].possibleMs) == 0: break
		event_states[_event_cursor]["skipped"] = true
		_event_cursor += 1
	if _event_cursor >= events.size(): return
	var next: Dictionary = events[_event_cursor]
	var gap := LaneSmashCatalog.transition_gap(absi(int(next.laneIndex) - last_target_lane))
	var shift := ceili((at + gap) / 10.0) * 10 - int(next.startMs)
	for i in range(_event_cursor, events.size()):
		events[i].startMs = int(events[i].startMs) + shift
		events[i].endMs = int(events[i].endMs) + shift
	# Keep resolved contact slots for pending visual feedback; rebuild future mines,
	# keeping the target lane and every transition clear after the reflow too.
	hazards.resize(_hazard_cursor)
	hazard_states.resize(_hazard_cursor)
	for hazard: Dictionary in LaneSmashHazards.generate_dense(events.slice(_event_cursor)):
		hazard.hazardId = str(hazard.hazardId) + "-return%d" % barrage.cursor
		hazards.append(hazard)
		hazard_states.append({"hit": false, "resolved": false, "penaltyUnits": 0})
