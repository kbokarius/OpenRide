extends SceneTree
## Render the real track and shared HUD at fixed input traces for repeatable visual review.
## --out=/absolute/path --time=135 --size=1920x1008


func _initialize() -> void:
	if "--hidden" in OS.get_cmdline_user_args():
		root.set_flag(ClassDB.class_get_integer_constant("Window", "FLAG_NO_FOCUS"), true)
		root.hide()
	_run.call_deferred()


func _run() -> void:
	var out := "user://neon-captures"
	var seconds := 135.0
	var measure := false
	var world_filter := ""
	var course_id := "ls_20_04"
	var window := Vector2i(1920, 1080)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--time="):
			seconds = float(arg.trim_prefix("--time="))
		elif arg.begins_with("--world="):
			world_filter = arg.trim_prefix("--world=")
		elif arg == "--measure":
			measure = true
		elif arg.begins_with("--course="):
			course_id = arg.trim_prefix("--course=")
		elif arg.begins_with("--size="):
			var size_text := arg.trim_prefix("--size=").split("x")
			window = Vector2i(int(size_text[0]), int(size_text[1]))
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(window)
	var rules := NeonRules.new()
	var errors := rules.configure(NeonCourse.load_course(course_id), "challenging", 150)
	if not errors.is_empty():
		push_error(str(errors))
		quit(1)
		return
	for t in range(0, int(seconds * 1000), 50):
		var event := rules.current_event()
		var lane := int(event.get("laneIndex", 1))
		rules.push_sample({"t": t, "seq": t + 1, "cadence": 80, "power": 150, "resistance": NeonRules.band(lane, rules.tier).x + 3})
		rules.advance(t + 50)
	var track = load("res://games/neon_vector/NeonTrack.gd").new()
	track.rules = rules
	track.visual_lane = rules.selected_lane
	track.ghost_visible = true
	track.ghost_lane = maxi(0, rules.selected_lane - 1)
	track.ghost_delta = 120
	root.add_child(track)
	var hud = load("res://framework/hud/Hud.gd").new()
	root.add_child(hud)
	var info = load("res://framework/GameInfo.gd").new()
	info.id = "neon_vector"
	info.title = "Lane Smash"
	info.how_to = "Turn resistance to change lanes"
	hud.setup(info, {"duration_sec": 1200, "effort": false})
	# This is a frozen rules snapshot, not a live SessionDirector session.
	hud.set_process(false)
	hud.timer.set_process(false)
	hud.timer.set_caption("time left")
	hud.timer.set_value("%d:%02d" % [int(1200 - seconds) / 60, int(1200 - seconds) % 60])
	hud.score.set_value(str(rules.score_units / NeonRules.UNIT))
	var skin: Dictionary = load("res://framework/ui/GameTheme.gd").new(Color("79b8d5"), Color("0b1019"), 0.0, false, true).hud_skin()
	skin["manual_pause"] = false
	hud.set_skin(skin)
	var status = load("res://games/neon_vector/NeonStatus.gd").new()
	status.rules = rules
	hud.add_widget(status)
	root.get_node("InputBus")._sim_cadence = 80
	root.get_node("InputBus")._sim_resistance = rules.latest.resistance
	for world in NeonWorlds.WORLDS:
		if not world_filter.is_empty() and world.id != world_filter: continue
		track.world_id = world.id
		track.update_view(0)
		status.refresh()
		for i in 60:
			await process_frame
		track.space._warming = false
		track.ghost_distance = rules.road_distance() + 8
		track.ghost_gap = 8
		track.update_view(0)
		await RenderingServer.frame_post_draw
		var file := "%s/%s-%d-%dx%d.png" % [out, world.id, roundi(seconds), window.x, window.y]
		root.get_texture().get_image().save_png(file)
		print("CAPTURE ", file)
		if measure:
			var process_ms: Array[float] = []
			var draw_calls: Array[int] = []
			var frame_ms: Array[float] = []
			var last := Time.get_ticks_usec()
			for i in 240:
				var time := rules.elapsed_ms
				rules.push_sample({"t": time, "seq": time + 1, "cadence": 80, "power": 150, "resistance": rules.latest.resistance})
				rules.advance(time + 10)
				track.update_view(1.0 / 60)
				status.refresh()
				await process_frame
				var now := Time.get_ticks_usec()
				if i >= 60:
					frame_ms.append((now - last) / 1000.0)
					process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
					draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
				last = now
			process_ms.sort()
			frame_ms.sort()
			draw_calls.sort()
			print("NEON PERF world=%s frame_median_ms=%.2f frame_p95_ms=%.2f process_p95_ms=%.2f draw_calls_p95=%d static_mib=%.1f" % [world.id, frame_ms[90], frame_ms[171], process_ms[171], draw_calls[171], Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576])
	quit()
