extends Game
## NEON VECTOR: an authored resistance-controlled ride, integrated with OpenRide's host.
## Rules never depend on render delta. The host's monotonic clock and delivery log drive them.

static var look := GameTheme.new(Color("79b8d5"), Color("0b1019"), 0.0, false, true)

var rules := NeonRules.new()
var track: NeonTrack
var status: NeonStatus
var _host_music_on := true
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
	i.title = "Lane Smash"
	i.how_to = "Turn resistance to change lanes. Collect points, match cadence targets and build power in the marked lane. Avoid red bombs: each hit costs up to 100 points."
	i.supports = ["minutes"]
	i.min_sec = 300
	i.max_sec = 1800
	i.timed_end_mode = "game"
	i.effort_in_just_ride = false
	i.star_thresholds = {"easy": [25, 60, 90], "standard": [25, 60, 90], "hard": [25, 60, 90]}
	i.options = [
		{"key": "ghost", "label": "Best-ride ghost", "choices": ["on", "off"], "labels": ["On", "Off"], "default": "on", "kind": "segmented"},
		{"key": "music", "label": "Music", "choices": ["on", "off"], "labels": ["On", "Off"], "default": "on", "kind": "segmented"},
		{"key": "motion", "label": "Background motion", "choices": ["full", "reduced"], "labels": ["Full", "Reduced"], "default": "full", "kind": "segmented"},
	]
	i.summary_stats = [
		{"key": "completion_percent", "label": "course targets", "suffix": "%"},
		{"key": "burst_energy", "label": "burst energy", "suffix": " J", "grouped": true},
		{"key": "max_score", "label": "target score", "grouped": true},
	]
	return i


func ui_theme() -> GameTheme:
	return look


func target_text(_seg: Dictionary) -> String:
	if not _errors.is_empty():
		return "Course unavailable: %s" % _errors[0]
	return "%s · %s · %d–%d resistance" % [rules.course.get("title", ""), rules.tier.capitalize(), NeonRules.TIERS[rules.tier], NeonRules.TIERS[rules.tier] + 41]


func _ready() -> void:
	track = NeonTrack.new()
	track.name = "Track"
	add_child(track)


func _on_prepare(_seg: Dictionary) -> void:
	Engine.max_fps = 60
	var course_id := str(params.get("course_id", "ls_20_01"))
	var data := NeonCourse.daily(course_id.get_slice("_", 1)) if course_id.begins_with("daily_") else NeonCourse.load_course(course_id)
	_errors = rules.configure(data, str(params.get("lane_difficulty", "challenging")), float(params.get("reference_power", 150)))
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
	variant = "nv%d:" % rules.scoring_version + rules.comparison_key(GameOptions.rider())
	track.world_id = str(rules.course.get("theme", "arctic"))
	track.rules = rules
	track.reduced_motion = option("motion") == "reduced"
	var skin := look.hud_skin()
	skin["manual_pause"] = false
	skin["text_interval"] = 1.0
	hud.set_skin(skin)
	status = NeonStatus.new()
	status.rules = rules
	hud.add_widget(status)
	track.update_view(0)
	status.refresh()
	_host_music_on = AudioDirector.music_enabled
	_apply_music()


func _on_start() -> void:
	_begin_ride()


func _begin_ride() -> void:
	_save_busy = true

	var replay_id := str(params.get("replay_attempt_id", ""))
	if not replay_id.is_empty():
		var replay := await NeonRecords.request({"action": "get", "attemptId": replay_id}, _rider)
		if not bool(replay.get("ok", false)):
			_storage_failed(replay)
			return
		var saved: Dictionary = replay.get("record", {})
		_errors = rules.configure(saved.get("course", {}), rules.tier, rules.reference_power)
		variant = "nv%d:" % rules.scoring_version + rules.comparison_key(_rider)
	if not _errors.is_empty():
		_storage_failed(NeonRecords.failure("Course unavailable. End this ride and choose another."))
		return
	track.world_id = str(rules.course.get("theme", "arctic"))
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
	var position := float(tick[3]) / 1000.0 if tick.size() == 4 else rules.road_distance() + 3.5
	var ghost_lane := float(tick[1])
	if tick.size() == 4 and _ghost_cursor + 1 < _ghost.size():
		var following: Array = _ghost[_ghost_cursor + 1]
		track.ghost_cadence = clampf(float(int(following[3]) - int(tick[3])) / maxi(1, int(following[0]) - int(tick[0])) / NeonRules.MAX_SPEED_MPS * NeonRules.MAX_CADENCE, 0, NeonRules.MAX_CADENCE)
		var blend := clampf(float(rules.elapsed_ms - int(tick[0])) / maxi(1, int(following[0]) - int(tick[0])), 0, 1)
		position = lerpf(position, float(following[3]) / 1000.0, blend)
		if ghost_lane >= 0 and int(following[1]) >= 0: ghost_lane = lerpf(ghost_lane, float(following[1]), blend)
	track.ghost_lane = ghost_lane
	track.ghost_distance = position
	track.ghost_gap = position - rules.road_distance()
	track.ghost_delta = floori(float(rules.score_units - int(tick[2])) / NeonRules.UNIT)


func _on_frame(delta: float) -> void:
	played_sec = rules.elapsed_ms / 1000.0
	if not _started_clock or _finalizing:
		status.heading.text = "SAVING YOUR RIDE" if _finalizing else "PREPARING YOUR RIDE"
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
	Session.request_pause(true)


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
		return "Reconnecting to your bike…"
	return ""


func allows_manual_pause() -> bool:
	return false

func automatic_resume_ready() -> bool:
	return _save_error.is_empty() and not _save_busy and not _finalizing and InputBus.neon_resume_ready()

func recovery_retry_available() -> bool:
	return not _save_error.is_empty() and not _save_busy


func pause_message() -> String:
	if not _save_error.is_empty():
		return _save_error + " Tap Retry save or end this ride."
	return {"sensor": "Bike data stopped. Your course is holding its place.",
		"stall": "The display stalled. Your course is holding its place.",
		"pedalling": "Pedal to reconnect. Recovery starts automatically."}.get(rules.pause_reason, "The ride will continue automatically when ready.")


func _apply_music() -> void:
	AudioDirector.set_volumes(_host_music_on and option("music") == "on", AudioDirector.music_volume, AudioDirector.sfx_volume)
	AudioDirector.play_music({"name": "neon_vector_drive", "stem_files": {"drive": "res://games/neon_vector/audio/vector_drive.ogg"}, "loop_from": 0.0}, 128.0)


func _on_option_changed(key: String, value: String) -> void:
	if key == "music":
		_apply_music()
	elif key == "motion":
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
	var energy := 0
	var hits := 0
	var pickups := 0
	for index in rules.event_states.size():
		energy += int(rules.event_states[index].get("energyMilliJoules", 0))
		if rules.course.events[index].type == "pickup":
			pickups += 1
			if rules.event_states[index].hit:
				hits += 1
	result.stats["neon"] = _result.duplicate(true)
	result.stats["completion_percent"] = roundi(float(rules.base_units) / maxi(1, rules.max_base_units) * 100)
	result.stats["burst_energy"] = energy / 1000
	result.stats["pickup_hits"] = hits
	result.stats["pickup_count"] = pickups
	result.stats["max_score"] = rules.max_units / NeonRules.UNIT
	result.stats["played_sec"] = rules.elapsed_ms / 1000
	return result
