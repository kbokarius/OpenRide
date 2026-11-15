extends GdUnitTestSuite
## Kid halves the resistance step; all scoring and visual lane consumers share the mapping.

const BANDS := [Vector2i(0, 3), Vector2i(4, 6), Vector2i(7, 10), Vector2i(11, 13), Vector2i(14, 17), Vector2i(18, 20)]

func _course() -> Dictionary:
	var course := NeonCourse.load_course("ls_10_01")
	course.events = [{"eventId": "kid-collect", "type": "cruise", "startMs": 0, "endMs": 10000, "laneIndex": 2}]
	course.barrages = []
	course.hazards = []
	return course

func _run(rules: NeonRules, until: int, resistance: float, rpm := 140.0) -> void:
	while rules.elapsed_ms < until:
		var t := rules.elapsed_ms
		assert_bool(rules.push_sample({"t": t, "seq": t + 1, "cadence": rpm, "power": 150, "resistance": resistance})).is_true()
		rules.advance(mini(until, t + 50))

func test_kid_has_half_the_step_and_no_gaps_or_overlapping_integer_ranges() -> void:
	assert_float(NeonRules.lane_step("kid")).is_equal(3.5)
	assert_float(NeonRules.lane_step("light")).is_equal(7.0)
	for lane in 6:
		assert_vector(NeonRules.band(lane, "kid")).is_equal(BANDS[lane])
		for resistance in range(BANDS[lane].x, BANDS[lane].y + 1):
			assert_int(NeonRules.lane_for(resistance, "kid")).is_equal(lane)
		assert_int(NeonRules.lane_for(NeonRules.band_center(lane, "kid"), "kid")).is_equal(lane)
	for resistance in [-1.0, 3.5, 20.5, 21.0, 100.0, NAN, INF]:
		assert_int(NeonRules.lane_for(resistance, "kid")).is_equal(-1)
	assert_int(NeonRules.clamped_lane_for(-20, "kid")).is_equal(0)
	assert_int(NeonRules.clamped_lane_for(100, "kid")).is_equal(5)

func test_zero_resistance_is_valid_and_each_new_lane_still_settles() -> void:
	var rules := NeonRules.new()
	assert_array(rules.configure(_course(), "kid", 150)).is_empty()
	_run(rules, 200, 0)
	assert_str(rules.pause_reason).is_empty()
	assert_int(rules.settled_lane).is_equal(0)
	_run(rules, 210, 4)
	assert_int(rules.selected_lane).is_equal(1)
	assert_int(rules.settled_lane).is_equal(-1)
	_run(rules, 400, 4)
	assert_int(rules.settled_lane).is_equal(1)

func test_kid_steering_crosses_every_threshold_smoothly_at_multiple_frame_rates() -> void:
	for fps in [30, 60, 120]:
		for lane in range(1, 6):
			var steering := LaneSmashSteering.new()
			steering.update(0, BANDS[lane - 1].y, "kid", lane)
			var previous := steering.lane
			var destination := LaneSmashSteering.position_for(BANDS[lane].x, "kid")
			for frame in int(fps * 0.2):
				steering.update(1.0 / fps, BANDS[lane].x, "kid", lane)
				assert_float(steering.lane).is_between(previous, destination)
				previous = steering.lane
			assert_float(absf(steering.lane - destination)).is_less(0.01)
			assert_int(steering.direction).is_zero()

func test_kid_target_lane_is_clear_and_mines_penalize_each_wrong_lane_once() -> void:
	var course := _course()
	course.hazards = LaneSmashHazards.generate_dense(course.events)
	for lane in 6:
		var rules := NeonRules.new()
		assert_array(rules.configure(course, "kid", 150)).is_empty()
		rules.score_units = 10000 * NeonRules.UNIT
		_run(rules, 2500, NeonRules.band_center(lane, "kid"))
		assert_int(rules.selected_lane).is_equal(lane)
		assert_int(rules.penalty_units).is_equal((0 if lane == 2 else 1800) * NeonRules.UNIT)
		assert_int(rules.hazard_states.filter(func(state): return state.hit).size()).is_equal(0 if lane == 2 else 1)

func test_wrong_lane_rapid_bomb_uses_kid_lane_not_the_old_seven_point_math() -> void:
	for wrong in [false, true]:
		var course := _course()
		course.barrages = [{"barrageId": "kid-bomb", "prepareMs": 51000, "startMs": 60000, "endMs": 95000, "slots": [0, 1], "laneIndex": 2}]
		var rules := NeonRules.new()
		assert_array(rules.configure(course, "kid", 150)).is_empty()
		_run(rules, 59900, 8, 80)
		_run(rules, 60600, 18 if wrong else 8, 80)
		var shot := rules.barrage.current_shot()
		assert_bool(shot.get("rapid", false)).is_equal(wrong)
		if wrong:
			assert_int(int(shot.rapidLaneIndex)).is_equal(5)
			assert_int(int(shot.impactMs)).is_equal(60450)
			assert_bool(shot.hit).is_true()
		else:
			assert_int(int(shot.impactMs)).is_equal(69000)
			assert_bool(shot.resolved).is_false()

func test_outside_range_message_and_ride_label_use_kid_limits() -> void:
	var rules := NeonRules.new()
	rules.configure(_course(), "kid", 150)
	_run(rules, 1000, 21)
	var status: NeonStatus = auto_free(NeonStatus.new())
	status.rules = rules
	add_child(status)
	status.refresh()
	assert_str(status.target.text).is_equal("Lower resistance to 20")
	var game: Node = auto_free(load("res://games/neon_vector/NeonVector.gd").new())
	game.rules = rules
	assert_str(game.target_text({})).contains("Kid · 0–20 resistance")

# End of suite.
