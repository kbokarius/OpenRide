extends SceneTree
## Complete authored and representative daily rides at all tiers and 30/60/120 fps.
## Drive the published best reachable route using timestamped 20 Hz sensor deliveries.
## No sleep: 49 simulated hours run headlessly in seconds/minutes.

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var started := Time.get_ticks_msec()
	var runs := 0
	var seconds := 0
	var courses := NeonCourse.library()
	for date in ["2026-11-13", "2026-12-31", "2027-01-01"]:
		courses.append(NeonCourse.daily(date))
	for course in courses:
		var baseline := -1
		for tier in NeonRules.TIERS:
			for fps in [30, 60, 120]:
				var rules := NeonRules.new()
				var problems := rules.configure(course, tier, 150)
				if not problems.is_empty():
					failures.append("Invalid %s: %s" % [course.courseId, problems])
					continue
				var target := 0
				var sample_time := 0
				var event_index := 0
				var frame := 0
				while rules.elapsed_ms < int(course.durationMs) and rules.pause_reason.is_empty():
					frame += 1
					target = mini(int(course.durationMs), roundi(frame * 1000.0 / fps))
					while sample_time < target:
						# Choose by sample time, not rendered state. Both render frequency and
						# tier can change without changing the underlying input trajectory.
						while event_index < course.events.size() - 1 and int(course.events[event_index].endMs) <= sample_time:
							event_index += 1
						var event: Dictionary = course.events[event_index]
						var choices := NeonCourse.choices(event)
						var choice: Dictionary = choices[-1]
						var band := NeonRules.band(int(choice.laneIndex), tier)
						rules.push_sample({"t": sample_time, "seq": sample_time + 1, "cadence": 80, "power": 150, "resistance": band.x + 3})
						sample_time += 50
					rules.advance(target)
				var result := rules.result()
				if result.status != "completed" or rules.score_units != rules.max_units or result.stars != 3:
					failures.append("%s %s %d fps: %s %d/%d stars=%d reason=%s" % [course.courseId, tier, fps, result.status, rules.score_units, rules.max_units, result.stars, rules.pause_reason])
				if baseline >= 0 and baseline != rules.score_units:
					failures.append("Frame rate/tier changed score: %s" % course.courseId)
				baseline = rules.score_units
				runs += 1
				seconds += int(course.durationMs) / 1000
		print("SIM course=%s all four tiers x three frame rates" % course.courseId)
	for failure in failures:
		printerr("FAIL ", failure)
	print("NEON SIM %s runs=%d simulated_hours=%.2f wall_ms=%d" % ["PASS" if failures.is_empty() else "FAIL", runs, seconds / 3600.0, Time.get_ticks_msec() - started])
	quit(0 if failures.is_empty() else 1)
