extends SceneTree
## Visible, isolated sensor simulator. Never writes demonstration scores into real history.
## Run with --out=/absolute/path to capture frames and a setup screenshot for review.

var session: Node
var input_bus: Node
var out := ""
var frame_index := 0
var next_capture := 0
var timestamps: Array[int] = []
var seen := {}
var upside_down_frames := 0
var portal_error := 0.0
var previous_portal := Vector2.ZERO
var max_portal_step := 0.0
var min_portal := Vector2.ONE
var max_portal := Vector2.ZERO

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
	await create_timer(0.5).timeout
	var setup: Node = current_scene.screen
	setup.length_picker.pick("15")
	setup._pick_track(0)
	_seed_best(setup)
	await setup._load_progress()
	setup.track_scroll.scroll_vertical = 0
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
		var space: NeonSpace = game.track.space
		if space.road_basis(space.distance).y.y < -0.9: upside_down_frames += 1
		var tip := space.camera.to_local(space.path(space.portal_distance))
		var expected := Vector2(tip.x, tip.y) / maxf(0.2, -tip.z) * 0.7
		var sky_basis: Basis = space._structures.portal_basis
		var core := space.camera.to_local(space.camera.position - sky_basis.z * 100)
		var actual := Vector2(core.x, core.y) / maxf(0.2, -core.z) * 0.7
		portal_error = maxf(portal_error, expected.distance_to(actual))
		if t > 1000: max_portal_step = maxf(max_portal_step, previous_portal.distance_to(actual))
		previous_portal = actual
		var event: Dictionary = game.rules.current_event()
		var kind := str(event.get("type", "cruise"))
		var rpm := 85.0 if t < 17000 else 125.0
		if kind == "hold": rpm = (float(event.cadenceMin) + float(event.cadenceMax)) / 2.0
		if kind == "burst": rpm = 140.0
		input_bus._sim_cadence = move_toward(input_bus._sim_cadence, rpm, 3.0)
		input_bus._sim_resistance = NeonRules.band(int(event.get("laneIndex", game.rules.selected_lane)), game.rules.tier).x + 3
		if t > 2000 and not game._ghost.is_empty():
			var gap: float = game.track.ghost_gap
			var state := "near" if game.track.space.ghost.visible else ("behind" if gap < -5 else "far_ahead" if gap >= 85 else "alongside")
			if not seen.has(state):
				seen[state] = true
				print("LANE SMASH DEMO ghost=", state, " gap_m=", snappedf(gap, 0.1), " score=", game.rules.score_units / NeonRules.UNIT)
		if not out.is_empty() and t < 120000 and t >= next_capture:
			next_capture += 50
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			picture.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
			picture.save_jpg(out.path_join("frames/%05d.jpg" % frame_index), 0.90)
			timestamps.append(t)
			frame_index += 1
			if not seen.has("screenshot") and game.track.space.ghost.visible and t > 10000:
				seen.screenshot = true
				picture.save_png(out.path_join("ghost.png"))
			var uv := space.camera.unproject_position(space.path(space.portal_distance)) / space.get_viewport().get_visible_rect().size
			min_portal = min_portal.min(uv)
			max_portal = max_portal.max(uv)
			if space.road_basis(space.distance).y.y < -0.9 and not seen.has("inverted"):
				seen.inverted = true
				picture.save_png(out.path_join("inverted.png"))
			if kind == "burst" and space.sections.zones.has(event.eventId):
				var charge: float = space.sections.zones[event.eventId].charge
				if charge > 0.6 and not seen.has("power_charged"):
					seen.power_charged = true
					picture.save_png(out.path_join("power_charged.png"))
			if game.track._completion_age < 0.3 and game.track._completion_age > 0.15:
				var key: String = game.track._completion_kind + "_complete"
				if not seen.has(key):
					seen[key] = true
					picture.save_png(out.path_join(key + ".png"))
		if t >= 120000:
			if not out.is_empty():
				var timing := FileAccess.open(out.path_join("timestamps.json"), FileAccess.WRITE)
				timing.store_string(JSON.stringify(timestamps))
				timing.close()
			print("LANE SMASH DEMO capture complete frames=", frame_index, " impacts=", game.track.space.impact_count, " sections=", game.track.completed_sections, " inverted_frames=", upside_down_frames, " portal_error=", portal_error, " largest_portal_step=", max_portal_step, " portal_min=", min_portal, " portal_max=", max_portal)
			assert(upside_down_frames > 30 and portal_error < 0.00001)
			assert(game.track.completed_sections.cruise > 0 and game.track.completed_sections.hold > 0 and game.track.completed_sections.burst > 0)
			session.request_end()
			break
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
		rules.push_sample({"t": t, "seq": t + 1, "cadence": (int(event.cadenceMin) + 10 if event.get("type") == "hold" else (125 if event.get("type") == "burst" else 100)), "power": 200,
			"resistance": NeonRules.band(int(event.get("laneIndex", 0)), setup.tier).x + 3})
		rules.advance(t + 50)
	record.result = rules.result()
	record.ghost = rules.ghost_trace
	assert(NeonRecords.local_request({"action": "save", "record": record}, rider).ok)
	print("LANE SMASH DEMO seeded completed best score=", rules.score_units / NeonRules.UNIT)
