extends SceneTree
## Repeated real hub/ride/end cycles use isolated storage, bounded nodes and no user settings.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 60
	var options = load("res://framework/GameOptions.gd")
	var storage := "user://lane_soak_" + NeonRecords.new_id()
	NeonRecords.path = storage
	options.path = storage + ".cfg"
	var session: Node = root.get_node("Session")
	var director: Node = session.director
	change_scene_to_file("res://hub/Hub.tscn")
	await process_frame
	session._local.hub.begin_visit()
	await create_timer(0.5).timeout
	var counts: Array[int] = []
	var memory: Array[int] = []
	var failures: Array[String] = []
	# `-- --cycles=N --minutes=M` repeats one duration N times, to tell a leak from a high-water mark.
	var cycles := 10
	var fixed_minutes := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cycles="): cycles = int(arg.trim_prefix("--cycles="))
		if arg.begins_with("--minutes="): fixed_minutes = int(arg.trim_prefix("--minutes="))
	for cycle in cycles:
		var setup: Node = current_scene.screen
		setup.length_picker.pick(str(fixed_minutes if fixed_minutes > 0 else LaneSmashCatalog.LENGTHS[cycle % 4]))
		setup._pick_track(cycle % 25)
		setup._pick_tier(NeonRules.CURRENT_TIERS.keys()[cycle % 5])
		root.get_node("InputBus")._sim_resistance = NeonRules.band_center(setup.course.events[0].laneIndex, setup.tier)
		setup.start_button.pressed.emit()
		var deadline := Time.get_ticks_msec() + 15000
		while director.phase_name() != "PLAYING" and Time.get_ticks_msec() < deadline: await process_frame
		if director.phase_name() != "PLAYING":
			failures.append("Ride did not start")
			break
		# The first section begins three to five road-seconds in (up to 8.8 real seconds at
		# 80 rpm): tracks open with a stretch of empty road since generator 6.
		deadline = Time.get_ticks_msec() + 14000
		while director.game.rules.score_units <= 0 and Time.get_ticks_msec() < deadline: await process_frame
		if director.game.rules.score_units <= 0: failures.append("Ride earned no points")
		session.request_end()
		deadline = Time.get_ticks_msec() + 5000
		while not director.summary_screen.visible and Time.get_ticks_msec() < deadline: await process_frame
		if not director.summary_screen.visible:
			failures.append("End did not finish")
			break
		director.summary_screen.done_pressed.emit()
		await create_timer(0.4).timeout
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		memory.append(int(Performance.get_monitor(Performance.MEMORY_STATIC)))
		print("SOAK cycle=", cycle + 1, " nodes=", counts[-1], " memory_mib=", memory[-1] / 1048576.0)
	if counts.size() == 10:
		if counts.max() - counts.min() > 5: failures.append("Menu node count grew")
		if memory[-1] - memory[1] > 4 * 1048576: failures.append("Retained memory grew over 4 MiB")
	print("SOAK cycles=", counts.size(), " failures=", failures)
	for file in DirAccess.get_files_at(storage): DirAccess.remove_absolute(storage.path_join(file))
	DirAccess.remove_absolute(storage)
	DirAccess.remove_absolute(options.path)
	quit(0 if failures.is_empty() else 1)
