extends SceneTree
## Where the picture's time goes. Renders the ride with vertical sync off and a 3D view four
## times the tablet's pixel count, so fill cost dominates, then switches one part off at a
## time and reports the frame time each part accounts for. The figures are from whatever GPU
## runs this (not the bike's tablet): read them as shares of the frame, not as milliseconds
## the tablet will see.
##   godot --path games -s res://tests/profile_lane_smash_gpu.gd [-- --frames=200 --scale=2.0]
const COURSE := "ls_15_01"
var rules := NeonRules.new()
var track: Node
var _next_sample := 0


func _initialize() -> void:
	_run.call_deferred()


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name): return arg.trim_prefix("--%s=" % name)
	return fallback


func _step(ms: int) -> void:
	var target := rules.elapsed_ms + ms
	while _next_sample < target:
		var event := rules.current_event()
		var lane := 0 if rules.barrage.active else int(event.get("laneIndex", 0))
		var rpm := 96.0
		if event.get("type", "") == "hold": rpm = (float(event.cadenceMin) + float(event.cadenceMax)) * 0.5
		rules.push_sample({"t": _next_sample, "seq": _next_sample + 1, "cadence": rpm, "power": 200, "resistance": NeonRules.band_center(lane, rules.tier)})
		_next_sample += 50
	rules.advance(target)


## Average milliseconds per frame over `frames` frames of riding.
func _measure(frames: int) -> float:
	for i in 20:
		_step(16)
		track.update_view(1.0 / 60)
		await process_frame
	var start := Time.get_ticks_usec()
	for i in frames:
		_step(16)
		track.update_view(1.0 / 60)
		await process_frame
	return (Time.get_ticks_usec() - start) / 1000.0 / frames


func _run() -> void:
	var frames := int(_arg("frames", "200"))
	var scale := float(_arg("scale", "2.0"))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var jukebox: Node = root.get_node_or_null("Jukebox")
	if jukebox != null: jukebox.frozen = true
	rules.configure(NeonCourse.load_course(COURSE), "challenging", 150)
	track = load("res://games/neon_vector/NeonTrack.gd").new()
	track.rules = rules
	root.add_child(track)
	track.apply_quality(_arg("quality", "balanced"))
	for i in 80:
		track.update_view(0)
		await process_frame
	track.space._warming = false
	_step(21000)  # into the first cadence section: gunner, tracers, section floor, markers
	var space: NeonSpace = track.space
	var view: SubViewport = track.view
	var tablet := Vector2(view.size)
	view.size = Vector2i(tablet * scale)
	print("GPU PROFILE view=%dx%d (tablet tier %s is %dx%d) window=%s renderer=%s" % [view.size.x, view.size.y, track.quality, int(tablet.x), int(tablet.y), root.size, RenderingServer.get_video_adapter_name()])
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var base: float = await _measure(frames)
	print("GPU PROFILE %-34s %7.3f ms/frame" % ["everything", base])
	# What the CPU and the driver are asked to do each frame.
	var script_usec := 0
	for i in 120:
		var t := Time.get_ticks_usec()
		_step(16)
		track.update_view(1.0 / 60)
		script_usec += Time.get_ticks_usec() - t
		await process_frame
	print("GPU PROFILE counters: draw_calls=%d objects=%d primitives=%d  script_ms=%.3f (rules + view update)  process_ms=%.3f  view_cpu_ms=%.3f view_gpu_ms=%.3f root_cpu_ms=%.3f root_gpu_ms=%.3f" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), script_usec / 120.0 / 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid()), RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid()),
		RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()), RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())])
	var env: Environment = space._env
	var parts: Array = [
		["sky (tunnel shader)", func(on: bool): env.background_mode = Environment.BG_SKY if on else Environment.BG_COLOR],
		["bloom and grade", func(on: bool): env.glow_enabled = on; env.adjustment_enabled = on],
		["road deck", func(on: bool): for chunk in space._road_chunks: chunk.road.visible = on],
		["rails", func(on: bool): for chunk in space._road_chunks: chunk.rails.visible = on],
		["rail curtains", func(on: bool): for chunk in space._road_chunks: chunk.glow.visible = on],
		["arches and streaks", func(on: bool): space.scenery.visible = on],
		["motorcycle and trail", func(on: bool): space.rider.visible = on; space._trail.visible = on],
		["markers, sections, attackers", func(on: bool): space.sections.visible = on; space.gunfire_view.visible = on; space._bars.visible = on; space._arrows.visible = on; space._glows.visible = on],
		["lens pass (vignette, fringing)", func(on: bool): track._image.material = track._lens if on else null],
	]
	for part: Array in parts:
		part[1].call(false)
		var without: float = await _measure(frames)
		part[1].call(true)
		print("GPU PROFILE %-34s %7.3f ms   (%4.1f%% of the frame)" % [part[0], base - without, (base - without) / base * 100.0])
	# Bloom: how its cost depends on which blur levels are in use.
	var levels := []
	for i in 7: levels.append(env.get_glow_level(i))
	print("GPU PROFILE bloom levels in use: ", levels)
	for variant: Array in [["levels 1-3 only", [0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0]], ["level 3 only", [0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0]], ["levels 2 and 4", [0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0]], ["levels 1 and 2", [1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]]]:
		for i in 7: env.set_glow_level(i, variant[1][i])
		var with_variant: float = await _measure(frames)
		print("GPU PROFILE bloom %-28s %7.3f ms/frame (%+.3f against the default)" % [variant[0], with_variant, with_variant - base])
	for i in 7: env.set_glow_level(i, levels[i])
	# Resolution and anti-aliasing, at the tablet's own view size.
	view.size = Vector2i(tablet)
	var plain: float = await _measure(frames)
	print("GPU PROFILE at the tablet's view size: %.3f ms/frame" % plain)
	for option: Array in [["FXAA", func(on: bool): view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if on else Viewport.SCREEN_SPACE_AA_DISABLED],
			["MSAA 2x", func(on: bool): view.msaa_3d = Viewport.MSAA_2X if on else Viewport.MSAA_DISABLED],
			["MSAA 4x", func(on: bool): view.msaa_3d = Viewport.MSAA_4X if on else Viewport.MSAA_DISABLED]]:
		option[1].call(true)
		var with_it: float = await _measure(frames)
		option[1].call(false)
		print("GPU PROFILE %-34s %+7.3f ms   (%+5.1f%%)" % [option[0], with_it - plain, (with_it - plain) / plain * 100.0])
	for factor in [0.62, 0.72, 0.83, 1.0]:
		view.size = Vector2i(Vector2(1920, 1080) * factor)
		var at: float = await _measure(frames)
		print("GPU PROFILE view scale %.2f (%dx%d)        %7.3f ms/frame" % [factor, view.size.x, view.size.y, at])
	quit()
