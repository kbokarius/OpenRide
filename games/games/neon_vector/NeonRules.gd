class_name NeonRules
extends RefCounted
## Pure rules: ordered timestamped input, 10 ms ticks, integer subpoints. No nodes or clocks.

const UNIT := 100000
const TICK := 10
const TIERS := {"beginner": 20, "intermediate": 24, "advanced": 30, "expert": 34}
const SCORING_VERSION := 1
const ENVELOPE_VERSION := 1

var course: Dictionary = {}
var tier := "intermediate"
var reference_power := 150.0
var elapsed_ms := 0
var score_units := 0
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
	var lo: int = TIERS[difficulty_id]
	if resistance < lo or resistance > lo + 41:
		return -1
	return (int(resistance) - lo) / 7


static func band(lane: int, difficulty_id: String) -> Vector2i:
	var lo: int = TIERS.get(difficulty_id, 24) + clampi(lane, 0, 5) * 7
	return Vector2i(lo, lo + 6)


func configure(data: Dictionary, difficulty_id: String, watts: float) -> Array[String]:
	var errors := NeonCourse.validate(data)
	if not TIERS.has(difficulty_id):
		errors.append("Unknown resistance difficulty")
	if not is_finite(watts) or watts < 1.0 or watts > 2000.0:
		errors.append("Reference power must be between 1 and 2000 W")
	if not errors.is_empty():
		return errors
	course = data.duplicate(true)
	tier = difficulty_id
	reference_power = watts
	elapsed_ms = 0
	score_units = 0
	base_units = 0
	max_units = NeonCourse.maximum(course)
	max_base_units = NeonCourse.maximum(course, true)
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
	for event: Dictionary in course.events:
		event_states.append({"eventId": event.eventId, "choice": -1, "scoreUnits": 0, "baseUnits": 0, "validMs": 0, "chargeIntegral": 0, "hit": false})
	_configured = true
	return errors


func comparison_key(rider_id: String) -> String:
	return JSON.stringify([rider_id, NeonCourse.fingerprint(course), tier, ENVELOPE_VERSION,
		SCORING_VERSION, reference_power], "", true, true).sha256_text()


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
			ghost_trace.append([elapsed_ms, selected_lane, score_units])
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
	if _stopped_ms >= 3000:
		pause("pedalling")
		return
	while _event_cursor < course.events.size() and int(course.events[_event_cursor].endMs) <= elapsed_ms:
		_event_cursor += 1
	if _event_cursor >= course.events.size() or settled_lane < 0 or rpm < 20:
		return
	var event: Dictionary = course.events[_event_cursor]
	if elapsed_ms < int(event.startMs):
		return
	var state: Dictionary = event_states[_event_cursor]
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
	var base_max := NeonCourse.base_units(event, choice)
	var old_score := int(state.scoreUnits)
	var old_base := int(state.baseUnits)
	match str(event.type):
		"pickup":
			state.hit = true
			state.baseUnits = base_max
			state.scoreUnits = base_max
		"hold":
			if rpm >= float(event.cadenceMin) and rpm <= float(event.cadenceMax):
				state.validMs += TICK
				state.baseUnits = base_max * int(state.validMs) / (int(event.endMs) - int(event.startMs))
				state.scoreUnits = state.baseUnits
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


func current_event() -> Dictionary:
	return course.events[_event_cursor] if _event_cursor < course.get("events", []).size() else {}


func result(status: String = "completed") -> Dictionary:
	var complete := status == "completed" and _configured and elapsed_ms >= int(course.durationMs)
	var stars := 0
	if complete and max_base_units > 0:
		for threshold in [25, 60, 90]:
			if base_units * 100 >= max_base_units * threshold:
				stars += 1
	return {"status": "completed" if complete else ("ended" if status == "completed" else status),
		"activeDurationMs": elapsed_ms, "scoreUnits": score_units, "maxScoreUnits": max_units,
		"baseUnits": base_units, "maxBaseUnits": max_base_units, "stars": stars,
		"events": event_states.duplicate(true), "courseId": course.get("courseId", ""),
		"courseVersion": course.get("courseVersion", 1), "courseHash": NeonCourse.fingerprint(course),
		"difficulty": tier, "referencePower": reference_power, "scoringVersion": SCORING_VERSION,
		"envelopeVersion": ENVELOPE_VERSION, "laneBands": range(6).map(func(lane: int): var limits := band(lane, tier); return [limits.x, limits.y]), "title": course.get("title", "")}
