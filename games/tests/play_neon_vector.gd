extends SceneTree
## Real hub -> setup -> intro -> live timestamped input -> pause -> resume -> loss -> end.
## Runs with a window for visual review, or headlessly for lifecycle checks.

var failures: Array[String] = []
var out := ""
var session: Node
var director: Node
var checks := 0
var storage_path := ""


func _initialize() -> void:
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
	session = root.get_node("Session")
	director = session.director
	Engine.max_fps = 60
	change_scene_to_file("res://hub/Hub.tscn")
	await process_frame
	session._local.hub.begin_visit()
	await create_timer(1).timeout
	var hub: Node = current_scene
	hub.nav.push("game", {"game_id": "neon_vector"})
	await create_timer(0.5).timeout
	_check(hub.screen.get_script().resource_path.ends_with("NeonSetup.gd"), "dedicated setup appears")
	await _shot("setup")
	hub.screen._open_power()
	await _shot("power")
	hub.screen._close_panel()
	hub.screen._open_extras()
	await _shot("style")
	hub.screen._close_panel()
	_seed_ghost(hub.screen)
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
	_check(game.rules.score_units > 0, "correct resistance earns the first pickup")
	_check(game.track.ghost_visible and not game._ghost.is_empty(), "matching completed ghost loads into the real game")
	_check(root.get_node("Effort").whole_points(root.get_node("Effort").score) == game.rules.score_units / NeonRules.UNIT, "HUD score equals exact rules total")
	await _shot("riding")
	session.request_pause()
	await process_frame
	var elapsed: int = game.rules.elapsed_ms
	var score: int = game.rules.score_units
	await create_timer(0.5).timeout
	_check(game.rules.elapsed_ms == elapsed and game.rules.score_units == score, "manual pause freezes clock and score")
	await _shot("paused")
	session.request_resume()
	await create_timer(2).timeout
	_check(game.rules.elapsed_ms == elapsed, "resume countdown is unscored")
	await create_timer(2).timeout
	_check(game.rules.elapsed_ms > elapsed, "resume restarts course after countdown")
	root.get_node("InputBus")._sim_neon_sensors = false
	await create_timer(1.8).timeout
	_check(session.paused, "sensor silence pauses the shared session")
	await _shot("sensor-loss")
	session.request_resume()
	await process_frame
	_check(session.paused, "stale sensors block Resume")
	root.get_node("InputBus")._sim_neon_sensors = true
	await create_timer(0.3).timeout
	session.request_resume()
	await process_frame
	_check(session.paused, "a single fresh frame does not bypass recovery gate")
	await create_timer(1.0).timeout
	_check(game.resume_block_reason().is_empty(), "one second of fresh data enables Resume")
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
	_check(saved.history.size() == 2 and saved.completions == 1, "partial history is saved without a completion or unlock")
	print("NEON PLAY %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	for file in DirAccess.get_files_at(storage_path):
		DirAccess.remove_absolute(storage_path.path_join(file))
	DirAccess.remove_absolute(storage_path)
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
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))


func _seed_ghost(setup: Node) -> void:
	var rules := NeonRules.new()
	rules.configure(setup.course, setup.tier, setup.reference_power)
	var id := NeonRecords.new_id()
	var rider: String = setup.rider_id
	var record := {"version": 1, "attemptId": id, "riderId": rider, "comparisonKey": rules.comparison_key(rider),
		"course": rules.course.duplicate(true), "result": rules.result("pending"), "ghost": []}
	_check(NeonRecords.local_request({"action": "save", "record": record}, rider).ok, "ghost attempt begins durably")
	var event_index := 0
	for time in range(0, int(rules.course.durationMs), 50):
		while event_index < rules.course.events.size() - 1 and int(rules.course.events[event_index].endMs) <= time:
			event_index += 1
		var lane := int(NeonCourse.choices(rules.course.events[event_index])[-1].laneIndex)
		rules.push_sample({"t": time, "seq": time + 1, "cadence": 80, "power": setup.reference_power, "resistance": NeonRules.band(lane, setup.tier).x + 3})
		rules.advance(time + 50)
	record.result = rules.result()
	record.ghost = rules.ghost_trace
	_check(NeonRecords.local_request({"action": "save", "record": record}, rider).ok, "completed ghost persists")
