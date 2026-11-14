extends SceneTree
## Real-renderer showcase; --seconds=55 captures standard targets before the Incoming Fire chapter.
var failures: Array[String] = []
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.hide()
	_run.call_deferred()

func _run() -> void:
	var out := "user://sections-review"
	var seconds := 55
	var movie := "--movie" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--seconds="): seconds = int(arg.trim_prefix("--seconds="))
	DirAccess.make_dir_recursive_absolute(out)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	Engine.max_fps = 60
	var rules := NeonRules.new()
	assert(rules.configure(NeonCourse.load_course("ls_15_01"), "challenging", 150).is_empty())
	var hazard: Dictionary = rules.course.hazards[0]
	var begin := 0
	var options = load("res://framework/GameOptions.gd")
	options.path = "user://showcase_" + NeonRecords.new_id() + ".cfg"
	var previous := NeonRules.new()
	previous.configure(rules.course, rules.tier, 150)
	for t in range(0, int(previous.course.durationMs), 50):
		_sample(previous, t, false)
		previous.advance(t + 50)
	assert(previous.result().status == "completed")
	var track: Node = load("res://games/neon_vector/NeonTrack.gd").new()
	track.rules = rules
	track.world_id = rules.course.theme
	track.visual_lane = 0
	track._completion_cursor = rules._event_cursor
	var replay: Node = load("res://games/neon_vector/NeonVector.gd").new()
	replay.rules = rules
	replay.track = track
	replay._ghost = previous.ghost_trace
	root.add_child(track)
	var hud: Node = load("res://framework/hud/Hud.gd").new()
	root.add_child(hud)
	var info: RefCounted = load("res://games/Registry.gd").info("neon_vector")
	hud.setup(info, {"duration_sec": 900, "effort": false})
	hud.set_process(false)
	hud.timer.set_process(false)
	hud.metrics.set_process(false)
	var skin: Dictionary = load("res://framework/ui/GameTheme.gd").new(Color("79b8d5"), Color("0b1019"), 0.0, false, true).hud_skin()
	skin.manual_pause = false
	skin.score_rollup = true
	skin.text_interval = 1.0
	hud.set_skin(skin)
	var audio_controls: Node = load("res://games/neon_vector/LaneSmashAudioControls.gd").new()
	audio_controls.info = info
	var buttons: Node = hud.end_button.get_parent()
	buttons.add_child(audio_controls)
	buttons.move_child(audio_controls, hud.end_button.get_index())
	var status: Node = load("res://games/neon_vector/NeonStatus.gd").new()
	status.rules = rules
	hud.add_widget(status)
	status.set_process(false)
	var sounds: Node = load("res://games/neon_vector/LaneSmashSound.gd").new()
	sounds.track = track
	track.add_child(sounds)
	sounds.active = true
	replay._apply_music()
	var sound_counts := {}
	root.get_node("AudioDirector").sound_played.connect(func(key: String, _bus: String): sound_counts[key] = int(sound_counts.get(key, 0)) + 1)

	for i in 60:
		track.update_view(0)
		await process_frame
	track.space._warming = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await process_frame
	var next_sample := begin
	var saw_popup := false
	var last_second := -1
	var moments := {}
	for frame in seconds * 30:
		var target := begin + floori((frame + 1) * 1000.0 / 30 / 10) * 10
		while next_sample < target:
			_sample(rules, next_sample, true)
			next_sample += 50
		rules.advance(target)
		replay._update_ghost()
		track.update_view(1.0 / 30)
		status.refresh()
		status._process(1.0 / 30)
		sounds.update_audio()
		root.get_node("Effort")._meter.score = float(rules.score_units) / NeonRules.UNIT
		hud._process(1.0 / 30)
		if rules.elapsed_ms / 1000 != last_second:
			last_second = rules.elapsed_ms / 1000
			hud.timer.set_value("%d:%02d" % [(900 - last_second) / 60, (900 - last_second) % 60])
			for pair in [[hud.metrics._rpm, "cadence"], [hud.metrics._watts, "power"], [hud.metrics._resistance, "resistance"]]:
				pair[0].text = str(roundi(float(rules.latest.get(pair[1], 0))))
		for kind in ["cruise", "hold", "burst"]:
			if not moments.has(kind) and int(track.completed_sections[kind]) > 0: moments[kind] = frame / 30.0
		if track._completion_kind == "bomb" and not moments.has("bomb"): moments.bomb = frame / 30.0
		if track._completion_kind == "bomb" and track._completion_text == "−%s" % HudTheme.grouped(100 * rules.score_scale): saw_popup = true
		await RenderingServer.frame_post_draw
		if not movie: root.get_texture().get_image().save_jpg(out.path_join("frame-%04d.jpg" % frame), 0.93)
		if frame % 900 == 0: print("SHOWCASE progress_s=", frame / 30)
	if not rules.pause_reason.is_empty(): failures.append("Unexpected pause")
	for kind in ["cruise", "hold", "burst"]:
		if not moments.has(kind): failures.append("Missing " + kind)
	var report := FileAccess.open(out.path_join("moments.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(moments, "  "))
	report.close()
	print("SHOWCASE penalty=", rules.penalty_units / NeonRules.UNIT, " moments=", moments, " failures=", failures)
	print("SHOWCASE sounds=", sound_counts)
	replay.free()
	track.queue_free()
	hud.queue_free()
	DirAccess.remove_absolute(options.path)
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _sample(rules: NeonRules, t: int, live: bool) -> void:
	var event := rules.current_event()
	var lane := int(event.get("laneIndex", 0))
	var rpm := 132 if live else 136
	if event.get("type", "") == "hold": rpm = int(event.cadenceMin) + (10 if live else 12)
	if event.get("type", "") == "burst": rpm = roundi(125 + 15 * sin(t * 0.001)) if live else 135
	if rules.barrage.active:
		lane = 0
		var shot := rules.barrage.current_shot()
		if not shot.is_empty():
			var blend := clampf((t - int(shot.lockMs) - 2000) / 4000.0, 0, 1)
			rpm = roundi(lerpf(float(shot.baselineRpm), float(shot.targetRpm), blend))
	if live and not rules.barrage.active:
		var bomb: Dictionary = rules.course.hazards[0]
		if rules.road_time_ms() >= int(bomb.hitMs) - 2200 and rules.road_time_ms() <= int(bomb.hitMs) + 1000:
			lane = int(bomb.laneIndex)
	var resistance := NeonRules.band(lane, rules.tier).x + 3
	var watts := roundi(rpm * (0.3 + resistance * 0.045))
	rules.push_sample({"t": t, "seq": t + 1, "cadence": rpm, "power": watts, "resistance": resistance})
