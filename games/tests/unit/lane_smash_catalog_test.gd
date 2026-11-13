extends GdUnitTestSuite

func test_one_hundred_tracks_are_unique_reachable_and_single_lane() -> void:
	var names := {}
	var patterns := {}
	var themes := {}
	for minutes in LaneSmashCatalog.LENGTHS:
		var tracks := LaneSmashCatalog.tracks(minutes)
		assert_int(tracks.size()).is_equal(25)
		for item in tracks:
			var course := NeonCourse.load_course(item.id)
			assert_array(NeonCourse.validate(course)).override_failure_message(item.id).is_empty()
			assert_int(int(course.durationMs)).is_equal(minutes * 60000)
			names[item.id] = true
			patterns[JSON.stringify(course.events).sha256_text()] = true
			themes[course.theme] = true
			var end := 0
			for event: Dictionary in course.events:
				assert_int(NeonCourse.choices(event).size()).is_equal(1)
				assert_int(int(event.startMs) - end).is_less_equal(3000)
				end = int(event.endMs)
	assert_int(names.size()).is_equal(100)
	assert_int(patterns.size()).is_equal(100)
	assert_int(themes.size()).is_equal(8)

func test_random_tracks_reproduce_and_reject_invalid_ids() -> void:
	for minutes in LaneSmashCatalog.LENGTHS:
		for seed_value in [1, 17, 12345, 2147483646]:
			var id := LaneSmashCatalog.random_id(minutes, seed_value)
			var course := NeonCourse.load_course(id)
			assert_array(NeonCourse.validate(course)).is_empty()
			assert_str(NeonCourse.fingerprint(course)).is_equal(NeonCourse.fingerprint(NeonCourse.load_course(id)))
	for id in ["ls_15_00", "ls_15_26", "ls_5_01", "ls_r_15_0", "ls_r_15_2147483647", "ls_r_15_01"]:
		assert_dict(NeonCourse.load_course(id)).is_empty()

func test_cyclist_crank_tracks_actual_cadence() -> void:
	var bike := LaneSmashCyclist.new()
	add_child(bike)
	bike.animate(60, 0.25)
	assert_float(bike.crank_phase).is_equal_approx(PI / 2, 0.001)
	bike.animate(120, 0.25)
	assert_float(bike.crank_phase).is_equal_approx(3 * PI / 2, 0.001)
	var stopped := bike.crank_phase
	bike.animate(0, 0.25)
	assert_float(bike.crank_phase).is_equal(stopped)
	bike.free()

func test_road_grade_tracks_target_lane() -> void:
	var course := NeonCourse.load_course("ls_10_01")
	var space := NeonSpace.new()
	add_child(space)
	var low := course.duplicate(true)
	var high := course.duplicate(true)
	low.courseId = "low"
	high.courseId = "high"
	for event in low.events: event.laneIndex = 0
	for event in high.events: event.laneIndex = 5
	space.prepare_terrain(low)
	var low_grade := space.path(900).y - space.path(882).y
	space.prepare_terrain(high)
	var high_grade := space.path(900).y - space.path(882).y
	assert_float(high_grade).is_greater(low_grade + 5)
	space.free()


func test_distance_is_cadence_driven_capped_deterministic_and_pauses() -> void:
	var distances := {}
	for rpm in [60, 90, 140, 200]:
		var results := []
		for fps in [30, 60, 120]:
			var rules := NeonRules.new()
			rules.configure(NeonCourse.load_course("ls_10_01"), "intermediate", 150)
			var sample := 0
			for frame in range(1, fps * 10 + 1):
				var target := roundi(frame * 1000.0 / fps)
				while sample < target:
					rules.push_sample({"t": sample, "seq": sample + 1, "cadence": rpm, "power": 150, "resistance": 27})
					sample += 50
				rules.advance(target)
			results.append(rules.distance_units)
			assert_float(rules.speed_kph).is_less_equal(60.0)
			assert_float(rules.road_distance()).is_less_equal(10.0 * NeonRules.MAX_SPEED_MPS)
			rules.pause()
			var before := rules.distance_units
			rules.advance(12000)
			assert_int(rules.distance_units).is_equal(before)
		assert_int(results[0]).is_equal(results[1])
		assert_int(results[1]).is_equal(results[2])
		distances[rpm] = results[0]
	assert_int(distances[90]).is_greater(distances[60])
	assert_int(distances[140]).is_greater(distances[90])
	assert_int(distances[200]).is_equal(distances[140])

func test_every_duration_has_full_speed_road_and_random_visual_variation() -> void:
	var combinations := {}
	for minutes in LaneSmashCatalog.LENGTHS:
		for i in range(1, 401):
			var course := LaneSmashCatalog.load_track(LaneSmashCatalog.random_id(minutes, i * 9187))
			assert_float(float(course.roadLengthMeters)).is_greater(minutes * 60 * NeonRules.MAX_SPEED_MPS)
			combinations[course.theme + ":" + course.background] = true
	assert_int(combinations.size()).is_equal(32)


func test_ghost_has_real_distance_and_stays_out_of_view_when_far_away() -> void:
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("ls_10_01"), "intermediate", 150)
	var space := NeonSpace.new()
	add_child(space)
	space._warming = false
	space.ghost_distance = 10.0
	space.update_view(rules, 0, 0, 1, true, "")
	assert_bool(space.ghost.visible).is_true()
	var on_road := space.pose(10.0, (1.0 - 2.5) * NeonSpace.LANE_WIDTH, 0.05).origin
	assert_float(space.ghost.position.distance_to(on_road)).is_less(0.01)
	space.ghost_distance = 100.0
	space.update_view(rules, 0, 0, 1, true, "")
	assert_bool(space.ghost.visible).is_false()
	space.ghost_distance = -20.0
	rules.distance_units = 100000000
	space.ghost_distance = 80.0
	space.update_view(rules, 0, 0, 1, true, "")
	assert_bool(space.ghost.visible).is_false()
	space.free()


func test_front_wheel_shatters_all_marker_types_once_without_awarding_invalid_points() -> void:
	for kind in ["cruise", "hold", "burst"]:
		for correct_lane in [true, false]:
			var course := NeonCourse.load_course("ls_10_03")
			var event_index := 0
			while course.events[event_index].type != kind: event_index += 1
			var event: Dictionary = course.events[event_index]
			var rules := NeonRules.new()
			rules.configure(course, "challenging", 150)
			rules._event_cursor = event_index
			var space := NeonSpace.new()
			add_child(space)
			var anchor := int(event.startMs) / 1000.0 * NeonRules.MAX_SPEED_MPS
			var lane := float(event.laneIndex) if correct_lane else fmod(float(event.laneIndex) + 2, 6)
			# Start in front of the tire-contact plane, then move only 0.8m.
			# The axle/body remains well behind the marker when it must disappear.
			rules.distance_units = roundi((anchor - 2.5) * 1000000)
			space.update_view(rules, 0, lane, -1, false, "")
			assert_int(space.impact_count).is_zero()
			rules.distance_units = roundi((anchor - 1.7) * 1000000)
			space.update_view(rules, 0.05, lane, -1, false, "")
			assert_int(space.impact_count).is_equal(1 if correct_lane else 0)
			space.update_view(rules, 0, lane, -1, false, "")
			assert_int(space.impact_count).is_equal(1 if correct_lane else 0)
			assert_int(rules.score_units).is_zero()
			space.free()

func test_current_ranges_and_uninterrupted_zero_cadence() -> void:
	assert_dict(NeonRules.CURRENT_TIERS).is_equal({"light": 15, "moderate": 20, "hard": 25, "challenging": 30, "extreme": 35})
	assert_vector(NeonRules.band(0, "challenging")).is_equal(Vector2i(30, 36))
	assert_vector(NeonRules.band(5, "challenging")).is_equal(Vector2i(65, 71))
	assert_vector(NeonRules.band(5, "extreme")).is_equal(Vector2i(70, 76))
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("ls_10_01"), "extreme", 150)
	for t in range(0, 5000, 50):
		rules.push_sample({"t": t, "seq": t + 1, "cadence": 0, "power": 0, "resistance": 38})
		rules.advance(t + 50)
	assert_int(rules.elapsed_ms).is_equal(5000)
	assert_str(rules.pause_reason).is_empty()
	assert_int(rules.distance_units).is_zero()
	assert_int(rules.score_units).is_zero()

func test_background_reacts_smoothly_to_cadence_and_resistance() -> void:
	var sky := LaneSmashEnvironment.new()
	sky.configure(Environment.new())
	sky.update_environment("reactor", Color("5ba5df"), 60, 0.2, 0, false)
	sky.update_environment("reactor", Color("5ba5df"), 60, 0.2, 1, false)
	var slow := sky.flow_time
	sky.update_environment("reactor", Color("5ba5df"), 140, 1, 0, false)
	sky.update_environment("reactor", Color("5ba5df"), 140, 1, 1, false)
	assert_float(sky.flow_time - slow).is_greater(slow)
	assert_float(sky.resistance_mix).is_equal(1.0)
	var before := sky.flow_time
	sky.update_environment("reactor", Color("5ba5df"), 140, 1, 1, true)
	assert_float(sky.flow_time - before).is_less(slow)
	sky.free()

func test_all_tracks_change_lanes_frequently_with_short_holds_and_equal_effort_budgets() -> void:
	for minutes in LaneSmashCatalog.LENGTHS:
		var expected: Array = []
		var ids: Array = LaneSmashCatalog.tracks(minutes).map(func(t): return t.id)
		for seed_value in [1, 17, 12345, 2147483646]: ids.append(LaneSmashCatalog.random_id(minutes, seed_value))
		for id: String in ids:
			var course := LaneSmashCatalog.load_track(id)
			var budgets := [0, 0, 0, 0]
			var last_lane := -1
			var lane_since := 0
			var first_types := {}
			var lanes := {}
			for event: Dictionary in course.events:
				var span := int(event.endMs) - int(event.startMs)
				var lane := int(event.laneIndex)
				lanes[lane] = true
				if int(event.endMs) < 50000: first_types[event.type] = true
				if lane != last_lane:
					assert_int(int(event.startMs) - lane_since).override_failure_message(id).is_less_equal(21500)
					if last_lane >= 0: assert_int(absi(lane - last_lane)).is_less_equal(2)
					lane_since = int(event.startMs)
					last_lane = lane
				budgets[0] += span * lane
				budgets[1] += span
				if event.type == "hold":
					assert_int(span).is_equal(6000)
					budgets[2] += span * (int(event.cadenceMin) + 10)
				if event.type == "burst": budgets[3] += span
			assert_int(lanes.size()).is_equal(6)
			assert_int(first_types.size()).is_equal(3)
			if expected.is_empty(): expected = budgets
			assert_array(budgets).override_failure_message(id).is_equal(expected)
