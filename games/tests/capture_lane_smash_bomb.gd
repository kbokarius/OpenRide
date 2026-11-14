extends SceneTree
## Deterministic real-renderer contact demo. Never reads or writes personal ride history.
var failures: Array[String] = []
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.hide()
	_run.call_deferred()

func _run() -> void:
	var out := "user://bomb-review"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Engine.max_fps = 60
	var rules := NeonRules.new()
	assert(rules.configure(NeonCourse.load_course("ls_15_01"), "challenging", 150).is_empty())
	var hazard: Dictionary = rules.course.hazards[0]
	var begin := int(hazard.hitMs) - 4000
	for t in range(0, begin, 50):
		var lane := int(rules.current_event().get("laneIndex", 0))
		rules.push_sample({"t": t, "seq": t + 1, "cadence": 140, "power": 250, "resistance": NeonRules.band(lane, rules.tier).x + 3})
		rules.advance(t + 50)
	var track: Node = load("res://games/neon_vector/NeonTrack.gd").new()
	track.rules = rules
	track.world_id = rules.course.theme
	track.visual_lane = hazard.laneIndex
	track._completion_cursor = rules._event_cursor
	track.ghost_visible = true
	track.ghost_lane = rules.course.events[rules._event_cursor].laneIndex
	root.add_child(track)
	var hud: Node = load("res://framework/hud/Hud.gd").new()
	root.add_child(hud)
	var info: RefCounted = load("res://framework/GameInfo.gd").new()
	info.id = "neon_vector"
	info.title = "Lane Smash"
	hud.setup(info, {"duration_sec": 900, "effort": false})
	hud.set_process(false)
	hud.timer.set_process(false)
	var skin: Dictionary = load("res://framework/ui/GameTheme.gd").new(Color("79b8d5"), Color("0b1019"), 0.0, false, true).hud_skin()
	skin.manual_pause = false
	hud.set_skin(skin)
	var status: Node = load("res://games/neon_vector/NeonStatus.gd").new()
	status.rules = rules
	hud.add_widget(status)
	root.get_node("InputBus")._sim_cadence = 140
	root.get_node("InputBus")._sim_resistance = NeonRules.band(hazard.laneIndex, rules.tier).x + 3
	for i in 60:
		track.update_view(0)
		await process_frame
	track.space._warming = false
	var next_sample := begin
	var saw_popup := false
	var last_second := -1
	for frame in 240:
		var target := begin + floori((frame + 1) * 1000.0 / 30 / 10) * 10
		while next_sample < target:
			var lane := int(hazard.laneIndex) if next_sample <= int(hazard.hitMs) + 1000 else int(rules.current_event().get("laneIndex", 0))
			rules.push_sample({"t": next_sample, "seq": next_sample + 1, "cadence": 140, "power": 250, "resistance": NeonRules.band(lane, rules.tier).x + 3})
			next_sample += 50
		rules.advance(target)
		track.ghost_distance = rules.road_distance() + 8
		track.ghost_gap = 8
		track.update_view(1.0 / 30)
		status.refresh()
		if rules.elapsed_ms / 1000 != last_second:
			last_second = rules.elapsed_ms / 1000
			hud.timer.set_value("%d:%02d" % [(900 - last_second) / 60, (900 - last_second) % 60])
			hud.score.set_value(str(rules.score_units / NeonRules.UNIT))
		if track._completion_kind == "bomb" and track._completion_text == "−100": saw_popup = true
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("frame-%04d.png" % frame))
	if not saw_popup: failures.append("Missing negative score popup")
	if rules.penalty_units != 100 * NeonRules.UNIT: failures.append("Expected exactly one 100-point penalty")
	if not rules.pause_reason.is_empty(): failures.append("Unexpected pause")
	print("BOMB DEMO penalty=", rules.penalty_units / NeonRules.UNIT, " popup=", saw_popup, " failures=", failures)
	track.queue_free()
	hud.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
