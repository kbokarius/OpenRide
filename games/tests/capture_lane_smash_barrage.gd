extends SceneTree
## Isolated incoming-fire render review; --mode=hit or success; --out=/absolute/path.
var failures: Array[String] = []
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.hide()
	_run.call_deferred()

func _run() -> void:
	var out := "user://barrage-review"
	var mode := "success"
	var slots_only := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg == "--slots-only": slots_only = true
	DirAccess.make_dir_recursive_absolute(out)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	Engine.max_fps = 60
	var rules := NeonRules.new()
	assert(rules.configure(NeonCourse.load_course("ls_15_01"), "challenging", 150).is_empty())
	var begin := int(rules.course.barrages[0].startMs) - 2000
	var options = load("res://framework/GameOptions.gd")
	options.path = "user://showcase_" + NeonRecords.new_id() + ".cfg"
	for t in range(0, begin, 50):
		_sample(rules, t, mode)
		rules.advance(t + 50)
	var track: Node = load("res://games/neon_vector/NeonTrack.gd").new()
	track.rules = rules
	track.world_id = rules.course.theme
	track.visual_lane = 0
	track._completion_cursor = rules._event_cursor
	var replay: Node = load("res://games/neon_vector/NeonVector.gd").new()
	replay.rules = rules
	replay.track = track
	replay._ghost = []
	root.add_child(track)
	var hud: Node = load("res://framework/hud/Hud.gd").new()
	root.add_child(hud)
	var info: RefCounted = load("res://framework/GameInfo.gd").new()
	info.id = "neon_vector"
	info.title = "Lane Smash"
	hud.setup(info, {"duration_sec": 900, "effort": false})
	hud.set_process(false)
	hud.timer.set_process(false)
	hud.metrics.set_process(false)
	var skin: Dictionary = load("res://framework/ui/GameTheme.gd").new(Color("79b8d5"), Color("0b1019"), 0.0, false, true).hud_skin()
	skin.manual_pause = false
	hud.set_skin(skin)
	var status: Node = load("res://games/neon_vector/NeonStatus.gd").new()
	status.rules = rules
	hud.add_widget(status)

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
	for frame in (271 if slots_only else 1200):
		var target := begin + floori((frame + 1) * 1000.0 / 30 / 10) * 10
		while next_sample < target:
			_sample(rules, next_sample, mode)
			next_sample += 50
		rules.advance(target)
		replay._update_ghost()
		track.update_view(1.0 / 30)
		status.refresh()
		if rules.elapsed_ms / 1000 != last_second:
			last_second = rules.elapsed_ms / 1000
			hud.timer.set_value("%d:%02d" % [(900 - last_second) / 60, (900 - last_second) % 60])
			hud.score.set_value(str(rules.score_units / NeonRules.UNIT))
			for pair in [[hud.metrics._rpm, "cadence"], [hud.metrics._watts, "power"], [hud.metrics._resistance, "resistance"]]:
				pair[0].text = str(roundi(float(rules.latest.get(pair[1], 0))))
		for kind in ["cruise", "hold", "burst"]:
			if not moments.has(kind) and int(track.completed_sections[kind]) > 0: moments[kind] = frame / 30.0
		if track._completion_kind == "bomb" and not moments.has("bomb"): moments.bomb = frame / 30.0
		if track._completion_kind in ["bomb", "evade"]: saw_popup = true
		await RenderingServer.frame_post_draw
		if not slots_only: root.get_texture().get_image().save_jpg(out.path_join("frame-%04d.jpg" % frame), 0.93)
		if slots_only and frame == 270:
			for slot in 6:
				rules.barrage.current_shot().slot = slot
				track.update_view(0)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(out.path_join("slot-%d.png" % slot))
		if frame % 900 == 0: print("SHOWCASE progress_s=", frame / 30)
	if not slots_only and not saw_popup: failures.append("Missing negative score popup")
	if not slots_only and rules.barrage.result().hits != (2 if mode == "hit" else 0): failures.append("Unexpected hits")
	if not rules.pause_reason.is_empty(): failures.append("Unexpected pause")
	var report := FileAccess.open(out.path_join("moments.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(moments, "  "))
	report.close()
	print("BARRAGE DEMO mode=", mode, " result=", rules.barrage.result(), " failures=", failures)
	replay.free()
	track.queue_free()
	hud.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _sample(rules: NeonRules, t: int, mode: String) -> void:
	var event := rules.current_event()
	var lane := int(event.get("laneIndex", 0))
	var rpm := 80.0
	if rules.barrage.active:
		lane = 0
		var shot := rules.barrage.current_shot()
		if not shot.is_empty():
			var blend := clampf((t - int(shot.lockMs) - 2000) / 4000.0, 0, 1)
			rpm = lerpf(float(shot.baselineRpm), float(shot.targetRpm), blend) if mode == "success" else float(shot.baselineRpm)
	elif event.get("type", "") == "hold": rpm = int(event.cadenceMin) + 10
	var resistance := NeonRules.band(lane, rules.tier).x + 3
	var watts := roundi(rpm * (0.3 + resistance * 0.045))
	rules.push_sample({"t": t, "seq": t + 1, "cadence": rpm, "power": watts, "resistance": resistance})
