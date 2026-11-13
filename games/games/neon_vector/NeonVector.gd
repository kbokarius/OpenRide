extends Game
## NEON VECTOR: an authored resistance-controlled ride, integrated with OpenRide's host.
## Rules never depend on render delta. The host's monotonic clock and delivery log drive them.

static var look := GameTheme.new(Color("67d8ff"), Color("0b132b"))

var rules := NeonRules.new()
var track: NeonTrack
var status: NeonStatus
var _sequence := -1
var _epoch := -1
var _started_clock := false
var _resume_left := 0.0
var _errors: Array[String] = []
var _result: Dictionary = {}
var _attempt_id := ""
var _rider := "guest"
var _checkpoint_ms := 0
var _save_busy := false
var _saved_final := false
var _finalizing := false
var _save_error := ""
var _ghost: Array = []
var _ghost_cursor := 0


func info() -> GameInfo:
	var i := GameInfo.new()
	i.id = "neon_vector"
	i.title = "NEON VECTOR"
	i.how_to = "Turn resistance to change lanes. Collect markers, hold cadence and charge with power."
	i.supports = ["minutes"]
	i.min_sec = 300
	i.max_sec = 1800
	i.timed_end_mode = "game"
	i.effort_in_just_ride = false
	i.star_thresholds = {"easy": [25, 60, 90], "standard": [25, 60, 90], "hard": [25, 60, 90]}
	i.options = [
		{"key": "world", "label": "World", "choices": ["city", "orbit", "abyss", "canyon"], "labels": ["Midnight Circuit", "Orbital Drift", "Deep Signal", "Solar Frontier"], "default": "city", "where": "hub"},
		{"key": "trail", "label": "Trail", "choices": ["ion", "prism", "comet"], "labels": ["Ion", "Prism", "Comet"], "default": "ion", "where": "hub"},
		{"key": "ghost", "label": "Best-ride ghost", "choices": ["on", "off"], "labels": ["On", "Off"], "default": "on", "kind": "segmented"},
		{"key": "motion", "label": "Background motion", "choices": ["full", "reduced"], "labels": ["Full", "Reduced"], "default": "full", "kind": "segmented"},
	]
	i.summary_stats = [
		{"key": "completion_percent", "label": "course targets", "suffix": "%"},
		{"key": "pickup_hits", "of": "pickup_count", "label": "pickups"},
		{"key": "max_score", "label": "maximum", "grouped": true},
	]
	return i


func ui_theme() -> GameTheme:
	return look


func target_text(_seg: Dictionary) -> String:
	if not _errors.is_empty():
		return "Course unavailable: %s" % _errors[0]
	return "%s · %s · %d–%d resistance · %.0f / %.0f W charge" % [rules.course.get("title", ""), rules.tier.capitalize(), NeonRules.TIERS[rules.tier], NeonRules.TIERS[rules.tier] + 41, rules.reference_power * 0.6, rules.reference_power]


func _ready() -> void:
	track = NeonTrack.new()
	track.name = "Track"
	add_child(track)


func _on_prepare(_seg: Dictionary) -> void:
	Engine.max_fps = 60
	var course_id := str(params.get("course_id", "tutorial"))
	var data := NeonCourse.daily(course_id.trim_prefix("daily_").trim_suffix("_g1")) if course_id.begins_with("daily_") else NeonCourse.load_course(course_id)
	_errors = rules.configure(data, str(params.get("lane_difficulty", "intermediate")), float(params.get("reference_power", 150)))
	_sequence = -1
	_epoch = -1
	_started_clock = false
	_resume_left = 0
	_result = {}
	_rider = GameOptions.rider()
	_attempt_id = NeonRecords.new_id()
	_checkpoint_ms = 0
	_save_busy = false
	_finalizing = false
	_saved_final = false
	_save_error = ""
	_ghost = []
	_ghost_cursor = 0
	variant = "nv1:" + rules.comparison_key(GameOptions.rider())
	track.rules = rules
	track.reduced_motion = option("motion") == "reduced"
	hud.set_skin(look.hud_skin())
	status = NeonStatus.new()
	status.rules = rules
	hud.add_widget(status)
	track.update_view(0)
	status.refresh()
	# No audio generator is registered: the whole experience is legible in silence.


func _on_start() -> void:
	_begin_ride()


func _begin_ride() -> void:
	_save_busy = true
	var progress := await NeonRecords.request({"action": "state"}, _rider)
	if not bool(progress.get("ok", false)):
		_storage_failed(progress)
		return
	var count := int(progress.get("completions", 0))
	track.world_id = option("world") if NeonWorlds.unlocked(option("world"), count) else "city"
	track.trail_id = option("trail") if NeonWorlds.unlocked(option("trail"), count, true) else "ion"
	var replay_id := str(params.get("replay_attempt_id", ""))
	if not replay_id.is_empty():
		var replay := await NeonRecords.request({"action": "get", "attemptId": replay_id}, _rider)
		if not bool(replay.get("ok", false)):
			_storage_failed(replay)
			return
		var saved: Dictionary = replay.get("record", {})
		_errors = rules.configure(saved.get("course", {}), rules.tier, rules.reference_power)
		variant = "nv1:" + rules.comparison_key(_rider)
	if not _errors.is_empty():
		_storage_failed(NeonRecords.failure("Course unavailable. End this ride and choose another."))
		return
	var previous := await NeonRecords.request({"action": "best", "key": rules.comparison_key(_rider)}, _rider)
	if not bool(previous.get("ok", false)):
		_storage_failed(previous)
		return
	var ghost_record: Dictionary = previous.get("record", {})
	if not ghost_record.is_empty() and NeonRecords.valid_record(ghost_record) and ghost_record.get("comparisonKey", "") == rules.comparison_key(_rider):
		_ghost = ghost_record.get("ghost", [])
	var reply := await NeonRecords.request({"action": "save", "record": _record("pending")}, _rider)
	_save_busy = false
	if not bool(reply.get("ok", false)):
		_storage_failed(reply)
		return
	# A user may pause/end while storage is loading; never start a clock behind that overlay.
	if _finalizing or not _result.is_empty():
		return
	rules.resume()
	_started_clock = true
	Session.neon_control("begin", 0, int(rules.course.durationMs))
	_sequence = -1
	if Session.paused:
		Session.neon_control("pause", 0)


func _record(state: String) -> Dictionary:
	var result := rules.result(state)
	return {"version": 1, "attemptId": _attempt_id, "riderId": _rider,
		"comparisonKey": rules.comparison_key(_rider), "course": rules.course.duplicate(true),
		"result": result, "ghost": rules.ghost_trace.duplicate(true) if state == "completed" else []}


func _checkpoint() -> void:
	_save_busy = true
	_checkpoint_ms = rules.elapsed_ms
	var reply := await NeonRecords.request({"action": "save", "record": _record("pending")}, _rider)
	_save_busy = false
	if not bool(reply.get("ok", false)):
		_storage_failed(reply)


func _storage_failed(reply: Dictionary) -> void:
	_save_busy = false
	_save_error = str(reply.get("error", "Could not save this ride."))
	_pause("storage")


func _complete(state: String) -> void:
	if _finalizing:
		return
	_finalizing = true
	Session.neon_control("pause", rules.elapsed_ms)
	while _save_busy:
		await get_tree().process_frame
	_result = rules.result(state)
	var reply := await NeonRecords.request({"action": "save", "record": _record(state)}, _rider)
	if not bool(reply.get("ok", false)):
		_finalizing = false
		_storage_failed(reply)
		return
	_save_error = ""
	_saved_final = true
	Session.neon_control("stop")
	end_segment()


func _update_ghost() -> void:
	track.ghost_visible = option("ghost") == "on" and not _ghost.is_empty()
	if _ghost.is_empty():
		return
	while _ghost_cursor + 1 < _ghost.size() and int(_ghost[_ghost_cursor + 1][0]) <= rules.elapsed_ms:
		_ghost_cursor += 1
	var tick: Array = _ghost[_ghost_cursor]
	track.ghost_lane = float(tick[1]) if int(tick[0]) <= rules.elapsed_ms else -1.0
	track.ghost_delta = floori(float(rules.score_units - int(tick[2])) / NeonRules.UNIT)


func _on_frame(delta: float) -> void:
	played_sec = rules.elapsed_ms / 1000.0
	if not _started_clock or _finalizing:
		status.heading.text = "SAVING YOUR SIGNAL" if _finalizing else "PREPARING YOUR SIGNAL"
		status.target.text = "Keeping your progress safe"
		status.detail.text = "Course time and points are frozen"
		return
	if not _errors.is_empty():
		return
	if _resume_left > 0:
		if InputBus.sample_age_ms > 1500:
			_pause("sensor")
			return
		_resume_left = maxf(0, _resume_left - delta)
		status.heading.text = "READY TO RESUME"
		status.target.text = str(ceili(_resume_left)) if _resume_left > 0 else "GO"
		status.detail.text = "The course is holding your place"
		if _resume_left > 0:
			return
		rules.resume()
		Session.neon_control("resume")
		_sequence = -1
	var batch := InputBus.neon_batch(_sequence)
	if not bool(batch.get("fresh", false)) or not bool(batch.get("running", false)):
		_pause(str(batch.get("pause_reason", "sensor")) if not str(batch.get("pause_reason", "")).is_empty() else "sensor")
		return
	if delta > 0.25:
		_pause("stall")
		return
	var epoch := int(batch.get("epoch", 0))
	var initial := epoch != _epoch
	_epoch = epoch
	for raw: Dictionary in batch.get("samples", []):
		var sample := raw.duplicate()
		var timestamp := int(raw.received_ms) - int(batch.origin_ms)
		if initial and timestamp < rules.elapsed_ms:
			timestamp = rules.elapsed_ms
		sample["t"] = timestamp
		rules.push_sample(sample)
		_sequence = maxi(_sequence, int(raw.seq))
	rules.advance(int(batch.elapsed_ms))
	Session.neon_control("ack", rules.elapsed_ms)
	played_sec = rules.elapsed_ms / 1000.0
	Effort.set_unmultiplied_total(float(rules.score_units) / NeonRules.UNIT)
	_update_ghost()
	track.update_view(delta)
	status.refresh()
	if not rules.pause_reason.is_empty():
		_pause(rules.pause_reason)
	elif rules.elapsed_ms >= int(rules.course.durationMs):
		_complete("completed")
	elif rules.elapsed_ms - _checkpoint_ms >= 5000 and not _save_busy:
		_checkpoint()


func _pause(reason: String) -> void:
	rules.pause(reason)
	Session.neon_control("pause", rules.elapsed_ms)
	status.refresh()
	Session.request_pause()


func _on_pause() -> void:
	if _started_clock:
		if rules.pause_reason.is_empty():
			rules.pause("manual")
		Session.neon_control("pause", rules.elapsed_ms)
		if status:
			status.refresh()
		if not _save_busy and not _finalizing:
			_checkpoint()


func _on_resume() -> void:
	if not _save_error.is_empty():
		_save_error = ""
		if not _result.is_empty():
			_complete(str(_result.status))
			return
		if not _started_clock:
			_begin_ride()
			return
	if _started_clock:
		_resume_left = 3.0


func resume_block_reason() -> String:
	if _save_busy or _finalizing:
		return "Saving your ride…"
	if not _save_error.is_empty():
		return ""  # Resume explicitly retries the save.
	if not InputBus.neon_resume_ready():
		return "Waiting for one second of fresh bike data"
	return ""


func pause_message() -> String:
	if not _save_error.is_empty():
		return _save_error + " Tap Resume to retry."
	return {"sensor": "Bike data stopped. Your course is holding its place.",
		"stall": "The display stalled. Your course is holding its place.",
		"pedalling": "Pedalling stopped. Resume when you’re ready."}.get(rules.pause_reason, "Tap Resume for a three-second countdown.")


func _on_option_changed(key: String, value: String) -> void:
	if key == "motion":
		track.reduced_motion = value == "reduced"
	elif key == "ghost":
		track.ghost_visible = value == "on" and track.ghost_lane >= 0


func _on_finish_requested() -> void:
	_complete("completed" if rules.elapsed_ms >= int(rules.course.get("durationMs", 1)) else "ended")


func finish() -> Dictionary:
	if _result.is_empty():
		_result = rules.result("ended")
	if not _saved_final:
		_result.status = "interrupted"
		_result.stars = 0
	var result := super.finish()
	result.score = int(_result.scoreUnits) / NeonRules.UNIT
	result.stars = int(_result.stars)
	var hits := 0
	var pickups := 0
	for index in rules.event_states.size():
		if rules.course.events[index].type == "pickup":
			pickups += 1
			if rules.event_states[index].hit:
				hits += 1
	result.stats["neon"] = _result.duplicate(true)
	result.stats["completion_percent"] = roundi(float(rules.base_units) / maxi(1, rules.max_base_units) * 100)
	result.stats["pickup_hits"] = hits
	result.stats["pickup_count"] = pickups
	result.stats["max_score"] = rules.max_units / NeonRules.UNIT
	result.stats["played_sec"] = rules.elapsed_ms / 1000
	return result
