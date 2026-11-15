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
			if not OS.get_cmdline_user_args().is_empty() and id not in OS.get_cmdline_user_args(): continue
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
			var previous_target := -1
			var high_lane_ms := 0
			var work_ms := 0
			var quiet_ms := 0
			var longest_quiet := 0
			for time in range(0, int(course.durationMs), 50):
				var event := rules.current_event()
				_check(LaneSmashSteering.target_for(rules) >= 0, id + " missing lane guidance at " + str(time))
				if not rules.barrage.active and not rules.cooldown and not event.is_empty() and rules.road_time_ms() < int(event.startMs):
					quiet_ms += 50
					longest_quiet = maxi(longest_quiet, quiet_ms)
				else: quiet_ms = 0
				var lane := int(event.get("laneIndex", 0))
				var kind := str(event.get("type", "cruise"))
				var rpm := (float(event.cadenceMin) + float(event.cadenceMax)) / 2 if kind == "hold" else (140.0 if kind == "burst" else 95.0)
				if rules.barrage.active:
					lane = rules.barrage.target_lane()
					var shot := rules.barrage.current_shot()
					if not shot.is_empty():
						var blend := clampf((time - int(shot.lockMs) - 2000) / 4000.0, 0, 1)
						barrage_rpm = lerpf(float(shot.baselineRpm), float(shot.targetRpm), blend)
					rpm = barrage_rpm
				else: barrage_rpm = rpm
				# During Incoming Fire, pace is the target; reset the ordinary lane timer.
				if rules.barrage.active or LaneSmashSteering.target_for(rules) < 0:
					last_lane = -1
					lane_since = time
				elif lane != last_lane:
					_check(time - lane_since <= 60000, id + " lane unchanged over 60 seconds at " + str(time) + " gap=" + str(time - lane_since) + " from=" + str(last_lane) + " to=" + str(lane))
					lane_since = time
					last_lane = lane
				if previous_target >= 0 and lane != previous_target:
					var jump := absi(lane - previous_target)
					_check(jump <= 3, id + " requires a jump over three lanes at " + str(time))
					var gap := int(rules.barrage.section.startMs) - time if rules.barrage.active else int(event.get("startMs", rules.road_time_ms())) - rules.road_time_ms()
					_check(gap >= LaneSmashCatalog.transition_gap(jump) - 60, id + " insufficient transition gap at " + str(time))
				previous_target = lane
				if rules.road_time_ms() >= LaneSmashCatalog.WARMUP_ROAD_MS and time < int(course.durationMs) - 60000:
					work_ms += 50
					if lane >= 2: high_lane_ms += 50
				rules.push_sample({"t": time, "seq": time + 1, "cadence": rpm, "power": 250, "resistance": NeonRules.band(lane, rules.tier).x + 3})
				rules.advance(time + 50)
				seen[kind] = true
				lanes[lane] = true
			_check(longest_quiet < 22000, id + " empty road over 22 seconds: " + str(longest_quiet))
			if id.ends_with("_01"): print("NIGHTFALL ", minutes, "m longest_empty_ms=", longest_quiet)
			_check(high_lane_ms == work_ms, id + " work outside lanes 3–6")
			_check(rules.cooldown, id + " missing final-minute cooldown")
			var result := rules.result()
			_check(result.status == "completed" and rules.pause_reason.is_empty(), id + " incomplete/stalled")
			_check(result.barrage.hits == 0 and result.barrage.dodges == rules.barrage.schedule.filter(func(row): return not row.get("cancelled", false)).size() * 2, id + " incoming fire response")
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
