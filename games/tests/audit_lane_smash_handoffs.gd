extends SceneTree
## Additional full Nightfall rides at fixed slow/fast paces and a target-following pace.
## Every inner lane visit must contain playable content before asking for another lane.
var failures: Array[String] = []
var cases := 0
var changes := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for minutes in LaneSmashCatalog.LENGTHS:
		for pace in [0, 20, 45, 60, 80, 100, 140]:
			var rules := NeonRules.new()
			var errors := rules.configure(NeonCourse.load_course("ls_%d_01" % minutes), "challenging", 150)
			if not errors.is_empty():
				failures.append(str(errors))
				continue
			var lane := LaneSmashSteering.target_for(rules)
			var since := 0
			var content_ms := 0
			for time in range(0, minutes * 60000, 50):
				var target := LaneSmashSteering.target_for(rules)
				var event := rules.current_event()
				if lane != target:
					changes += 1
					if content_ms < 1000:
						failures.append("%dm pace=%d empty/brief lane=%d from=%d to=%d content=%d" % [minutes,pace,lane+1,since,time,content_ms])
					lane = target
					since = time
					content_ms = 0
				if rules.barrage.active and time >= int(rules.barrage.section.startMs): content_ms += 50
				elif not rules.barrage.active and not event.is_empty() and rules.road_time_ms() >= int(event.startMs) and rules.road_time_ms() < int(event.endMs): content_ms += 50
				var rpm := float(pace)
				if pace == 0:
					rpm = (float(event.cadenceMin) + float(event.cadenceMax)) / 2 if event.get("type") == "hold" else (140.0 if event.get("type") == "burst" else 95.0)
					var shot := rules.barrage.current_shot()
					if not shot.is_empty(): rpm = float(shot.targetRpm)
				rules.push_sample({"t":time,"seq":time+1,"cadence":rpm,"power":150,"resistance":NeonRules.band_center(lane,rules.tier)})
				rules.advance(time+50)
			if rules.result().status != "completed" or not rules.pause_reason.is_empty(): failures.append("Incomplete ride")
			cases += 1
			await process_frame
	print("HANDOFF AUDIT ", "PASS" if failures.is_empty() else "FAIL", " full_tracks=",cases," simulated_hours=8.75 guidance_changes=",changes," failures=",failures)
	quit(0 if failures.is_empty() else 1)
