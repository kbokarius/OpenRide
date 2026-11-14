extends SceneTree
## Full-duration offline sensor traces for every named track and representative seeds.
var failures: Array[String] = []
var cases := 0
var simulated_ms := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, detail: String) -> void:
	if not ok: failures.append(detail)

func _run() -> void:
	var tiers := NeonRules.CURRENT_TIERS.keys()
	for minutes in LaneSmashCatalog.LENGTHS:
		var ids: Array = LaneSmashCatalog.tracks(minutes).map(func(row): return row.id)
		for seed_value in [7, 101, 9187, 2147483646]: ids.append(LaneSmashCatalog.random_id(minutes, seed_value))
		for id: String in ids:
			var course := NeonCourse.load_course(id)
			var errors := NeonCourse.validate(course)
			_check(errors.is_empty(), id + " validation: " + str(errors))
			if not errors.is_empty(): continue
			for tier: String in tiers:
				var limits := {}
				for lane in 6:
					var band := NeonRules.band(lane, tier)
					for resistance in range(band.x, band.y + 1):
						_check(NeonRules.lane_for(resistance, tier) == lane, id + " lane mapping")
						limits[resistance] = true
				_check(limits.size() == 42, id + " missing resistance bands")
			var rules := NeonRules.new()
			rules.configure(course, tiers[cases % tiers.size()], 150)
			var seen := {}
			var lanes := {}
			var last_lane := -1
			var lane_since := 0
			var barrage_rpm := 80.0
			for time in range(0, int(course.durationMs), 50):
				var event := rules.current_event()
				var lane := int(event.get("laneIndex", 0))
				var kind := str(event.get("type", "cruise"))
				var rpm := (float(event.cadenceMin) + float(event.cadenceMax)) / 2 if kind == "hold" else (140.0 if kind == "burst" else 95.0)
				if rules.barrage.active:
					lane = 0
					var shot := rules.barrage.current_shot()
					if not shot.is_empty():
						var blend := clampf((time - int(shot.lockMs) - 2000) / 4000.0, 0, 1)
						barrage_rpm = lerpf(float(shot.baselineRpm), float(shot.targetRpm), blend)
					rpm = barrage_rpm
				else: barrage_rpm = rpm
				# During Incoming Fire, pace is the target; reset the ordinary lane timer.
				if rules.barrage.active:
					last_lane = -1
					lane_since = time
				elif lane != last_lane:
					_check(time - lane_since <= 60000, id + " lane unchanged over 60 seconds")
					lane_since = time
					last_lane = lane
				rules.push_sample({"t": time, "seq": time + 1, "cadence": rpm, "power": 250, "resistance": NeonRules.band(lane, rules.tier).x + 3})
				rules.advance(time + 50)
				seen[kind] = true
				lanes[lane] = true
			var result := rules.result()
			_check(result.status == "completed" and rules.pause_reason.is_empty(), id + " incomplete/stalled")
			_check(result.barrage.hits == 0 and result.barrage.dodges == course.barrages.size() * 2, id + " incoming fire response")
			_check(result.stars == 3 and result.scoreUnits > 0, id + " target-following score/stars")
			_check(seen.size() == 3 and lanes.size() == 6, id + " missing section type or lane")
			_check(rules.ghost_trace.size() == int(course.durationMs) / 100, id + " ghost coverage")
			_check(rules.road_distance() < float(course.roadLengthMeters), id + " ran off road")
			cases += 1
			simulated_ms += int(course.durationMs)
			if cases % 10 == 0:
				print("TRACK AUDIT progress=", cases, " failures=", failures.size())
				await process_frame
	# Cap-speed and stopped traces through the entire 30-minute duration.
	for rpm in [0, 60, 140, 200]:
		var rules := NeonRules.new()
		rules.configure(NeonCourse.load_course("ls_30_01"), "extreme", 150)
		for time in range(0, 1800000, 50):
			rules.push_sample({"t": time, "seq": time + 1, "cadence": rpm, "power": 150, "resistance": 38})
			rules.advance(time + 50)
		_check(rules.result().status == "completed", "30-minute speed trace did not complete")
		_check(absf(rules.road_distance() - minf(rpm, 140) / 140.0 * 30000.0) < 0.01, "30-minute speed/distance drift")
		_check(rules._samples.size() <= 130 and rules._power.size() <= 100 and rules.ghost_trace.size() == 18000, "unbounded input/ghost buffer")
		await process_frame
	print("TRACK AUDIT ", "PASS" if failures.is_empty() else "FAIL", " full_tracks=", cases, " simulated_hours=", simulated_ms / 3600000.0, " speed_traces=4 five_difficulties=verified failures=", failures)
	quit(0 if failures.is_empty() else 1)
