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
	for cycle in 10:
		var setup: Node = current_scene.screen
		setup.length_picker.pick(str(LaneSmashCatalog.LENGTHS[cycle % 4]))
		setup._pick_track(cycle)
		setup._pick_tier(NeonRules.CURRENT_TIERS.keys()[cycle % 5])
		root.get_node("InputBus")._sim_resistance = NeonRules.band(setup.course.events[0].laneIndex, setup.tier).x + 3
		setup.start_button.pressed.emit()
		var deadline := Time.get_ticks_msec() + 15000
		while director.phase_name() != "PLAYING" and Time.get_ticks_msec() < deadline: await process_frame
		if director.phase_name() != "PLAYING":
			failures.append("Ride did not start")
			break
		# The first target begins 1.5 road-seconds ahead (2.6 real seconds at 80 rpm).
		deadline = Time.get_ticks_msec() + 6000
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
