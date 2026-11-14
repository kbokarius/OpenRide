class_name NeonRecords
extends RefCounted
## Room on Android; atomic, versioned JSON per attempt on desktop. Never loads Resources.

static var path := "user://neon_records"
static var _recovered_path := ""


static func request(data: Dictionary, rider_id: String) -> Dictionary:
	if Engine.has_singleton("OpenRideBridge"):
		var bridge := Engine.get_singleton("OpenRideBridge")
		# Android plugin methods live in JNISingleton's Java method table.
		if not bridge.has_java_method("neon_records_request"):
			return failure("This app version cannot save Lane Smash rides.")
		var ticket: int = bridge.neon_records_request(JSON.stringify(data, "", true, true))
		if ticket < 0:
			return failure("Ride storage is busy. Please retry.")
		var deadline := Time.get_ticks_msec() + 15000
		while Time.get_ticks_msec() < deadline:
			var reply: String = bridge.neon_records_reply(ticket)
			if not reply.is_empty():
				var decoded = JSON.parse_string(reply)
				return decoded if decoded is Dictionary else failure("Unreadable save response.")
			await (Engine.get_main_loop() as SceneTree).process_frame
		return failure("Saving took too long. Please retry.")
	return local_request(data, rider_id)


static func new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


static func failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}


static func local_request(data: Dictionary, rider_id: String) -> Dictionary:
	if DirAccess.make_dir_recursive_absolute(path) != OK:
		return failure("Could not open ride storage.")
	if _recovered_path != path:
		for id in _ids():
			var record := _read(id)
			if not record.is_empty() and record.result.status == "pending":
				record.result.status = "interrupted"
				record.result.stars = 0
				if not _atomic_write(record):
					return failure("Could not recover interrupted rides.")
		_recovered_path = path
	match str(data.get("action", "")):
		"save":
			var record: Dictionary = data.get("record", {}).duplicate(true)
			if not valid_record(record) or str(record.get("riderId", "")) != rider_id:
				return failure("Ride data is invalid.")
			var old := _read(str(record.attemptId))
			if not old.is_empty():
				if old.riderId != rider_id or old.comparisonKey != record.comparisonKey or old.result.courseId != record.result.courseId:
					return failure("Ride identity changed.")
				if old.result.status != "pending":
					return {"ok": true, "status": old.result.status, "attemptId": old.attemptId}
				if int(record.result.activeDurationMs) < int(old.result.activeDurationMs) or _earned(record.result) < _earned(old.result) or _penalty(record.result) < _penalty(old.result):
					return failure("Checkpoint moved backwards.")
			elif record.result.status != "pending":
				return failure("Ride must start before its result is saved.")
			record.updatedMs = int(Time.get_unix_time_from_system() * 1000)
			if not _atomic_write(record):
				return failure("Could not save this ride. Please retry.")
			return {"ok": true, "status": record.result.status, "attemptId": record.attemptId}
		"get":
			var record := _read(str(data.get("attemptId", "")))
			return {"ok": true, "record": record} if not record.is_empty() and record.riderId == rider_id else failure("Saved ride not found.")
		"state", "best":
			var rows: Array[Dictionary] = []
			var completions := 0
			var best: Dictionary = {}
			for id in _ids():
				var record := _read(id)
				if record.get("riderId", "") != rider_id:
					continue
				if record.result.status == "completed":
					if record.result.courseId != "tutorial":
						completions += 1
					if record.comparisonKey == data.get("key", "") and (best.is_empty() or int(record.result.scoreUnits) > int(best.result.scoreUnits)):
						best = record
				if data.action == "best": continue
				# Keep at most one full trace while reading; menu history needs metadata only.
				record.erase("ghost")
				record.erase("course")
				record.result.erase("events")
				record.result.erase("barrage")
				rows.append(record)
			if data.action == "best":
				return {"ok": true, "record": best}
			rows.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.attemptId) > str(b.attemptId) if int(a.get("updatedMs", 0)) == int(b.get("updatedMs", 0)) else int(a.get("updatedMs", 0)) > int(b.get("updatedMs", 0)))
			var track_stats := {}
			for row in rows:
				if row.result.status == "pending": continue
				var key := str(row.comparisonKey)
				if not track_stats.has(key):
					track_stats[key] = {"lastScoreUnits": row.result.scoreUnits, "lastStatus": row.result.status, "bestScoreUnits": -1}
				if row.result.status == "completed":
					track_stats[key].bestScoreUnits = maxi(int(track_stats[key].bestScoreUnits), int(row.result.scoreUnits))
			rows = rows.slice(0, 50)
			return {"ok": true, "completions": completions, "history": rows, "trackStats": track_stats}
	return failure("Unknown ride storage request.")


static func valid_record(record: Dictionary) -> bool:
	if not NeonCourse._integer(record.get("version")) or int(record.version) != 1 or not record.has_all(["attemptId", "comparisonKey", "result", "course", "riderId"]):
		return false
	if not _hex(str(record.attemptId), 32) or not _hex(str(record.comparisonKey), 64):
		return false
	if not record.result is Dictionary or not record.course is Dictionary:
		return false
	var result: Dictionary = record.result
	if not result.has_all(["status", "activeDurationMs", "scoreUnits", "courseId"]):
		return false
	for value in [record.course.get("durationMs"), result.activeDurationMs, result.scoreUnits]:
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)):
			return false
	var duration := int(record.course.get("durationMs", 0))
	var elapsed := int(result.activeDurationMs)
	var score := int(result.scoreUnits)
	if duration < 300000 or duration > 1800000 or elapsed < 0 or elapsed > duration or score < 0 or score > 10000000000000:
		return false
	if result.courseId != record.course.get("courseId") or result.status not in ["pending", "completed", "ended", "interrupted"]:
		return false
	if result.status == "completed" and elapsed != duration:
		return false
	var version: Variant = result.get("scoringVersion", 1)
	if not NeonCourse._integer(version) or int(version) not in range(1, 6): return false
	var gross := score
	if int(version) >= 4:
		for field in ["earnedScoreUnits", "penaltyUnits"]:
			if not NeonCourse._integer(result.get(field)) or int(result[field]) < 0 or int(result[field]) > 10000000000000: return false
		gross = int(result.earnedScoreUnits)
		if gross - int(result.penaltyUnits) != score: return false
	var ghost = record.get("ghost", [])
	if not ghost is Array or ghost.size() > 18001:
		return false
	var last_time := -1
	var last_score := 0
	var last_distance := 0
	var row_size := 0
	for tick in ghost:
		if not tick is Array or tick.size() not in [3, 4]:
			return false
		if row_size != 0 and tick.size() != row_size: return false
		row_size = tick.size()
		for value in tick:
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)):
				return false
		if int(tick[0]) <= last_time or int(tick[0]) > elapsed or int(tick[1]) < -1 or int(tick[1]) > 5 or int(tick[2]) < (0 if int(version) >= 4 else last_score) or int(tick[2]) > gross:
			return false
		if tick.size() == 4:
			if int(tick[3]) < last_distance or int(tick[3]) > ceili(float(tick[0]) * NeonRules.MAX_SPEED_MPS) + 2:
				return false
			last_distance = int(tick[3])
		last_time = int(tick[0])
		last_score = int(tick[2])
	return true


static func _hex(value: String, length: int) -> bool:
	return value.length() == length and value.is_valid_hex_number(false)


static func _ids() -> Array[String]:
	var ids: Array[String] = []
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".json"): ids.append(file.trim_suffix(".json"))
	return ids


static func _read(id: String) -> Dictionary:
	if not _hex(id, 32) or not FileAccess.file_exists(path.path_join(id + ".json")):
		return {}
	var file := FileAccess.open(path.path_join(id + ".json"), FileAccess.READ)
	if file == null or file.get_length() > 2000000:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary and valid_record(data) else {}


static func _atomic_write(record: Dictionary) -> bool:
	var target := path.path_join(str(record.attemptId) + ".json")
	var temporary := target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(record, "", true, true))
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(temporary, target) == OK

static func _penalty(result: Dictionary) -> int:
	return int(result.get("penaltyUnits", 0)) if int(result.get("scoringVersion", 1)) >= 4 else 0

static func _earned(result: Dictionary) -> int:
	return int(result.scoreUnits) + _penalty(result)
