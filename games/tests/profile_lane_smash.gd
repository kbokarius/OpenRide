extends SceneTree
## Repeatable CPU timing; headless numbers exclude GPU cost and are not device FPS.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("ls_30_10"), "extreme", 150)
	var space := NeonSpace.new()
	root.add_child(space)
	space._warming = false
	var start := Time.get_ticks_usec()
	space.update_view(rules, 0, 0, -1, false, "")
	print("PROFILE prepare_ms=", (Time.get_ticks_usec() - start) / 1000.0)
	var timings: Array[float] = []
	for base in [0.0, 14000.0, 29000.0]:
		for frame in 600:
			var at: float = base + frame * NeonRules.MAX_SPEED_MPS / 60.0
			rules.distance_units = roundi(at * 1000000)
			while rules._event_cursor + 1 < rules.course.events.size() and rules.course.events[rules._event_cursor].endMs < rules.road_time_ms(): rules._event_cursor += 1
			rules.latest = {"cadence": 140, "power": 350, "resistance": 60}
			start = Time.get_ticks_usec()
			space.update_view(rules, 1.0 / 60, 3, 2, true, "")
			if frame > 10: timings.append((Time.get_ticks_usec() - start) / 1000.0)
			if frame % 60 == 0: await process_frame
	var total := 0.0
	for value in timings: total += value
	timings.sort()
	print("PROFILE updates=", timings.size(), " mean_ms=", total / timings.size(), " p50_ms=", timings[timings.size()/2], " p95_ms=", timings[int(timings.size()*.95)], " max_ms=", timings[-1])
	# Sample the new effect's complete active interval separately from ordinary cruising.
	var attack := NeonRules.new()
	attack.configure(NeonCourse.load_course("ls_15_01"), "challenging", 150)
	var begin := int(attack.course.barrages[0].startMs)
	for t in range(0, begin, 50):
		attack.push_sample({"t": t, "seq": t + 1, "cadence": 80, "power": 150, "resistance": 33})
		attack.advance(t + 50)
	space.update_view(attack, 0, 0, -1, false, "")
	timings.clear()
	for t in range(begin, begin + 35000, 20):
		attack.push_sample({"t": t, "seq": t + 1, "cadence": 80, "power": 150, "resistance": 33})
		attack.advance(t + 20)
		start = Time.get_ticks_usec()
		space.update_view(attack, 0.02, 0, -1, false, "")
		timings.append((Time.get_ticks_usec() - start) / 1000.0)
		if t % 1000 == 0: await process_frame
	total = 0
	for value in timings: total += value
	timings.sort()
	print("PROFILE incoming_fire updates=", timings.size(), " mean_ms=", total / timings.size(), " p95_ms=", timings[int(timings.size()*.95)], " max_ms=", timings[-1], " effects=", space.barrage_view.effects_count)
	space.queue_free()
	await process_frame
	quit()
