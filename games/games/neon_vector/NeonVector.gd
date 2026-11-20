extends Game
## NEON VECTOR: an authored resistance-controlled ride, integrated with OpenRide's host.
## Rules never depend on render delta. The host's monotonic clock and delivery log drive them.

static var look: GameTheme = LaneSmashMenuTheme.shared()

## Automatic graphics: the average frame rate over each window while riding decides whether
## the 3D view steps down a tier. It never steps back up within a ride.

var rules := NeonRules.new()
var track: NeonTrack
var status: NeonStatus
var _hud_panel: StyleBoxFlat  ## the ride and clock panels' shared style; its edge pulses with the music
var audio_controls: LaneSmashAudioControls
var sounds: LaneSmashSound
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
var _ghost_playback := LaneSmashGhostPlayback.new()
var _ghost: Array = []:
	set(value):
		_ghost = value
		_ghost_playback.configure(value, int(rules.course.get("durationMs", 0)))
var _benchmark_card: LaneSmashBenchmarkCard
var _benchmark_selection: Dictionary = {}
var _benchmark_loading := false
var _benchmark_error := ""
var _governor := LaneSmashGovernor.new()


func info() -> GameInfo:
	var i := GameInfo.new()
	i.id = "neon_vector"
	i.title = "Lane Smash"
	i.how_to = "Turn resistance to change lanes. Collect points, match cadence targets and build power in the marked lane. Avoid red bombs. During Incoming Fire, change pace to dodge the marked blast. Hits cost points. Pass the blast to earn a bonus; hanging back avoids damage without earning points."
	i.supports = ["minutes"]
	i.min_sec = 300
	i.max_sec = 1800
	i.timed_end_mode = "game"
	i.effort_in_just_ride = false
	i.star_thresholds = {"easy": [25, 60, 90], "standard": [25, 60, 90], "hard": [25, 60, 90]}
	i.options = [
		{"key": "ghost", "label": "Best-ride ghost", "choices": ["on", "off"], "labels": ["On", "Off"], "default": "on", "kind": "segmented"},
		{"key": "music", "label": "Music", "choices": ["on", "off"], "labels": ["On", "Off"], "default": "on", "kind": "segmented"},
		{"key": "sfx", "label": "Sound effects", "choices": ["on", "off"], "labels": ["On", "Off"], "default": "on", "kind": "segmented"},
		{"key": "motion", "label": "Background motion", "choices": ["full", "reduced"], "labels": ["Full", "Reduced"], "default": "full", "kind": "segmented"},
		{"key": "graphics", "label": "Graphics", "choices": ["auto", "high", "performance"], "labels": ["Auto", "High", "Performance"], "default": "auto", "kind": "segmented"},
	]
	i.summary_stats = [
		{"key": "completion_percent", "label": "course targets", "suffix": "%"},
		{"key": "burst_energy", "label": "burst energy", "suffix": " J", "grouped": true},
		{"key": "max_score", "label": "target score", "grouped": true},
	]
	return i


func ui_theme() -> GameTheme:
	return look


func how_to_text(_segment: Dictionary) -> String:
	return "Turn resistance to follow the highlighted lane.\nCollect points, match pedal speed and avoid bombs."


func intro_visual() -> Control:
	_benchmark_card = LaneSmashBenchmarkCard.new()
	_refresh_benchmark_card()
	return _benchmark_card


func intro_ready() -> bool:
	return not _benchmark_loading


func _refresh_benchmark_card() -> void:
	if not is_instance_valid(_benchmark_card) or _benchmark_loading: return
	if not _benchmark_error.is_empty(): _benchmark_card.show_error()
	else: _benchmark_card.show_benchmark(_benchmark_selection, option("ghost") == "on", not _ghost.is_empty(), _ghost_playback.complete)


## The ride HUD's skin, shared with the capture harnesses so reviews match the real game.
static func hud_skin() -> Dictionary:
	var skin := look.hud_skin()
	skin["manual_pause"] = false
	skin["text_interval"] = 1.0
	skin["score_rollup"] = true
	return skin


func target_text(_seg: Dictionary) -> String:
	if not _errors.is_empty():
		return "Course unavailable: %s" % _errors[0]
	return "%s · %s · %d–%d resistance" % [rules.course.get("title", ""), rules.tier.capitalize(), NeonRules.band(0, rules.tier).x, NeonRules.band(5, rules.tier).y]


func _ready() -> void:
	track = NeonTrack.new()
	track.name = "Track"
	add_child(track)


func _on_prepare(_seg: Dictionary) -> void:
	Engine.max_fps = 60
	var course_id := str(params.get("course_id", "ls_20_01"))
	var data := NeonCourse.daily(course_id.get_slice("_", 1)) if course_id.begins_with("daily_") else NeonCourse.load_course(course_id)
	var difficulty := str(params.get("lane_difficulty", "challenging"))
	data = NeonCourse.for_difficulty(data, difficulty)
	_errors = rules.configure(data, difficulty, float(params.get("reference_power", 150)))
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
	_benchmark_selection = {}
	_benchmark_error = ""
	_benchmark_loading = true
	variant = "nv%d:" % rules.scoring_version + rules.comparison_key(GameOptions.rider())
	track.world_id = str(rules.course.get("theme", "arctic"))
	track.rules = rules
	track.reduced_motion = option("motion") == "reduced"
	track.apply_quality(_starting_quality())
	_governor.reset()
	var skin := hud_skin()
	_hud_panel = skin.get("panel") as StyleBoxFlat
	hud.set_skin(skin)
	status = NeonStatus.new()
	status.rules = rules
	hud.add_widget(status)
	track.update_view(0)
	status.refresh()
	audio_controls = LaneSmashAudioControls.new()
	audio_controls.info = declared()
	audio_controls.rider_id = _rider
	var buttons := hud.end_button.get_parent()
	buttons.add_child(audio_controls)
	buttons.move_child(audio_controls, hud.end_button.get_index())
	sounds = LaneSmashSound.new()
	sounds.track = track
	add_child(sounds)
	_apply_music()
	_prepare_benchmark.call_deferred()


func _on_start() -> void:
	_begin_ride()


func _load_benchmark() -> Dictionary:
	var replay_id := str(params.get("replay_attempt_id", ""))
	if not replay_id.is_empty():
		var replay := await NeonRecords.request({"action": "get", "attemptId": replay_id}, _rider)
		if not bool(replay.get("ok", false)):
			return replay
		var saved: Dictionary = replay.get("record", {})
		_errors = rules.configure(saved.get("course", {}), rules.tier, rules.reference_power)
		variant = "nv%d:" % rules.scoring_version + rules.comparison_key(_rider)
	if not _errors.is_empty():
		return NeonRecords.failure("Course unavailable. End this ride and choose another.")
	track.world_id = str(rules.course.get("theme", "arctic"))
	var previous := await NeonRecords.request({"action": "state"}, _rider)
	if not bool(previous.get("ok", false)):
		return previous
	_benchmark_selection = NeonBenchmark.select(previous.get("trackStats", {}), rules, _rider)
	var best: Dictionary = _benchmark_selection.best
	_ghost = []
	track.ghost_different_version = bool(_benchmark_selection.differentVersion)
	if not best.is_empty():
		var saved := await NeonRecords.request({"action": "get", "attemptId": best.attemptId}, _rider)
		if not bool(saved.get("ok", false)): return saved
		var ghost_record: Dictionary = saved.get("record", {})
		if not NeonRecords.valid_record(ghost_record) or ghost_record.result.status != "completed" or not NeonBenchmark.matches(NeonRecords.benchmark(ghost_record), rules, _rider):
			return NeonRecords.failure("Saved best ride could not be read.")
		_ghost = ghost_record.get("ghost", [])
	return {"ok": true}


func _prepare_benchmark() -> void:
	_benchmark_loading = true
	var reply := await _load_benchmark()
	_benchmark_error = str(reply.get("error", "")) if not bool(reply.get("ok", false)) else ""
	_benchmark_loading = false
	_refresh_benchmark_card()


func _begin_ride() -> void:
	_save_busy = true
	while _benchmark_loading:
		await get_tree().process_frame
	if not _benchmark_error.is_empty():
		await _prepare_benchmark()
		if not _benchmark_error.is_empty():
			_storage_failed(NeonRecords.failure(_benchmark_error))
			return
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
	if is_instance_valid(sounds): sounds.suspend()
	if is_instance_valid(audio_controls): audio_controls.panel.hide()
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
	_ghost_playback.update(rules.elapsed_ms, rules.road_distance() + 3.5)
	var enabled := option("ghost") == "on"
	track.ghost_visible = enabled and _ghost_playback.available
	track.ghost_notice = _ghost_playback.notice if enabled else ""
	track.ghost_opacity = _ghost_playback.opacity
	track.ghost_cadence = _ghost_playback.cadence
	track.ghost_lane = _ghost_playback.lane
	track.ghost_distance = _ghost_playback.distance
	track.ghost_gap = _ghost_playback.distance - rules.road_distance() if _ghost_playback.available else 0.0
	track.ghost_delta = floori(float(rules.score_units - _ghost_playback.score_units) / NeonRules.UNIT) if _ghost_playback.available else 0


func _on_frame(delta: float) -> void:
	if is_instance_valid(sounds): sounds.active = false
	played_sec = rules.elapsed_ms / 1000.0
	if not _started_clock or _finalizing:
		status.show_notice("SAVING YOUR RIDE" if _finalizing else "PREPARING YOUR RIDE", "Keeping your progress safe", "Course time and points are frozen")
		return
	if not _errors.is_empty():
		return
	if _resume_left > 0:
		if InputBus.sample_age_ms > 1500:
			_pause("sensor")
			return
		_resume_left = maxf(0, _resume_left - delta)
		status.show_notice("READY TO RESUME", str(ceili(_resume_left)) if _resume_left > 0 else "GO", "The course is holding your place")
		if _resume_left > 0:
			return
		rules.resume()
		Session.neon_control("resume")
		_sequence = -1
	var batch := InputBus.neon_batch(_sequence)
	if not bool(batch.get("fresh", false)) or not bool(batch.get("running", false)):
		_pause(str(batch.get("pause_reason", "sensor")) if not str(batch.get("pause_reason", "")).is_empty() else "sensor")
		return
	# A long frame is caught up, not treated as an interruption: the batch above already holds
	# every sensor sample from that time. Only a stall of more than a second pauses the ride.
	if delta > NeonLocalInput.STALL_MS / 1000.0:
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
	sounds.active = rules.pause_reason.is_empty()
	_govern_quality(delta)
	track.update_view(delta)
	_pulse_hud()
	sounds.update_audio()
	status.refresh()
	if not rules.pause_reason.is_empty():
		_pause(rules.pause_reason)
	elif rules.elapsed_ms >= int(rules.course.durationMs):
		_complete("completed")
	elif rules.elapsed_ms - _checkpoint_ms >= 5000 and not _save_busy:
		_checkpoint()


## The HUD's panel edges breathe with the music, like the track's own accent lines.
func _pulse_hud() -> void:
	var levels: Vector4 = track.music_levels
	var edge := LaneSmashLook.pulsed(Color(LaneSmashMenuTheme.ACCENT, 0.34), levels)
	edge.a = clampf(0.34 + 0.4 * levels.w + 0.2 * levels.x, 0.0, 0.9)
	if _hud_panel != null and not _hud_panel.border_color.is_equal_approx(edge): _hud_panel.border_color = edge
	if is_instance_valid(status): status.set_edge(edge)


## The tier this ride starts on: the rider's explicit choice, or (Auto) the tier the last ride
## settled on for this device.
func _starting_quality() -> String:
	var choice := option("graphics")
	if choice in ["high", "performance"]: return choice
	return GameOptions.graphics_tier(NeonTrack.default_quality())


## Auto only: one step down when the frame rate stays under the floor (see LaneSmashGovernor).
func _govern_quality(delta: float) -> void:
	if option("graphics") != "auto" or DisplayServer.get_name() == "headless": return
	if not _governor.observe(delta): return
	var index := NeonTrack.TIERS.find(track.quality)
	if index < 0 or index >= NeonTrack.TIERS.size() - 1: return
	var lower: String = NeonTrack.TIERS[index + 1]
	var fps := _governor.last_fps
	track.apply_quality(lower)
	GameOptions.set_graphics_tier(lower)
	print("OPENRIDE_GAMES lane_smash quality tier=%s fps=%.1f" % [lower, fps])


func _pause(reason: String) -> void:
	# Logged so a ride that was interrupted on the bike can be explained afterwards.
	if rules.pause_reason.is_empty() or rules.pause_reason != reason:
		print("OPENRIDE_GAMES lane_smash pause reason=%s at_ms=%d sample_age_ms=%d" % [reason, rules.elapsed_ms, int(minf(InputBus.sample_age_ms, 99999.0))])
	rules.pause(reason)
	Session.neon_control("pause", rules.elapsed_ms)
	status.refresh()
	Session.request_pause(true)


func _on_pause() -> void:
	if is_instance_valid(sounds): sounds.suspend()
	if is_instance_valid(audio_controls): audio_controls.panel.hide()
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
	GameOptions.apply_audio()
	# The jukebox owns the soundtrack across menu and ride: a ride never restarts the music.
	AudioDirector.stop_music(0.2)
	Jukebox.ensure_started()


func _on_option_changed(key: String, value: String) -> void:
	if key in ["music", "sfx"]:
		GameOptions.apply_audio()
	elif key == "motion":
		track.reduced_motion = value == "reduced"
	elif key == "graphics":
		track.apply_quality(_starting_quality())
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
		if rules.events[index].type == "pickup":
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


func _exit_tree() -> void:
	if is_instance_valid(audio_controls): audio_controls.queue_free()
