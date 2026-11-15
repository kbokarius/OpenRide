extends SceneTree
var failures: Array[String] = []
var runs := 0
var hours := 0.0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for minutes in LaneSmashCatalog.LENGTHS:
		for entry in LaneSmashCatalog.tracks(minutes):
			var course := NeonCourse.load_course(entry.id)
			var result := _ride(course, 0)
			if int(result.rules.result().stars) != 3: failures.append("Perfect targets did not earn three stars: " + entry.id)
		print("LANE SMASH SIM library ", minutes, " min complete")
	for minutes in LaneSmashCatalog.LENGTHS:
		for seed_value in [1, 314159, 2147483646]:
			_ride(NeonCourse.load_course(LaneSmashCatalog.random_id(minutes, seed_value)), 0)
		_ride(NeonCourse.load_course("ls_%d_01" % minutes), 250)
	var source := _ride(NeonCourse.load_course("ls_15_04"), 0)
	for tier in NeonRules.CURRENT_TIERS:
		for fps in [30, 60, 120]:
			var rules := NeonRules.new()
			rules.configure(source.rules.course, tier, 150)
			var index := 0
			for frame in range(1, 900 * fps + 1):
				var target := roundi(frame * 1000.0 / fps)
				while index < source.trace.size() and int(source.trace[index].t) < target:
					var sample: Dictionary = source.trace[index].duplicate()
					sample.resistance = NeonRules.band_center(NeonRules.lane_for(sample.resistance, "challenging"), tier)
					rules.push_sample(sample)
					index += 1
				rules.advance(target)
			if rules.score_units != source.rules.score_units or rules.distance_units != source.rules.distance_units: failures.append("fps/tier changed trajectory")
			runs += 1
			hours += 0.25
	for failure in failures: printerr("FAIL ", failure)
	print("LANE SMASH SIM ", "PASS" if failures.is_empty() else "FAIL", " runs=", runs, " hours=", hours)
	quit(0 if failures.is_empty() else 1)
func _ride(course: Dictionary, forced_rpm: int) -> Dictionary:
	var rules := NeonRules.new()
	var errors := rules.configure(course, "challenging", 150)
	if not errors.is_empty():
		failures.append(str(errors))
		return {"rules": rules, "trace": []}
	var trace: Array = []
	for t in range(0, int(course.durationMs), 50):
		var event := rules.current_event()
		var rpm := int((int(event.get("cadenceMin", 80)) + int(event.get("cadenceMax", 100))) / 2) if event.get("type") == "hold" else 110
		if forced_rpm > 0: rpm = forced_rpm
		var sample := {"t": t, "seq": t + 1, "cadence": rpm, "power": 200 if event.get("type") == "burst" else 150, "resistance": NeonRules.band_center(int(event.get("laneIndex", 0)), "challenging")}
		trace.append(sample)
		rules.push_sample(sample)
		rules.advance(t + 50)
	var result := rules.result()
	if result.status != "completed" or rules.road_distance() > float(course.roadLengthMeters) or not rules.pause_reason.is_empty(): failures.append("Incomplete/out of road " + str(course.courseId))
	var record := {"version": 1, "attemptId": "a".repeat(32), "comparisonKey": rules.comparison_key("demo"), "riderId": "demo", "course": course, "result": result, "ghost": rules.ghost_trace}
	if not NeonRecords.valid_record(record): failures.append("Invalid completed ghost " + str(course.courseId))
	runs += 1
	hours += float(course.durationMs) / 3600000.0
	return {"rules": rules, "trace": trace}
