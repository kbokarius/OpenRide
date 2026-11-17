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

func test_new_kid_cadence_is_halved_for_every_named_and_seeded_course() -> void:
	for minutes in LaneSmashCatalog.LENGTHS:
		var ids: Array[String] = []
		for index in 25: ids.append("ls_%d_%02d" % [minutes, index + 1])
		for seed_value in [1, 77, 104729, 2147483646]: ids.append(LaneSmashCatalog.random_id(minutes, seed_value))
		for id in ids:
			var original := NeonCourse.load_course(id)
			var fingerprint := NeonCourse.fingerprint(original)
			var kid := NeonCourse.for_difficulty(original, "kid")
			assert_array(NeonCourse.validate(kid)).is_empty()
			assert_str(NeonCourse.fingerprint(original)).is_equal(fingerprint)
			assert_str(NeonCourse.fingerprint(kid)).is_not_equal(fingerprint)
			assert_dict(NeonCourse.for_difficulty(kid, "kid")).is_equal(kid)
			for i in original.events.size():
				var before: Dictionary = original.events[i]
				var after: Dictionary = kid.events[i]
				if before.type == "hold":
					var expected: Vector2i = {75: Vector2i(38, 48), 85: Vector2i(43, 53), 70: Vector2i(35, 45), 55: Vector2i(28, 38)}[int(before.cadenceMin)]
					assert_vector(Vector2i(after.cadenceMin, after.cadenceMax)).is_equal(expected)
				else:
					assert_dict(after).is_equal(before)
			for tier in ["light", "moderate", "hard", "challenging", "extreme"]:
				assert_str(NeonCourse.fingerprint(NeonCourse.for_difficulty(original, tier))).is_equal(fingerprint)


func test_kid_cadence_scoring_gunfire_meter_and_prompt_share_lower_targets() -> void:
	var course := _course()
	course.events = [{"eventId": "kid-hold", "type": "hold", "startMs": 0, "endMs": 10000, "laneIndex": 2, "cadenceMin": 75, "cadenceMax": 95}]
	var rules := NeonRules.new()
	assert_array(rules.configure(NeonCourse.for_difficulty(course, "kid"), "kid", 150)).is_empty()
	_run(rules, 4000, 8, 43)
	assert_int(rules.score_units).is_greater(0)
	assert_int(rules.gun_hits).is_zero()
	var live := rules.cadence_target()
	assert_bool(live.inBand).is_true()
	assert_bool(live.inSweet).is_true()
	assert_int(live.cadenceMin).is_equal(38)
	assert_int(live.cadenceMax).is_equal(48)
	assert_int(rules.gunfire().cadenceMin).is_equal(38)
	var gauge := LaneSmashCadenceGauge.new()
	gauge.update(0, live, Vector2(960, 700), Rect2(0, 340, 1920, 500))
	assert_str(gauge.state()).is_equal("sweet")
	var status: NeonStatus = auto_free(NeonStatus.new())
	status.rules = rules
	add_child(status)
	status.refresh()
	assert_str(status.target.text).contains("38–48 rpm")
	_run(rules, 7000, 8, 75)
	assert_bool(rules.cadence_target().inBand).is_false()
	assert_int(rules.gun_hits).is_greater(0)


func test_kid_snapshot_replays_without_halving_again_and_adult_keys_stay_stable() -> void:
	var original := NeonCourse.load_course("ls_20_01")
	var old := NeonRules.new()
	var current := NeonRules.new()
	var replay := NeonRules.new()
	assert_array(old.configure(original, "kid", 150)).is_empty()
	assert_array(current.configure(NeonCourse.for_difficulty(original, "kid"), "kid", 150)).is_empty()
	assert_array(replay.configure(JSON.parse_string(JSON.stringify(current.course, "", true, true)), "kid", 150)).is_empty()
	assert_str(current.comparison_key("1")).is_not_equal(old.comparison_key("1"))
	assert_str(replay.comparison_key("1")).is_equal(current.comparison_key("1"))
	assert_dict(replay.events[1]).is_equal(JSON.parse_string(JSON.stringify(current.events[1], "", true, true)))
	assert_int(old.events[1].cadenceMin).is_equal(75)
	assert_int(int(replay.events[1].cadenceMin)).is_equal(38)
	for tier in ["light", "moderate", "hard", "challenging", "extreme"]:
		old.configure(original, tier, 150)
		current.configure(NeonCourse.for_difficulty(original, tier), tier, 150)
		assert_str(current.comparison_key("1")).is_equal(old.comparison_key("1"))
