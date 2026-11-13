extends SceneTree
## Visible, isolated sensor simulator. Never writes demonstration scores into real history.
## Run with --out=/absolute/path to capture frames and a setup screenshot for review.

var session: Node
var input_bus: Node
var out := ""
var frame_index := 0
var last_capture := -1000
var seen := {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
	NeonRecords.path = "user://lane_smash_demo_" + NeonRecords.new_id()
	var options = load("res://framework/GameOptions.gd")
	options.path = NeonRecords.path + "_options.cfg"
	DisplayServer.window_set_size(Vector2i(1440, 810))
	DisplayServer.window_set_title("Lane Smash — simulated ride with best-ride ghost")
	Engine.max_fps = 60
	session = root.get_node("Session")
	input_bus = root.get_node("InputBus")
	change_scene_to_file("res://hub/Hub.tscn")
	await process_frame
	session._local.hub.begin_visit()
	await create_timer(1).timeout
	current_scene.nav.push("game", {"game_id": "neon_vector"})
	await create_timer(0.5).timeout
	var setup: Node = current_scene.screen
	setup.length_picker.pick("15")
	setup._pick_track(9)
	_seed_best(setup)
	await setup._load_progress()
	setup.track_scroll.scroll_vertical = 9 * 194
	await create_timer(0.4).timeout
	if not out.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("setup.png"))
	input_bus._sim_resistance = NeonRules.band(int(setup.course.events[0].laneIndex), setup.tier).x + 3
	input_bus._sim_cadence = 80
	setup.start_button.pressed.emit()
	while session.director.game == null or session.director.phase_name() != "PLAYING":
		await process_frame
	var game: Node = session.director.game
	while is_instance_valid(game) and session.director.game == game:
		var t: int = game.rules.elapsed_ms
		var cycle := fmod(t / 1000.0, 140.0)
		# The saved rider holds 100 rpm; this rider falls back, passes, then falls back again.
		var rpm := 80.0 if cycle < 12 else (140.0 if cycle < 30 else (60.0 if cycle < 80 else 130.0))
		input_bus._sim_cadence = move_toward(input_bus._sim_cadence, rpm, 1.5)
		var event: Dictionary = game.rules.current_event()
		input_bus._sim_resistance = NeonRules.band(int(event.get("laneIndex", game.rules.selected_lane)), game.rules.tier).x + 3
		if t > 2000 and not game._ghost.is_empty():
			var gap: float = game.track.ghost_gap
			var state := "near" if game.track.space.ghost.visible else ("behind" if gap < -5 else "far_ahead" if gap >= 85 else "alongside")
			if not seen.has(state):
				seen[state] = true
				print("LANE SMASH DEMO ghost=", state, " gap_m=", snappedf(gap, 0.1), " score=", game.rules.score_units / NeonRules.UNIT)
		if not out.is_empty() and t >= 5000 and t < 95000 and t - last_capture >= 100:
			last_capture = t
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			picture.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
			picture.save_jpg(out.path_join("frames/%05d.jpg" % frame_index), 0.88)
			frame_index += 1
			if not seen.has("screenshot") and game.track.space.ghost.visible and t > 10000:
				seen.screenshot = true
				picture.save_png(out.path_join("ghost.png"))
		if t >= 95000 and not seen.has("captured"):
			seen.captured = true
			print("LANE SMASH DEMO capture complete frames=", frame_index, " impacts=", game.track.space.impact_count)
		await process_frame

func _seed_best(setup: Node) -> void:
	var rules := NeonRules.new()
	rules.configure(setup.course, setup.tier, 150)
	var rider: String = setup.rider_id
	var record := {"version": 1, "attemptId": NeonRecords.new_id(), "riderId": rider,
		"comparisonKey": rules.comparison_key(rider), "course": rules.course.duplicate(true),
		"result": rules.result("pending"), "ghost": []}
	assert(NeonRecords.local_request({"action": "save", "record": record}, rider).ok)
	for t in range(0, int(setup.course.durationMs), 50):
		var event := rules.current_event()
		rules.push_sample({"t": t, "seq": t + 1, "cadence": 100, "power": 180,
			"resistance": NeonRules.band(int(event.get("laneIndex", 0)), setup.tier).x + 3})
		rules.advance(t + 50)
	record.result = rules.result()
	record.ghost = rules.ghost_trace
	assert(NeonRecords.local_request({"action": "save", "record": record}, rider).ok)
	print("LANE SMASH DEMO seeded completed best score=", rules.score_units / NeonRules.UNIT)
