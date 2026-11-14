extends GdUnitTestSuite


func _course(events: Array, duration: int = 20000) -> Dictionary:
	return {"schemaVersion": 1, "courseId": "test", "courseVersion": 1, "title": "Test",
		"family": "test", "durationMs": duration, "phases": [{"name": "Ride", "startMs": 0, "endMs": duration}], "events": events}


func _event(kind: String, start: int, end: int, lane: int = 2) -> Dictionary:
	return {"eventId": "%s-%s" % [kind, start], "type": kind, "startMs": start, "endMs": end,
		"laneIndex": lane, "hitMs": start + 250 if kind == "pickup" else start,
		"cadenceMin": 70, "cadenceMax": 90, "ratio100": 0.6, "ratio200": 1.0}


func _run(rules: NeonRules, end: int, cadence: int = 80, watts: int = 150, resistance: int = 41, fps: int = 60) -> void:
	# Samples are produced at 20 Hz independently of render cadence.
	var next_sample: int = rules.elapsed_ms
	var target: int = rules.elapsed_ms
	while target < end and rules.pause_reason.is_empty():
		target = mini(end, target + maxi(1, roundi(1000.0 / fps)))
		while next_sample < target:
			rules.push_sample({"t": next_sample, "seq": next_sample + 1, "cadence": cadence, "power": watts, "resistance": resistance})
			next_sample += 50
		rules.advance(target)


func test_all_resistance_boundaries_and_outside_are_exact() -> void:
	for tier in NeonRules.TIERS:
		var lo: int = NeonRules.TIERS[tier]
		assert_int(NeonRules.lane_for(lo - 1, tier)).is_equal(-1)
		assert_int(NeonRules.lane_for(lo + 42, tier)).is_equal(-1)
		for lane in 6:
			for r in range(lo + lane * 7, lo + lane * 7 + 7):
				assert_int(NeonRules.lane_for(r, tier)).is_equal(lane)


func test_pickup_is_once_and_requires_settled_lane() -> void:
	var r := NeonRules.new()
	assert_array(r.configure(_course([_event("pickup", 1000, 1510)]), "intermediate", 150)).is_empty()
	_run(r, 2000)
	assert_int(r.score_units).is_equal(140 * NeonRules.UNIT)
	_run(r, 3000)
	assert_int(r.score_units).is_equal(140 * NeonRules.UNIT)


func test_hold_inclusive_cadence_and_zero_pedalling() -> void:
	for rpm in [0, 19, 69, 70, 90, 91]:
		var r := NeonRules.new()
		r.configure(_course([_event("hold", 1000, 2000)]), "intermediate", 150)
		_run(r, 2500, rpm)
		assert_int(r.score_units).is_equal(10 * NeonRules.UNIT if rpm in [70, 90] else 0)


func test_charge_reference_examples_and_cadence_ceiling() -> void:
	for pair in [[45, 50], [90, 100], [150, 150], [300, 150]]:
		var r := NeonRules.new()
		r.configure(_course([_event("charge", 1000, 11000)]), "intermediate", 150)
		_run(r, 11500, 80, pair[0])
		assert_int(r.score_units).is_equal(pair[1] * NeonRules.UNIT)
	var fast := NeonRules.new()
	fast.configure(_course([_event("charge", 1000, 11000)]), "intermediate", 150)
	_run(fast, 11500, 121)
	assert_int(fast.score_units).is_zero()


func test_same_trace_at_different_frame_rates_is_exact() -> void:
	var scores: Array[int] = []
	for fps in [30, 60, 120]:
		var r := NeonRules.new()
		r.configure(_course([_event("hold", 1000, 4000), _event("charge", 8000, 18000)]), "intermediate", 157)
		_run(r, 20000, 83, 113, 41, fps)
		scores.append(r.score_units)
	assert_int(scores[0]).is_equal(scores[1])
	assert_int(scores[1]).is_equal(scores[2])


func test_stale_unchanged_sample_freezes_and_cannot_catch_up() -> void:
	var r := NeonRules.new()
	r.configure(_course([_event("hold", 1000, 10000)]), "intermediate", 150)
	r.push_sample({"t": 0, "seq": 1, "cadence": 80, "power": 100, "resistance": 41})
	r.advance(5000)
	assert_str(r.pause_reason).is_equal("sensor")
	assert_int(r.elapsed_ms).is_equal(1510)
	var frozen := r.score_units
	r.advance(10000)
	assert_int(r.score_units).is_equal(frozen)


func test_invalid_power_setting_and_incomplete_stars() -> void:
	for power in [0.0, -1.0, NAN, INF]:
		var r := NeonRules.new()
		assert_array(r.configure(_course([]), "beginner", power)).is_not_empty()
	var r := NeonRules.new()
	r.configure(_course([_event("hold", 1000, 2000)]), "intermediate", 150)
	_run(r, 2500)
	assert_int(r.result("ended").stars).is_zero()


func test_branch_locks_once_and_maximum_does_not_sum_alternatives() -> void:
	var e := _event("hold", 1000, 2000, 0)
	e["alternatives"] = [{"laneIndex": 0, "rewardPercent": 100}, {"laneIndex": 2, "rewardPercent": 125}]
	var r := NeonRules.new()
	r.configure(_course([e]), "intermediate", 150)
	_run(r, 1500, 80, 100, 26)
	_run(r, 2500, 80, 100, 41)
	assert_int(r.max_units).is_equal(1250000)
	assert_int(r.score_units).is_equal(500000)
	assert_int(r.event_states[0].choice).is_zero()


func test_v2_burst_integrates_energy_without_cadence_or_score_ceiling() -> void:
	for watts in [0, 150, 300]:
		for fps in [30, 60, 120]:
			var data := _course([_event("burst", 1000, 11000)])
			data.courseVersion = 2
			var r := NeonRules.new()
			assert_array(r.configure(data, "intermediate", 150)).is_empty()
			_run(r, 11500, 130, watts, 41, fps)
			assert_int(r.score_units).is_equal(watts * 2 * NeonRules.UNIT)
			assert_int(r.event_states[0].energyMilliJoules).is_equal(watts * 10000)
			assert_int(r.base_units).is_equal(mini(watts, 150) * 2 * NeonRules.UNIT)
			assert_int(r.max_units).is_equal(300 * NeonRules.UNIT)


func test_v2_cruise_and_burst_only_reward_valid_lane_and_pedalling() -> void:
	for kind in ["cruise", "burst"]:
		for pair in [[19, 41], [80, 34], [80, 41]]:
			var data := _course([_event(kind, 1000, 11000)])
			data.courseVersion = 2
			var r := NeonRules.new()
			r.configure(data, "intermediate", 150)
			_run(r, 11500, pair[0], 150, pair[1])
			assert_int(r.score_units).is_equal((100 if kind == "cruise" else 300) * NeonRules.UNIT if pair == [80, 41] else 0)


func test_v1_comparison_identity_is_preserved_after_scoring_upgrade() -> void:
	var data := _course([_event("charge", 1000, 11000)])
	var r := NeonRules.new()
	r.configure(data, "intermediate", 150)
	var original := JSON.stringify(["rider", NeonCourse.fingerprint(data), "intermediate", 1, 1, 150.0], "", true, true).sha256_text()
	assert_str(r.comparison_key("rider")).is_equal(original)
	assert_int(r.scoring_version).is_equal(1)


func _bomb_course() -> Dictionary:
	var course := NeonCourse.load_course("ls_10_01")
	course.events = [_event("cruise", 0, 600000, 0)]
	course.hazards = [{"hazardId": "test-bomb", "hitMs": 60000, "laneIndex": 1, "penaltyPoints": 100}]
	return course

func test_bomb_contact_deducts_once_at_front_wheel_and_is_frame_rate_independent() -> void:
	var results := []
	for fps in [30, 60, 120]:
		var r := NeonRules.new()
		assert_array(r.configure(_bomb_course(), "challenging", 150)).is_empty()
		_run(r, 59000, 140, 150, 33, fps)
		_run(r, 59990, 140, 150, 40, fps)
		var before := r.score_units
		assert_int(r.penalty_units).is_zero()
		_run(r, 60010, 140, 150, 40, fps)
		assert_bool(r.hazard_states[0].hit).is_true()
		assert_int(r.penalty_units).is_equal(100 * NeonRules.UNIT)
		assert_int(r.score_units).is_equal(before - 100 * NeonRules.UNIT)
		_run(r, 61000, 140, 150, 40, fps)
		assert_int(r.penalty_units).is_equal(100 * NeonRules.UNIT)
		results.append(r.score_units)
	assert_int(results[0]).is_equal(results[1])
	assert_int(results[1]).is_equal(results[2])

func test_bombs_leave_target_lane_clear_and_cannot_make_points_negative() -> void:
	for lane in [0, 1, 2]:
		var r := NeonRules.new()
		r.configure(_bomb_course(), "challenging", 150)
		_run(r, 61000, 140, 150, 33 + lane * 7)
		assert_bool(r.hazard_states[0].resolved).is_true()
		assert_bool(r.hazard_states[0].hit).is_equal(lane == 1)
		assert_int(r.penalty_units).is_zero()
		assert_int(r.score_units).is_greater_equal(0)
		if lane == 0: assert_int(r.score_units).is_greater(0)

func test_saved_v4_course_keeps_its_previous_scoring_identity() -> void:
	var course := _bomb_course()
	course.erase("hazards")
	course.courseVersion = 4
	course.generatorVersion = 2
	var r := NeonRules.new()
	assert_array(r.configure(course, "challenging", 150)).is_empty()
	assert_int(r.scoring_version).is_equal(3)
	var key := JSON.stringify(["rider", NeonCourse.fingerprint(course), "challenging", 1, 3, 150.0], "", true, true).sha256_text()
	assert_str(r.comparison_key("rider")).is_equal(key)
