extends SceneTree
## Isolated synthetic Iron Horizon / Hard record from course 12. Exercises real menu,
## async preview lookup and replay rendering without touching personal history/settings.
var out := ""

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	if out.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(out)
	NeonRecords.path = "user://benchmark_capture_" + NeonRecords.new_id()
	var options = load("res://framework/GameOptions.gd")
	options.path = NeonRecords.path + "_options.cfg"
	var hub_prefs = load("res://hub/HubPrefs.gd")
	hub_prefs.path = NeonRecords.path + "_hub.cfg"
	var course := NeonCourse.load_course("ls_20_05")
	course.courseVersion = 12
	course.generatorVersion = 9
	course.hazards = LaneSmashHazards.generate_dense(course.events)
	var past := NeonRules.new()
	assert(past.configure(course, "hard", 150).is_empty())
	var rider := str(root.get_node("Session")._local.hub.rider.id)
	var record := {"version": 1, "attemptId": NeonRecords.new_id(), "riderId": rider,
		"comparisonKey": past.comparison_key(rider), "course": course, "result": past.result("pending"), "ghost": []}
	assert(NeonRecords.local_request({"action": "save", "record": record}, rider).ok)
	past.elapsed_ms = int(course.durationMs)
	past.score_units = 154321 * NeonRules.UNIT
	record.result = past.result("completed")
	# Synthetic 10 Hz trace, 8 m/s and lane 3 throughout. Fixtures are never real records.
	for t in range(100, past.elapsed_ms + 1, 100):
		record.ghost.append([t, 2, floori(float(past.score_units) * t / past.elapsed_ms), t * 8])
	assert(NeonRecords.local_request({"action": "save", "record": record}, rider).ok)
	root.size = Vector2i(1280, 720)
	root.show()
	Engine.max_fps = 60
	change_scene_to_file("res://hub/Hub.tscn")
	await process_frame
	root.get_node("Session")._local.hub.begin_visit()
	for i in 90: await process_frame
	var setup: Node = current_scene.screen
	setup._pick_tier("hard")
	setup._pick_track(4)
	setup.track_scroll.scroll_vertical = int(setup.track_buttons[4].position.y)
	for i in 6: await process_frame
	for card in setup.track_buttons:
		for child in card.get_children():
			if child is Label:
				assert(child.position.x + child.size.x <= card.size.x, "Overflow: " + child.text)
	assert(setup.score_label.text.contains("154,321"))
	await _capture("menu")
	setup._start()
	var director: Node = root.get_node("Session").director
	for i in 180:
		await process_frame
		if director.game != null and director.intro_card.visible and not director.game._benchmark_loading: break
	assert(director.intro_card.visible)
	director.set_process(false)
	var game: Node = director.game
	assert(game._benchmark_error.is_empty())
	assert(game._ghost.size() == 12000)
	assert(game._benchmark_card.target_label.text.contains("154,322"))
	# Slow IO must not consume the rider's chance to read the benchmark.
	var left: float = director._intro_left
	game._benchmark_loading = true
	director._process(1.0)
	assert(director._intro_left == left)
	game._benchmark_loading = false
	await _capture("preview")
	for count in [6, 3, 1]:
		director.intro_card.set_time_left(count)
		for i in 4: await process_frame
		assert(director.intro_card._card.size.is_equal_approx(Vector2(1320, 984)))
	director.intro_card.hide()
	game.track.space._warming = false
	game.rules.elapsed_ms = 30000
	game.rules.latest = {"cadence": 80, "power": 180, "resistance": 42}
	game.rules.selected_lane = 2
	game.track.visual_lane = 2
	for item: Array in [["nearby", 15.0, 2.0, true], ["alongside", 0.0, 3.0, true], ["overlap", 0.0, 2.0, false], ["ahead", 200.0, 2.0, false], ["behind", -200.0, 2.0, false]]:
		game.rules.distance_units = roundi((240.0 - float(item[1])) * 1000000.0)
		game.track._text_second = -1
		for i in 20:
			game._update_ghost()
			game.track.visual_lane = float(item[2])
			game.track.update_view(0)
			game.status.refresh()
			await process_frame
		# The steering controller may retain the actual resistance position; set the final
		# render pose explicitly to exercise same-lane overlap versus a neighbouring lane.
		game.track.space.update_view(game.rules, 0, float(item[2]), game.track.ghost_lane, game.track.ghost_visible, "")
		assert(game.track.space.ghost.visible == bool(item[3]), "Ghost visibility: " + item[0])
		if item[0] != "overlap": await _capture(item[0])
	# A damaged recording ends at 30.5 s. Its last half-second fades while still following
	# recorded motion; at the endpoint both the model and stale comparison disappear.
	game._ghost = game._ghost.slice(0, 305)
	for item: Array in [["fading", 30250, 0.5], ["ended", 30500, 0.0]]:
		game.rules.elapsed_ms = int(item[1])
		game.rules.distance_units = roundi((float(item[1]) * 0.008 - 15.0) * 1000000.0)
		game.track._text_second = -1
		game._update_ghost()
		game.track.update_view(0)
		game.track.space.update_view(game.rules, 0, 2.0, game.track.ghost_lane, game.track.ghost_visible, "")
		assert(is_equal_approx(game.track.ghost_opacity, float(item[2])))
		assert(game.track.space.ghost.visible == (float(item[2]) > 0.0))
		if item[0] == "fading":
			# Portal/curve visibility may already attenuate the model; coverage multiplies it.
			var faded: float = game.track.space.ghost._opacity
			game.track.space.ghost_opacity = 1.0
			game.track.space.update_view(game.rules, 0, 2.0, game.track.ghost_lane, true, "")
			assert(game.track.space.ghost._opacity > 0.0)
			assert(is_equal_approx(faded, game.track.space.ghost._opacity * 0.5))
			game.track.space.ghost_opacity = 0.5
			game.track.space.update_view(game.rules, 0, 2.0, game.track.ghost_lane, true, "")
		else:
			assert(game.track._ghost_text == "GHOST RECORDING ENDED" and game.track.ghost_cadence == 0.0)
		await _capture(item[0])
	game._refresh_benchmark_card()
	director.intro_card.show()
	director.intro_card.set_time_left(6)
	assert(game._benchmark_card.detail_label.text.contains("Ghost recording is incomplete"))
	await _capture("incomplete_preview")
	print("BENCHMARK CAPTURE PASS: earlier-version menu/preview, full trace, near/alongside/overlap/far visibility, incomplete preview, 50% fade and ended ghost")
	for file in DirAccess.get_files_at(NeonRecords.path): DirAccess.remove_absolute(NeonRecords.path.path_join(file))
	DirAccess.remove_absolute(NeonRecords.path)
	DirAccess.remove_absolute(options.path)
	DirAccess.remove_absolute(hub_prefs.path)
	game.queue_free()
	director.game = null
	for i in 4: await process_frame
	quit()


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
