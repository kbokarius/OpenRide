extends GdUnitTestSuite

func _ride(rpm: float, watts := 150, lane := 2, version := 12, step := 50) -> NeonRules:
	var course := NeonCourse.load_course("ls_10_01")
	course.courseVersion = version
	course.events = [{"eventId": "burst", "type": "burst", "startMs": 2000, "endMs": 8000, "laneIndex": 2}]
	course.phases = [{"name":"Work", "role":"work", "startMs":0, "endMs":600000}]
	course.hazards = []
	course.barrages = []
	var rules := NeonRules.new()
	var errors := rules.configure(course, "challenging", 150)
	assert_array(errors).is_empty()
	if not errors.is_empty(): return rules
	while rules.road_time_ms() < 8100 and rules.elapsed_ms < 600000 and rules.pause_reason.is_empty():
		var time := rules.elapsed_ms
		rules.push_sample({"t": time, "seq": time + 1, "cadence": rpm, "power": watts, "resistance": NeonRules.band_center(lane, rules.tier)})
		rules.advance(time + step)
	return rules

func test_full_burst_rewards_speed_proportionally_even_though_slow_pass_takes_longer() -> void:
	var at_90 := _ride(90)
	var baseline := float(at_90.score_units)
	for rpm in [30, 45, 60, 90, 120, 140]:
		var rules := _ride(rpm)
		assert_float(float(rules.score_units) / baseline).override_failure_message("rpm=%d" % rpm).is_equal_approx(rpm / 90.0, 0.005)
		assert_int(rules.base_units).is_equal(rules.score_units)
		assert_float(float(rules.base_units) / rules.max_base_units).is_greater(0.99)
	assert_int(_ride(45).elapsed_ms).is_greater(at_90.elapsed_ms)
	assert_int(_ride(45).score_units).is_less(at_90.score_units)
	# Exactly the old energy reward at the reference pace; old snapshots remain unchanged.
	assert_int(at_90.score_units).is_equal(_ride(90, 150, 2, 11).score_units)
	assert_int(_ride(45, 150, 2, 11).score_units).is_greater(_ride(90, 150, 2, 11).score_units)

func test_power_still_matters_but_wrong_lane_and_coasting_do_not_earn() -> void:
	var normal := _ride(90)
	assert_int(_ride(90, 300).score_units).is_equal(normal.score_units * 2)
	assert_int(_ride(90, 0).score_units).is_zero()
	assert_int(_ride(90, 150, 1).score_units).is_zero()
	assert_int(_ride(19).score_units).is_zero()
	assert_int(_ride(200).score_units).is_equal(_ride(140).score_units)

func test_speed_reward_is_identical_across_advance_batch_sizes() -> void:
	var expected := _ride(90, 240, 2, 12, 10)
	for step in [20, 50, 100]:
		var actual := _ride(90, 240, 2, 12, step)
		assert_int(actual.score_units).is_equal(expected.score_units)
		assert_array(actual.event_states).is_equal(expected.event_states)
