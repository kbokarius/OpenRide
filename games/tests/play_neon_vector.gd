extends SceneTree
## Real hub -> setup -> intro -> live input -> manual-pause rejection -> sensor loss/recovery -> end.
## Runs with a window for visual review, or headlessly for lifecycle checks.

var failures: Array[String] = []
var out := ""
var session: Node
var director: Node
var checks := 0
var storage_path := ""
var _saves: Array[int] = []


func _initialize() -> void:
	if "--hidden" in OS.get_cmdline_user_args():
		root.set_flag(ClassDB.class_get_integer_constant("Window", "FLAG_NO_FOCUS"), true)
		root.hide()
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_size(Vector2i(1920, 1008))
	storage_path = "user://neon_play_test_" + NeonRecords.new_id()
	NeonRecords.path = storage_path
	var game_options = load("res://framework/GameOptions.gd")
	game_options.path = storage_path + "_options.cfg"
	session = root.get_node("Session")
	director = session.director
	Engine.max_fps = 60
	change_scene_to_file("res://hub/Hub.tscn")
	await process_frame
	session._local.hub.begin_visit()
	await create_timer(1).timeout
	var hub: Node = current_scene
	await create_timer(0.5).timeout
	_check(hub.screen.get_script().resource_path.ends_with("NeonSetup.gd"), "dedicated setup appears")
	_check(load("res://games/Registry.gd").ids() == ["neon_vector"], "Lane Smash is the sole registered game")
	_check(hub.state.circuits.is_empty(), "circuits are unavailable")
	for duration in ["10", "15", "20", "30"]:
		hub.screen.length_picker.pick(duration)
		for tier in NeonRules.CURRENT_TIERS:
			hub.screen._pick_tier(tier)
			await process_frame
			await process_frame
			var controls: Array = hub.screen.length_picker.buttons + hub.screen.tier_buttons.values()
			var valid := true
			for i in controls.size():
				var rect: Rect2 = controls[i].get_global_rect()
				if duration == "10" and tier == "light": print("LAYOUT ", controls[i].text, " size=", controls[i].size, " rect=", rect, " font=", controls[i].get_theme_font_size("font_size"))
				valid = valid and rect.end.x <= 1865 and is_equal_approx(controls[i].size.y, 120.0) and controls[i].get_theme_font_size("font_size") == 34
				for j in range(i + 1, controls.size()):
					valid = valid and not rect.intersects(controls[j].get_global_rect())
			_check(valid, "stable controls " + duration + " / " + tier)
	if "--layout-only" in OS.get_cmdline_user_args():
		print("LAYOUT checks=", checks, " failures=", failures)
		quit(0 if failures.is_empty() else 1)
		return
	hub.screen.length_picker.pick("20")
	hub.screen._pick_tier("challenging")
	await _shot("setup")
	_check(hub.screen.track_buttons.size() == 25, "25 tracks are listed")
	hub.screen.length_picker.pick("15")
	_check(int(hub.screen.course.durationMs) == 900000, "15 minute duration selects matching track")
	hub.screen._random_track()
	_check(hub.screen.course.family == "random", "random track is generated")
	hub.screen._pick_track(0)
	hub.screen._open_extras()
	await _shot("style")
	hub.screen._close_panel()
	_seed_ghost(hub.screen)
	root.get_node("InputBus")._sim_resistance = NeonRules.band_center(int(hub.screen.course.events[0].laneIndex), hub.screen.tier)
	hub.screen.start_button.pressed.emit()
	await _until(func(): return director.phase_name() == "PLAYING", 15, "game starts")
	if director.game == null:
		quit(1)
		return
	var game: Node = director.game
	_check(game.game_id == "neon_vector", "right game is playing")
	_check(not root.get_node("Effort").enabled, "generic multiplier is off")
	await create_timer(10).timeout
	_check(game.rules.elapsed_ms >= 9000, "host clock advances during play")
	_check(game.rules.score_units > 0, "correct resistance earns continuous points")
	_check(game.track.ghost_visible and not game._ghost.is_empty(), "matching completed ghost loads into the real game")
	_check(root.get_node("Effort").whole_points(root.get_node("Effort").score) == game.rules.score_units / NeonRules.UNIT, "HUD score equals exact rules total")
	var jukebox: Node = root.get_node("Jukebox")
	# Headless runs leave the jukebox off (nothing loads or plays by itself there).
	_check(not jukebox.autoplay or (jukebox.current >= 0 and (jukebox.is_playing() or jukebox.is_loading())), "jukebox soundtrack is playing")
	_check(not jukebox.autoplay or root.get_node("AudioDirector").current_music_key().is_empty(), "no second soundtrack plays under the jukebox")
	game.change_option("music", "off")
	await create_timer(0.8).timeout
	_check(not root.get_node("AudioDirector").user_music_enabled, "music can be muted")
	game.change_option("music", "on")
	await create_timer(0.8).timeout
	_check(root.get_node("AudioDirector").user_music_enabled, "music can resume")
	game.audio_controls.pressed.emit()
	await create_timer(0.1).timeout
	var audio_elapsed: int = game.rules.elapsed_ms
	game.audio_controls.rows.sfx.segmented.pick("off")
	await create_timer(0.4).timeout
	_check(game.rules.elapsed_ms > audio_elapsed and not session.paused, "audio controls keep the ride running")
	_check(not root.get_node("AudioDirector").user_sfx_enabled, "ride effects switch mutes effects")
	_check(not root.get_node("AudioDirector").is_music_playing() or root.get_node("AudioDirector").user_music_enabled, "effects switch leaves music independent")
	await _shot("ride-audio")
	game.audio_controls.rows.sfx.segmented.pick("on")
	game.audio_controls.panel.hide()
	await _shot("riding")
	_check(not director.hud.pause_button.visible, "Pause is absent")
	_check(director.hud.end_button.text == "End Ride", "End Ride stays available")
	var elapsed: int = game.rules.elapsed_ms
	session.request_pause()
	await create_timer(0.5).timeout
	_check(not session.paused and game.rules.elapsed_ms > elapsed, "manual pause cannot stop an uninterrupted ride (paused=%s reason=%s)" % [session.paused, game.rules.pause_reason])
	director.pause_overlay.show_confirm()
	elapsed = game.rules.elapsed_ms
	await create_timer(0.5).timeout
	_check(game.rules.elapsed_ms > elapsed, "end confirmation does not pause the ride (paused=%s reason=%s)" % [session.paused, game.rules.pause_reason])
	director.pause_overlay.hide_confirm()
	root.get_node("InputBus")._sim_neon_sensors = false
	await create_timer(1.8).timeout
	_check(session.paused, "sensor silence freezes scoring")
	_check(not director.pause_overlay._resume_button.visible, "sensor recovery offers no manual Resume")
	await _shot("sensor-loss")
	elapsed = game.rules.elapsed_ms
	root.get_node("InputBus")._sim_neon_sensors = true
	await create_timer(0.3).timeout
	_check(session.paused, "a single fresh frame cannot bypass recovery gate")
	await create_timer(5).timeout
	_check(not session.paused and game.rules.elapsed_ms > elapsed, "healthy sensor data automatically resumes after countdown")

	session.request_end()
	await _until(func(): return director.summary_screen.visible, 5, "ended result appears")
	_check(int(director.results[0].stars) == 0, "incomplete ride earns no stars")
	_check(director.results[0].stats.neon.status == "ended", "partial result is labelled ended")
	await create_timer(1.5).timeout
	await _shot("ended")
	root.get_node("InputBus")._sim_neon_sensors = true
	for failure in failures:
		printerr("FAIL ", failure)
	var saved := NeonRecords.local_request({"action": "state"}, str(session.plan.get("rider_id", "guest")).trim_suffix(".0"))
	_check(saved.history.size() == 2 and saved.completions == 1, "partial history is saved without a completion")
	for task in _saves: WorkerThreadPool.wait_for_task_completion(task)
	print("NEON PLAY %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	for file in DirAccess.get_files_at(storage_path):
		DirAccess.remove_absolute(storage_path.path_join(file))
	DirAccess.remove_absolute(storage_path)
	DirAccess.remove_absolute(game_options.path)
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _until(condition: Callable, seconds: float, message: String) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(condition.call(), message)


func _shot(name: String) -> void:
	if out.is_empty():
		return
	await RenderingServer.frame_post_draw
	# Encode off the main thread: a slow PNG save must not look like a display stall to the ride.
	var picture := root.get_texture().get_image()
	var path := out.path_join(name + ".png")
	_saves.append(WorkerThreadPool.add_task(func(): picture.save_png(path)))


func _seed_ghost(setup: Node) -> void:
	var rules := NeonRules.new()
	rules.configure(setup.course, setup.tier, setup.reference_power)
	var id := NeonRecords.new_id()
	var rider: String = setup.rider_id
	var record := {"version": 1, "attemptId": id, "riderId": rider, "comparisonKey": rules.comparison_key(rider),
		"course": rules.course.duplicate(true), "result": rules.result("pending"), "ghost": []}
	_check(NeonRecords.local_request({"action": "save", "record": record}, rider).ok, "ghost attempt begins durably")
	for time in range(0, int(rules.course.durationMs), 50):
		var lane := int(rules.current_event().get("laneIndex", 0))
		rules.push_sample({"t": time, "seq": time + 1, "cadence": 80, "power": setup.reference_power, "resistance": NeonRules.band_center(lane, setup.tier)})
		rules.advance(time + 50)
	record.result = rules.result()
	record.ghost = rules.ghost_trace
	_check(NeonRecords.local_request({"action": "save", "record": record}, rider).ok, "completed ghost persists")
