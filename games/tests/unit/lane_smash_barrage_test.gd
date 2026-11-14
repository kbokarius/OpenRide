extends GdUnitTestSuite

func _course() -> Dictionary:
	var course := NeonCourse.load_course("ls_10_01")
	course.events = [{"eventId": "road", "type": "cruise", "startMs": 0, "endMs": 600000, "laneIndex": 0}]
	course.hazards = []
	course.barrages = [{"barrageId": "test", "startMs": 60000, "endMs": 95000, "slots": [0, 1]}]
	return course

func _run(baseline: float, change: float, reaction_ms: int, ramp_ms: int, fps := 60, lane := 0, end_ms := 78000) -> NeonRules:
	var r := NeonRules.new()
	assert_array(r.configure(_course(), "challenging", 150)).is_empty()
	var next_sample := 0
	var target := 0
	while target < end_ms:
		target = mini(end_ms, target + roundi(1000.0 / fps))
		while next_sample < target:
			var blend := clampf((next_sample - 66000 - reaction_ms) / float(maxi(1, ramp_ms)), 0, 1)
			var rpm := clampf(baseline + change * blend, 0, 140)
			r.push_sample({"t": next_sample, "seq": next_sample + 1, "cadence": rpm, "power": 150, "resistance": 33 + lane * 7})
			next_sample += 50
		r.advance(target)
	return r

func test_gradual_acceleration_and_deceleration_with_reaction_time_evade() -> void:
	for baseline in [80, 95]:
		var change := 40.0 if baseline == 80 else -40.0
		var r := _run(baseline, change, 2000, 4000)
		var shot: Dictionary = r.barrage.shots[0]
		assert_bool(shot.resolved).is_true()
		assert_bool(shot.hit).is_false()
		assert_int(shot.points).is_equal(1800 if baseline == 80 else 0)
		assert_float(absf(shot.impactRiderMeters - shot.targetMeters)).is_greater(21.5)
		assert_int(r.penalty_units).is_zero()

func test_small_changes_or_steering_cannot_evade() -> void:
	for change in [-15.0, 0.0, 15.0]:
		var r := _run(80, change, 0, 1)
		assert_bool(r.barrage.shots[0].hit).is_true()
		assert_int(r.barrage.shots[0].points).is_equal(-1800)
		assert_int(r.penalty_units).is_equal(1800 * NeonRules.UNIT)
	for lane in 6:
		var r := _run(80, 0, 0, 1, 60, lane)
		assert_bool(r.barrage.shots[0].hit).is_true()
	var mild := _run(80, 25, 2000, 4000)
	assert_bool(mild.barrage.shots[0].hit).is_true()

func test_targets_outcomes_and_scores_match_across_frame_rates() -> void:
	var previous: Dictionary = {}
	for fps in [30, 60, 120]:
		var r := _run(80, 40, 2000, 4000, fps)
		var snapshot := {"shot": r.barrage.shots[0], "score": r.score_units, "distance": r.distance_units, "ghost": r.ghost_trace}
		if not previous.is_empty(): assert_dict(snapshot).is_equal(previous)
		previous = snapshot

func test_recommendations_have_headroom_and_substantial_changes() -> void:
	for baseline in range(141):
		for ordinal in 2:
			var target := LaneSmashBarrage.target_cadence(baseline, ordinal)
			assert_int(target).is_between(45, 120)
			assert_int(absi(target - baseline)).is_greater_equal(35)

func test_all_track_schedules_are_seeded_bounded_and_clear_the_finish() -> void:
	for minutes in LaneSmashCatalog.LENGTHS:
		var ids: Array = LaneSmashCatalog.tracks(minutes).map(func(t): return t.id)
		for seed_value in [1, 17, 12345, 2147483646]: ids.append(LaneSmashCatalog.random_id(minutes, seed_value))
		for id: String in ids:
			var course := NeonCourse.load_course(id)
			assert_array(course.barrages).is_not_empty()
			assert_bool(LaneSmashBarrage.valid(course.barrages, course.durationMs)).is_true()
			assert_array(course.barrages).is_equal(NeonCourse.load_course(id).barrages)
			assert_int(course.barrages[-1].endMs).is_less_equal(course.durationMs - 60000)
	var broken := _course()
	broken.barrages[0].slots = [0, 0]
	assert_array(NeonCourse.validate(broken)).is_not_empty()

func test_target_stays_fixed_and_pause_cannot_advance_attack() -> void:
	var r := _run(80, 40, 2000, 4000)
	var shot: Dictionary = r.barrage.shots[0].duplicate(true)
	var score := r.score_units
	r.pause("sensor")
	r.advance(120000)
	assert_int(r.elapsed_ms).is_equal(78000)
	assert_dict(r.barrage.shots[0]).is_equal(shot)
	assert_int(r.score_units).is_equal(score)

func test_legacy_bomb_courses_keep_original_identity_and_no_barrages() -> void:
	var course := _course()
	course.erase("barrages")
	course.courseVersion = 5
	course.generatorVersion = 3
	var rules := NeonRules.new()
	assert_array(rules.configure(course, "challenging", 150)).is_empty()
	assert_int(rules.scoring_version).is_equal(4)
	assert_array(rules.barrage.schedule).is_empty()
	var key := JSON.stringify(["rider", NeonCourse.fingerprint(course), "challenging", 1, 4, 150.0], "", true, true).sha256_text()
	assert_str(rules.comparison_key("rider")).is_equal(key)

func test_midflight_sensor_interruption_freezes_target_and_resumes_same_outcome() -> void:
	var r := _run(80, 40, 2000, 4000, 60, 0, 71000)
	var shot: Dictionary = r.barrage.shots[0].duplicate(true)
	var distance := r.distance_units
	assert_bool(shot.resolved).is_false()
	r.pause("sensor")
	r.advance(150000)
	assert_int(r.elapsed_ms).is_equal(71000)
	assert_int(r.distance_units).is_equal(distance)
	assert_dict(r.barrage.shots[0]).is_equal(shot)
	r.resume()
	for t in range(71000, 78000, 50):
		var rpm := lerpf(80, 120, clampf((t - 68000) / 4000.0, 0, 1))
		r.push_sample({"t": t, "seq": t + 1, "cadence": rpm, "power": 150, "resistance": 33})
		r.advance(t + 50)
	assert_dict(r.barrage.shots[0]).is_equal(_run(80, 40, 2000, 4000).barrage.shots[0])

func test_flight_endpoint_matches_locked_target_and_impact_feedback_is_once() -> void:
	var r := _run(80, 40, 2000, 4000, 60, 0, 71000)
	var space := NeonSpace.new()
	add_child(space)
	space._warming = false
	space.update_view(r, 0, 0, -1, false, "")
	var view := space.barrage_view
	var target := space.pose(float(r.barrage.shots[0].targetMeters), 0, 0.12).origin
	assert_float(view.curve(1).distance_to(target)).is_less(0.001)
	var source := view.curve(0)
	for t in range(71000, 78000, 50):
		var rpm := lerpf(80, 120, clampf((t - 68000) / 4000.0, 0, 1))
		r.push_sample({"t": t, "seq": t + 1, "cadence": rpm, "power": 150, "resistance": 33})
		r.advance(t + 50)
		space.update_view(r, 0.05, 0, -1, false, "")
	assert_float(view.curve(0).distance_to(source)).is_less(0.001)
	assert_float(view.curve(1).distance_to(target)).is_less(0.001)
	assert_int(view.effects_count).is_equal(1)
	assert_int(view.take_feedback().points).is_equal(1800)
	assert_dict(view.take_feedback()).is_empty()
	space.free()

func test_malformed_attack_configuration_is_rejected_without_type_errors() -> void:
	for value in [null, 1, "attack", true, {}, [null], [{"barrageId": 1}]]:
		assert_bool(LaneSmashBarrage.valid(value, 600000)).is_false()
	for key in ["startMs", "endMs", "slots"]:
		for value in [null, true, {}, "60000", INF, NAN]:
			var data: Array = _course().barrages.duplicate(true)
			data[0][key] = value
			assert_bool(LaneSmashBarrage.valid(data, 600000)).is_false()

func test_legacy_incoming_fire_keeps_points_for_slowing_down() -> void:
	var course := _course()
	course.courseVersion = 6
	var r := NeonRules.new()
	r.configure(course, "challenging", 150)
	for t in range(0, 78000, 50):
		var rpm := lerpf(95, 55, clampf((t - 68000) / 4000.0, 0, 1))
		r.push_sample({"t": t, "seq": t + 1, "cadence": rpm, "power": 150, "resistance": 33})
		r.advance(t + 50)
	assert_int(r.scoring_version).is_equal(5)
	assert_int(r.barrage.shots[0].points).is_equal(100)

func test_slow_evade_awards_no_score_but_keeps_avoidance_star_credit() -> void:
	var r := _run(95, -40, 2000, 4000)
	assert_int(r.barrage.shots[0].points).is_zero()
	assert_str(r.barrage.shots[0].outcome).is_equal("held_back")
	assert_int(r.base_units).is_greater(r.score_units)
	assert_int(r.penalty_units).is_zero()
