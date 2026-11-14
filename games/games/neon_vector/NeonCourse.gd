class_name NeonCourse
extends RefCounted
## Versioned, offline content. A branch is a choice inside one event, never two awards.

const VERSION := 1
const DIRECTORY := "res://games/neon_vector/courses/"
const FAMILIES := ["steady_flow", "intervals", "rolling_climb"]


static func library() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append(load_course("tutorial"))
	for family in FAMILIES:
		for minutes in [10, 20, 30]:
			result.append(load_course("%s_%d" % [family, minutes]))
	return result


static func load_course(id: String) -> Dictionary:
	if id.begins_with("ls_"):
		return LaneSmashCatalog.load_track(id)
	if not id.is_valid_filename():
		return {}
	var path := DIRECTORY + id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func fingerprint(course: Dictionary) -> String:
	# Visual path/opacity cannot change ride eligibility or hide previous best scores.
	# Removing only this new field preserves every pre-presentation comparison hash.
	var scoring_course := course.duplicate()
	scoring_course.erase("presentation")
	return JSON.stringify(scoring_course, "", true, true).sha256_text()


static func choices(event: Dictionary) -> Array:
	return event.get("alternatives", [{"laneIndex": event.get("laneIndex", -1), "rewardPercent": 100}])


static func base_units(event: Dictionary, choice: Dictionary, reference_power: float = 150.0) -> int:
	var base: int
	if event.type == "pickup":
		base = (100 + 20 * int(choice.laneIndex)) * 100000
	elif event.type == "burst":
		base = roundi(reference_power) * (int(event.endMs) - int(event.startMs)) * 100000 / 5000
	else:
		base = (int(event.endMs) - int(event.startMs)) * 1000
	return base * int(choice.get("rewardPercent", 100)) / 100


static func maximum(course: Dictionary, base_only: bool = false, reference_power: float = 150.0) -> int:
	var total: int = 0
	for event: Dictionary in course.get("events", []):
		var best: int = 0
		for choice: Dictionary in choices(event):
			var value := base_units(event, choice, reference_power)
			if event.type == "charge" and not base_only:
				value = value * 3 / 2
			best = maxi(best, value)
		total += best
	return total


static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))


static func validate(course: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field in ["courseId", "title", "family"]:
		if not course.get(field) is String or str(course.get(field, "")).is_empty():
			errors.append("Missing %s" % field)
	if not _integer(course.get("schemaVersion")) or int(course.schemaVersion) != VERSION or not _integer(course.get("courseVersion")) or int(course.get("courseVersion", 0)) < 1:
		errors.append("Unsupported course version")
	if not _integer(course.get("durationMs")) or int(course.get("durationMs", 0)) <= 0 or int(course.get("durationMs", 0)) > 1800000 or int(course.get("durationMs", 0)) % 10 != 0:
		errors.append("Duration must be positive whole 10 ms ticks")
	if not course.get("events") is Array or not course.get("phases") is Array:
		errors.append("Events and phases must be arrays")
	if not errors.is_empty():
		return errors
	# Reject malformed/unbounded render allocations before a saved course reaches 3D.
	if course.events.size() > 4096 or course.phases.size() > 4096:
		errors.append("Course contains too many sections")
	if course.has("distanceBased") and not course.distanceBased is bool:
		errors.append("Invalid distance mode")
	if course.has("seed") and not _integer(course.seed):
		errors.append("Invalid track seed")
	if course.has("roadLengthMeters"):
		if not LaneSmashPath._number(course.roadLengthMeters) or float(course.roadLengthMeters) <= 0 or float(course.roadLengthMeters) > 33000:
			errors.append("Invalid road length")
	if not errors.is_empty(): return errors
	if bool(course.get("distanceBased", false)):
		if not _integer(course.get("maxSpeedKph")) or int(course.maxSpeedKph) != 60 or not _integer(course.get("maxCadenceRpm")) or int(course.maxCadenceRpm) != 140:
			errors.append("Unsupported distance speed limits")
		if not LaneSmashPath._number(course.get("roadLengthMeters")) or float(course.roadLengthMeters) < float(course.durationMs) / 60.0:
			errors.append("Road does not cover maximum ride distance")
	if not errors.is_empty(): return errors
	if course.has("presentation") and not LaneSmashPath.valid(course.presentation, float(course.get("roadLengthMeters", 0))):
		errors.append("Invalid presentation path")
	var phase_end: int = 0
	for phase: Variant in course.phases:
		if not phase is Dictionary or not phase.get("name") is String or not _integer(phase.get("startMs")) or not _integer(phase.get("endMs")):
			errors.append("Invalid phase")
			continue
		if int(phase.startMs) != phase_end or int(phase.endMs) <= phase_end:
			errors.append("Phases must cover the course contiguously")
		phase_end = int(phase.endMs)
	if phase_end != int(course.durationMs):
		errors.append("Phases must end at course duration")
	var ids := {}
	for event: Variant in course.events:
		if not event is Dictionary:
			errors.append("Event must be an object")
			continue
		if int(course.courseVersion) >= 3 and event.has("alternatives"):
			errors.append("Lane Smash tracks must have one target lane")
		if not event.get("eventId") is String or str(event.get("eventId", "")).is_empty() or ids.has(event.get("eventId")):
			errors.append("Missing or duplicate event ID")
		ids[event.get("eventId", "")] = true
		if event.get("type") not in ["pickup", "hold", "charge", "cruise", "burst"]:
			errors.append("Unknown event type")
			continue
		if not _integer(event.get("startMs")) or not _integer(event.get("endMs")):
			errors.append("Event times must be integers")
			continue
		var start := int(event.startMs)
		var end := int(event.endMs)
		if start < 0 or start >= end or end > int(course.durationMs) or start % 10 != 0 or end % 10 != 0:
			errors.append("Event outside course or off tick grid")
		if not _integer(event.get("laneIndex")) or int(event.get("laneIndex", -1)) not in range(6):
			errors.append("Invalid target lane")
		if event.has("alternatives") and (not event.alternatives is Array or event.alternatives.size() != 2):
			errors.append("A branch requires exactly two alternatives")
			continue
		var lanes := {}
		for choice: Variant in choices(event):
			if not choice is Dictionary or not _integer(choice.get("laneIndex")) or int(choice.get("laneIndex", -1)) not in range(6):
				errors.append("Invalid branch lane")
				continue
			if lanes.has(choice.laneIndex) or (not _integer(choice.get("rewardPercent", 100)) or int(choice.get("rewardPercent", 100)) not in [100, 125]):
				errors.append("Duplicate branch lane or invalid reward")
			lanes[choice.laneIndex] = true
		if event.type == "pickup":
			if not _integer(event.get("hitMs")) or int(event.get("hitMs", 0)) - 250 != start or int(event.get("hitMs", 0)) + 260 != end:
				errors.append("Pickup must include exactly its +/-250 ms window")
		elif event.type == "hold":
			if not _integer(event.get("cadenceMin")) or not _integer(event.get("cadenceMax")) or int(event.get("cadenceMin", 0)) < 20 or int(event.get("cadenceMax", 0)) > 120 or int(event.get("cadenceMin", 0)) > int(event.get("cadenceMax", 0)):
				errors.append("Invalid cadence band")
		elif event.type == "charge":
			# v1 publishes one target formula; arbitrary ratios would change comparison math.
			if event.get("ratio100") != 0.6 or event.get("ratio200") != 1.0:
				errors.append("Unsupported charge ratios")
	if not errors.is_empty():
		return errors
	if course.has("hazards") and (int(course.courseVersion) < 5 or not bool(course.get("distanceBased", false)) or not LaneSmashHazards.valid(course.hazards, course.events, int(course.durationMs))):
		errors.append("Invalid bomb hazards")
	if int(course.courseVersion) >= 5 and not course.has("hazards"):
		errors.append("Missing bomb hazards")
	var previous: Dictionary = {}
	var charge_end: int = -30000
	for event: Dictionary in course.events:
		if not previous.is_empty():
			var gap := int(event.startMs) - int(previous.endMs)
			if gap < 0:
				errors.append("Overlapping or unordered events")
			for a: Dictionary in choices(previous):
				for b: Dictionary in choices(event):
					var distance := absi(int(a.laneIndex) - int(b.laneIndex))
					if distance > 0 and gap < maxi(3000, 1500 * distance):
						errors.append("Unreachable lane transition before %s" % event.eventId)
		if event.type in ["charge", "burst"]:
			var minimum := 6000 if int(course.courseVersion) >= 4 and event.type == "burst" else 8000
			if int(event.startMs) - charge_end < 30000 or int(event.endMs) - int(event.startMs) not in range(minimum, 15001):
				errors.append("Power section needs %d–15 s and 30 s recovery" % (minimum / 1000))
			charge_end = int(event.endMs)
			for phase: Dictionary in course.phases:
				if phase.get("role", "work") != "work" and int(event.startMs) < int(phase.endMs) and int(event.endMs) > int(phase.startMs):
					errors.append("Charge outside a work phase")
		previous = event
	return errors


static func daily(date: String) -> Dictionary:
	# Deliberately specified PRNG, rather than an engine-version-dependent random stream.
	# Date is frozen at selection; stored content/hash permits replay after midnight/upgrades.
	var seed_value := date.to_utf8_buffer().hex_encode().sha256_text().substr(0, 7).hex_to_int() + 1
	var state := seed_value
	var course := load_course("steady_flow_20").duplicate(true)
	course.courseId = "daily_%s_g2" % date
	course.title = "Daily signal · %s" % date
	course.family = "daily"
	course["seed"] = seed_value
	course["generatorVersion"] = 2
	# Shift whole work blocks by at most one lane. Adjacent minutes differ by at most
	# two lanes, which fits the authored three-second transition. Never shift recovery.
	var offset := 0
	for event: Dictionary in course.get("events", []):
		if str(event.eventId).ends_with("-a"):
			state = (state * 48271) % 2147483647
			var in_work := false
			for phase: Dictionary in course.phases:
				if int(event.startMs) >= int(phase.startMs) and int(event.startMs) < int(phase.endMs):
					in_work = str(phase.get("role", "")) == "work"
			offset = int(state % 2) if in_work and int(event.laneIndex) < 4 else 0
		event.laneIndex = int(event.laneIndex) + offset
		for choice: Dictionary in event.get("alternatives", []):
			choice.laneIndex = int(choice.laneIndex) + offset
	return course
