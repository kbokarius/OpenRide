extends SceneTree
## Still-frame look review with the real renderer, HUD and deterministic simulated sensors.
## Never reads or writes personal ride history or settings.
##
##   godot --path games -s res://tests/capture_lane_smash_look.gd -- --out=/abs/dir \
##       [--course=ls_15_01] [--begin=0] [--frames=300] [--every=15] [--size=1280x720] \
##       [--scenario=follow|bomb|hit|pass|steering] [--motion=reduced] [--tier=challenging] [--ghost] \
##       [--timeline] [--lane=N] [--rpm=N] [--quality=high|balanced|performance] [--music]
##
## `--music` drives the jukebox's analysis values with a synthetic 128 BPM track (no audio
## plays), so the music-reactive scenery can be reviewed deterministically.
##
## `--begin` is the active ride time in ms to fast-forward to before rendering; `--timeline`
## prints the course's sections, bombs and attacks, then quits.

var failures: Array[String] = []

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.hide()
	_run.call_deferred()


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name): return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	var out := _arg("out", "user://look-review")
	var course_id := _arg("course", "ls_15_01")
	var begin := int(_arg("begin", "0"))
	var frames := int(_arg("frames", "300"))
	var every := maxi(1, int(_arg("every", "15")))
	var scenario := _arg("scenario", "follow")
	var tier := _arg("tier", "challenging")
	var fixed_lane := int(_arg("lane", "-1"))
	var fixed_rpm := float(_arg("rpm", "0"))
	var dimensions := _arg("size", "1280x720").split("x")
	var window := Vector2i(int(dimensions[0]), int(dimensions[1]))
	var flags := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(out)
	var rules := NeonRules.new()
	var errors := rules.configure(NeonCourse.load_course(course_id), tier, 150)
	if not errors.is_empty():
		printerr("LOOK course failed: ", errors)
		quit(1)
		return
	if "--timeline" in flags:
		_timeline(rules)
		quit()
		return
	root.mode = Window.MODE_WINDOWED
	root.size = window
	Engine.max_fps = 60
	var options = load("res://framework/GameOptions.gd")
	options.path = "user://look_" + NeonRecords.new_id() + ".cfg"
	var duration := int(rules.course.durationMs)
	var ghost_trace: Array = []
	if "--ghost" in flags:
		var previous := NeonRules.new()
		previous.configure(rules.course, tier, 150)
		for t in range(0, duration, 50):
			_sample(previous, t, "follow", -1, 92.0)
			previous.advance(t + 50)
		ghost_trace = previous.ghost_trace
	for t in range(0, begin, 50):
		_sample(rules, t, scenario, fixed_lane, fixed_rpm)
		rules.advance(t + 50)
	var track: Node = load("res://games/neon_vector/NeonTrack.gd").new()
	track.rules = rules
	track.world_id = rules.course.theme
	track.reduced_motion = _arg("motion", "full") == "reduced"
	track.visual_lane = maxi(0, rules.selected_lane)
	track._completion_cursor = rules._event_cursor
	var replay: Node = load("res://games/neon_vector/NeonVector.gd").new()
	replay.rules = rules
	replay.track = track
	replay._ghost = ghost_trace
	root.add_child(track)
	track.apply_quality(_arg("quality", "high"))
	# `--aa=fxaa|msaa2|msaa4` overrides the tier's anti-aliasing, to compare them.
	var aa := _arg("aa", "")
	if aa == "fxaa": track.view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	elif aa == "msaa2": track.view.msaa_3d = Viewport.MSAA_2X
	elif aa == "msaa4": track.view.msaa_3d = Viewport.MSAA_4X
	elif aa == "none": track.view.msaa_3d = Viewport.MSAA_DISABLED
	var jukebox: Node = root.get_node_or_null("Jukebox")
	var music := "--music" in flags and jukebox != null
	if music: jukebox.frozen = true
	var hud: Node = load("res://framework/hud/Hud.gd").new()
	root.add_child(hud)
	var info: RefCounted = load("res://games/Registry.gd").info("neon_vector")
	hud.setup(info, {"duration_sec": duration / 1000, "effort": false})
	hud.set_process(false)
	hud.timer.set_process(false)
	hud.metrics.set_process(false)
	hud.set_skin(load("res://games/neon_vector/NeonVector.gd").hud_skin())
	var audio_controls: Node = load("res://games/neon_vector/LaneSmashAudioControls.gd").new()
	audio_controls.info = info
	var buttons: Node = hud.end_button.get_parent()
	buttons.add_child(audio_controls)
	buttons.move_child(audio_controls, hud.end_button.get_index())
	var status: Node = load("res://games/neon_vector/NeonStatus.gd").new()
	status.rules = rules
	hud.add_widget(status)
	status.set_process(false)
	for i in 70:
		track.update_view(0)
		await process_frame
	track.space._warming = false
	root.mode = Window.MODE_WINDOWED
	root.size = window
	await process_frame
	var next_sample := begin
	var last_second := -1
	var notes := {}
	var last_kind := ""
	var last_beat := -1
	for frame in frames:
		var target := begin + floori((frame + 1) * 1000.0 / 30 / 10) * 10
		while next_sample < target:
			_sample(rules, next_sample, scenario, fixed_lane, fixed_rpm)
			next_sample += 50
		rules.advance(target)
		replay._update_ghost()
		if music:
			var seconds := frame / 30.0
			var kick := exp(-fposmod(seconds * 128.0 / 60.0, 1.0) * 5.0)
			jukebox.beat = kick
			jukebox.bass = 0.35 + 0.6 * kick
			jukebox.mid = 0.4 + 0.3 * sin(seconds * 0.9)
			jukebox.treble = 0.35 + 0.3 * sin(seconds * 2.3 + 1.0)
			jukebox.level = 0.55 + 0.3 * kick
			jukebox.flow = seconds * 0.9
			# The eight live bands and the kick counter, which the road's seams read.
			for b in jukebox.bands.size():
				jukebox.bands[b] = clampf(0.35 + 0.6 * kick if b < 2 else 0.42 + 0.34 * sin(seconds * (0.9 + b * 0.35) + b), 0.0, 1.0)
			var beat_index := floori(seconds * 128.0 / 60.0)
			if beat_index != last_beat:
				last_beat = beat_index
				jukebox.beat_count += 1
		track.update_view(1.0 / 30)
		status.refresh()
		status._process(1.0 / 30)
		root.get_node("Effort")._meter.score = float(rules.score_units) / NeonRules.UNIT
		hud._process(1.0 / 30)
		if rules.elapsed_ms / 1000 != last_second:
			last_second = rules.elapsed_ms / 1000
			var left := maxi(0, duration / 1000 - last_second)
			hud.timer.set_value("%d:%02d" % [left / 60, left % 60])
			for pair in [[hud.metrics._rpm, "cadence"], [hud.metrics._watts, "power"], [hud.metrics._resistance, "resistance"]]:
				pair[0].text = str(roundi(float(rules.latest.get(pair[1], 0))))
		if track._completion_age < 0.05 and track._completion_kind != last_kind:
			notes["%s@%d" % [track._completion_kind, frame]] = track._completion_text
		last_kind = track._completion_kind if track._completion_age < 0.05 else ""
		await RenderingServer.frame_post_draw
		if frame % every == 0 or frame == frames - 1:
			root.get_texture().get_image().save_png(out.path_join("f%04d.png" % frame))
	# `--passes` also saves the off-screen sky and the bloom's last pass, as the picture reads them.
	if "--passes" in flags:
		track.space._structures.pass_view.get_texture().get_image().save_png(out.path_join("pass_sky.png"))
		track._bloom_views[-1].get_texture().get_image().save_png(out.path_join("pass_bloom.png"))
	if not rules.pause_reason.is_empty(): failures.append("Unexpected pause: " + rules.pause_reason)
	print("LOOK course=", course_id, " begin_ms=", begin, " end_ms=", rules.elapsed_ms, " score=", rules.score_units / NeonRules.UNIT,
		" popups=", notes, " failures=", failures)
	replay.free()
	track.queue_free()
	hud.queue_free()
	DirAccess.remove_absolute(options.path)
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _timeline(rules: NeonRules) -> void:
	var rows: Array[String] = []
	for event: Dictionary in rules.course.events:
		if int(event.startMs) > 240000: break
		rows.append("%7d-%7d %-6s lane %d" % [event.startMs, event.endMs, event.type, int(event.laneIndex) + 1])
	print("LOOK events (first four minutes):\n  ", "\n  ".join(rows))
	rows.clear()
	for hazard: Dictionary in rules.course.get("hazards", []): rows.append("%d lane %d" % [hazard.hitMs, int(hazard.laneIndex) + 1])
	print("LOOK bombs: ", ", ".join(rows))
	rows.clear()
	for barrage: Dictionary in rules.course.get("barrages", []): rows.append("%d-%d slots %s" % [barrage.startMs, barrage.endMs, barrage.slots])
	print("LOOK attacks: ", ", ".join(rows))
	print("LOOK theme=", rules.course.get("theme"), " background=", rules.course.get("background"), " duration_ms=", rules.course.durationMs)


func _sample(rules: NeonRules, t: int, scenario: String, fixed_lane: int, fixed_rpm: float) -> void:
	var event := rules.current_event()
	var lane := int(event.get("laneIndex", 0))
	var rpm := 96.0
	if event.get("type", "") == "hold": rpm = (float(event.cadenceMin) + float(event.cadenceMax)) * 0.5
	if event.get("type", "") == "burst": rpm = 118.0 + 10.0 * sin(t * 0.001)
	if rules.barrage.active:
		lane = 0
		rpm = 80.0
		var shot := rules.barrage.current_shot()
		if not shot.is_empty():
			var blend := clampf((t - int(shot.lockMs) - 2000) / 4000.0, 0, 1)
			rpm = float(shot.baselineRpm) if scenario == "hit" else lerpf(float(shot.baselineRpm), float(shot.targetRpm), blend)
	elif scenario == "bomb":
		for hazard: Dictionary in rules.course.get("hazards", []):
			if rules.road_time_ms() >= int(hazard.hitMs) - 2600 and rules.road_time_ms() <= int(hazard.hitMs) + 400:
				lane = int(hazard.laneIndex)
	if fixed_lane >= 0: lane = fixed_lane
	if fixed_rpm > 0: rpm = fixed_rpm
	var resistance := NeonRules.band(lane, rules.tier).x + 3
	# A repeatable knob sweep around the requested lane: wrong lane, threshold, full band.
	# Only this test harness simulates it; the production controller reads real sensors.
	if scenario == "steering": resistance += roundi(8.0 * sin(t * 0.0012))
	var fixed_resistance := int(_arg("resistance", "-1"))
	if fixed_resistance >= 0: resistance = fixed_resistance
	var watts := roundi(rpm * (0.3 + resistance * 0.045))
	rules.push_sample({"t": t, "seq": t + 1, "cadence": rpm, "power": watts, "resistance": resistance})
