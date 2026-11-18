extends GdUnitTestSuite
## Gap mines deter easy-lane detours without obstructing a required adjustment.

func _course(from_lane := 2, to_lane := 5, version := 13) -> Dictionary:
	var course := NeonCourse.load_course("ls_10_01")
	course.courseVersion = version
	course.generatorVersion = 10 if version == 13 else 9
	var gap := 2000 if from_lane == to_lane else 9000
	course.events = [
		{"eventId": "first", "type": "cruise", "startMs": 2000, "endMs": 12000, "laneIndex": from_lane},
		{"eventId": "next", "type": "cruise", "startMs": 12000 + gap, "endMs": 22000 + gap, "laneIndex": to_lane}]
	course.barrages = []
	course.hazards = LaneSmashHazards.generate_guarded(course.events) if version == 13 else LaneSmashHazards.generate_dense(course.events)
	return course

func _at(hazards: Array, time: int) -> Array:
	return hazards.filter(func(row): return int(row.hitMs) == time).map(func(row): return int(row.laneIndex))

func _step(rules: NeonRules, rpm: float, lane: int) -> void:
	var time := rules.elapsed_ms
	rules.push_sample({"t": time, "seq": time + 1, "cadence": rpm, "power": 150,
		"resistance": NeonRules.band_center(lane, rules.tier)})
	rules.advance(time + 10)

func test_three_lane_corridor_closes_only_after_six_seconds() -> void:
	var course := _course()
	assert_array(NeonCourse.validate(course)).is_empty()
	# Lane 3 -> 6: lanes 3/4/5/6 are clear at +1 and +4 seconds.
	assert_array(_at(course.hazards, 13000)).is_equal([0, 1])
	assert_array(_at(course.hazards, 16000)).is_equal([0, 1])
	assert_array(_at(course.hazards, 19000)).is_equal([0, 1, 2, 3, 4])
	assert_array(course.hazards.filter(func(row): return int(row.hitMs) < 2000)).is_empty()

func test_one_and_two_lane_changes_have_four_and_five_second_allowances() -> void:
	var one := _course(2, 3)
	assert_array(_at(one.hazards, 13000)).is_equal([0, 1, 4, 5])
	assert_array(_at(one.hazards, 16000)).is_equal([0, 1, 2, 4, 5])
	var two := _course(2, 4)
	assert_array(_at(two.hazards, 16000)).is_equal([0, 1, 5])
	assert_array(_at(two.hazards, 19000)).is_equal([0, 1, 2, 3, 5])

func test_same_lane_gap_has_five_mines_and_detour_loses_points_once() -> void:
	var course := _course(3, 3)
	assert_array(_at(course.hazards, 13000)).is_equal([0, 1, 2, 4, 5])
	for lane in [0, 3]:
		var rules := NeonRules.new()
		assert_array(rules.configure(course, "challenging", 150)).is_empty()
		rules.score_units = 5000 * NeonRules.UNIT
		while rules.elapsed_ms < 12000: _step(rules, 140, 3)
		while rules.elapsed_ms < 13010: _step(rules, 140, lane)
		assert_int(rules.penalty_units).is_equal((1800 if lane == 0 else 0) * NeonRules.UNIT)
		assert_int(rules.hazard_states.filter(func(state): return state.hit).size()).is_equal(1 if lane == 0 else 0)

func test_gradual_three_lane_adjustment_is_safe_in_both_directions_and_at_slower_speed() -> void:
	for pair in [[2, 5], [5, 2]]:
		for rpm in [35, 70, 140]:
			var rules := NeonRules.new()
			assert_array(rules.configure(_course(pair[0], pair[1]), "kid", 150)).is_empty()
			while rules.road_time_ms() < 22000:
				var since := rules.road_time_ms() - 12000
				var crossed := 0 if since < 2000 else (1 if since < 4000 else (2 if since < 5900 else 3))
				var lane := int(pair[0]) + crossed * (1 if pair[1] > pair[0] else -1)
				_step(rules, rpm, lane)
			assert_int(rules.penalty_units).is_zero()

func test_lingering_in_the_old_lane_is_penalized_after_the_grace() -> void:
	var rules := NeonRules.new()
	assert_array(rules.configure(_course(), "challenging", 150)).is_empty()
	rules.score_units = 5000 * NeonRules.UNIT
	while rules.elapsed_ms < 18990: _step(rules, 140, 2)
	assert_int(rules.penalty_units).is_zero()
	while rules.elapsed_ms < 19010: _step(rules, 140, 2)
	assert_int(rules.penalty_units).is_equal(1800 * NeonRules.UNIT)

func test_validator_rejects_mines_in_target_or_early_crossing_corridor() -> void:
	for placement in [[13000, 3], [19000, 5], [12500, 0], [20900, 0]]:
		var course := _course()
		course.hazards = [{"hazardId": "unsafe", "hitMs": placement[0], "laneIndex": placement[1], "penaltyPoints": 100}]
		assert_array(NeonCourse.validate(course)).contains(["Invalid bomb hazards"])

func test_all_named_and_seeded_tracks_keep_every_gap_route_clear_and_fit_the_pool() -> void:
	for minutes in LaneSmashCatalog.LENGTHS:
		var ids: Array = LaneSmashCatalog.tracks(minutes).map(func(row): return row.id)
		for seed_value in [1, 77, 104729, 2147483646]: ids.append(LaneSmashCatalog.random_id(minutes, seed_value))
		for id: String in ids:
			var course := NeonCourse.load_course(id)
			assert_array(NeonCourse.validate(course)).override_failure_message(id).is_empty()
			var hazards: Array = course.hazards
			var left := 0
			for right in hazards.size():
				while int(hazards[right].hitMs) - int(hazards[left].hitMs) > 17500: left += 1
				assert_int(right - left + 1).override_failure_message(id + " render pool overflow").is_less_equal(LaneSmashBombs.CAPACITY)
			for i in range(1, course.events.size()):
				var previous: Dictionary = course.events[i - 1]
				var next: Dictionary = course.events[i]
				var rows := hazards.filter(func(row): return int(row.hitMs) >= int(previous.endMs) and int(row.hitMs) < int(next.startMs))
				assert_array(rows).override_failure_message(id + " unguarded gap").is_not_empty()
				for row: Dictionary in rows:
					assert_int(int(row.laneIndex)).is_not_equal(int(next.laneIndex))
					var grace: int = [0, 4000, 5000, 6000][absi(int(next.laneIndex) - int(previous.laneIndex))]
					if int(row.hitMs) - int(previous.endMs) < grace:
						assert_bool(int(row.laneIndex) < mini(int(previous.laneIndex), int(next.laneIndex)) or int(row.laneIndex) > maxi(int(previous.laneIndex), int(next.laneIndex))).is_true()

func test_incoming_fire_returns_guarded_gaps_only_for_new_courses() -> void:
	for version in [12, 13]:
		var course := NeonCourse.load_course("ls_10_01")
		course.courseVersion = version
		if version == 12: course.hazards = LaneSmashHazards.generate_dense(course.events)
		var original := NeonCourse.fingerprint(course)
		var rules := NeonRules.new()
		assert_array(rules.configure(course, "challenging", 150)).is_empty()
		assert_int(rules.scoring_version).is_equal(version - 1)
		var was_attacking := false
		var returned := false
		while rules.elapsed_ms < 180000:
			_step(rules, 140, LaneSmashSteering.target_for(rules))
			if was_attacking and not rules.barrage.active:
				returned = true
				var at := rules.road_time_ms()
				var next := rules.current_event()
				var rows := rules.hazards.filter(func(row): return int(row.hitMs) > at and int(row.hitMs) < int(next.startMs))
				assert_bool(not rows.is_empty()).is_equal(version == 13)
				for row: Dictionary in rows:
					assert_int(int(row.hitMs) % 10).is_zero()
					assert_int(int(row.laneIndex)).is_not_equal(int(next.laneIndex))
				break
			was_attacking = rules.barrage.active
		assert_bool(returned).is_true()
		assert_str(NeonCourse.fingerprint(course)).is_equal(original)

func test_cooldown_suppresses_gap_mines() -> void:
	var course := _course(3, 3)
	var rules := NeonRules.new()
	rules.configure(course, "challenging", 150)
	while rules.elapsed_ms < 12000: _step(rules, 140, 3)
	rules.cooldown = true
	while rules.elapsed_ms < 13010: _step(rules, 140, 0)
	assert_int(rules.penalty_units).is_zero()
