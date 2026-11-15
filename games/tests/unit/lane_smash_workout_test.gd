extends GdUnitTestSuite
## Revision 16: authored transitions, timed cooldown and lane-checked incoming bombs.

func test_named_and_random_tracks_keep_work_high_and_every_lane_change_reachable() -> void:
	for minutes in LaneSmashCatalog.LENGTHS:
		var ids: Array = LaneSmashCatalog.tracks(minutes).map(func(row): return row.id)
		for seed_value in range(1, 65): ids.append(LaneSmashCatalog.random_id(minutes, seed_value * 9187))
		for id: String in ids:
			var course := NeonCourse.load_course(id)
			assert_array(NeonCourse.validate(course)).override_failure_message(id).is_empty()
			var previous := {}
			for event: Dictionary in course.events:
				var lane := int(event.laneIndex)
				if int(event.startMs) < LaneSmashCatalog.WARMUP_ROAD_MS: assert_int(lane).is_between(0, 1)
				else: assert_int(lane).is_between(2, 5)
				if not previous.is_empty():
					var jump := absi(lane - int(previous.laneIndex))
					assert_int(jump).override_failure_message(id).is_less_equal(3)
					if jump > 0:
						assert_int(int(event.startMs) - int(previous.endMs)).override_failure_message(id).is_greater_equal(LaneSmashCatalog.transition_gap(jump))
				previous = event
			var bomb_lanes := {}
			var last_lane := -1
			for attack: Dictionary in course.barrages:
				var lane := int(attack.laneIndex)
				assert_int(lane).is_between(2, 5)
				assert_int(lane).is_not_equal(last_lane)
				assert_int(int(attack.startMs) - int(attack.prepareMs)).is_equal(9000)
				bomb_lanes[lane] = true
				last_lane = lane
			assert_int(bomb_lanes.size()).override_failure_message(id).is_greater_equal(2)


func _attack(wrong: bool, frame_ms := 50, end_ms := 70000) -> NeonRules:
	var course: Dictionary = preload("res://tests/fixtures/catalog_v7.gd").load_track("ls_10_01")
	course.hazards = []
	course.barrages = [{"barrageId": "gated", "prepareMs": 51000, "startMs": 60000, "endMs": 95000, "slots": [0, 1], "laneIndex": 4}]
	var rules := NeonRules.new()
	assert_array(rules.configure(course, "challenging", 150)).is_empty()
	var next_sample := 0
	for until in range(frame_ms, end_ms + frame_ms, frame_ms):
		var end := mini(until, end_ms)
		while next_sample < end:
			# Input is independent of render cadence; lane 5 is reachable from warm-up lane 2.
			var lane := 0 if wrong else (4 if next_sample >= 51000 else 1)
			rules.push_sample({"t": next_sample, "seq": next_sample + 1, "cadence": 80, "power": 150, "resistance": NeonRules.band(lane, "challenging").x + 3})
			next_sample += 50
		rules.advance(end)
	return rules


func test_wrong_lane_drops_in_450ms_and_penalizes_once() -> void:
	var r := _attack(true)
	var shot: Dictionary = r.barrage.shots[0]
	assert_bool(shot.rapid).is_true()
	assert_int(int(shot.rapidMs)).is_equal(60000)
	assert_int(int(shot.impactMs)).is_equal(60450)
	assert_bool(shot.hit).is_true()
	assert_int(int(shot.points)).is_equal(-1800)
	assert_int(r.penalty_units).is_equal(1800 * NeonRules.UNIT)
	assert_int(r.barrage.shots.size()).is_equal(1)


func test_correct_lane_keeps_the_full_flight_and_speed_challenge() -> void:
	var r := _attack(false)
	var shot: Dictionary = r.barrage.shots[0]
	assert_bool(shot.get("rapid", false)).is_false()
	assert_int(int(shot.impactMs) - int(shot.fireMs)).is_equal(9000)
	assert_bool(shot.hit).is_true()  # holding baseline pace still does not dodge the blast
	assert_int(r.barrage.target_lane()).is_equal(4)


func test_entering_the_marked_footprint_in_the_wrong_lane_also_triggers_a_fast_drop() -> void:
	var r := _attack(false, 10, 60100)
	var shot := r.barrage.current_shot()
	while not shot.get("rapid", false) and r.elapsed_ms < 68000:
		var t := r.elapsed_ms
		var approaching := r.road_distance() >= float(shot.targetMeters) - LaneSmashBarrage.HALF_LENGTH - 5.0
		r.push_sample({"t": t, "seq": t + 1, "cadence": 140, "power": 200, "resistance": 33 if approaching else 61})
		r.advance(t + 50)
	assert_bool(shot.get("rapid", false)).is_true()
	assert_int(int(shot.rapidMs)).is_greater(60000)
	assert_int(int(shot.impactMs) - int(shot.rapidMs)).is_equal(450)


func test_fast_drop_keeps_its_visible_destination_and_only_explodes_once() -> void:
	var r := _attack(true, 10, 60200)
	var space: NeonSpace = auto_free(NeonSpace.new())
	add_child(space)
	space._warming = false
	space.update_view(r, 0, 0, -1, false, "")
	var shot := r.barrage.current_shot()
	var expected := space.pose(float(shot.targetMeters), -2.5 * NeonSpace.LANE_WIDTH, 0.12).origin
	assert_float(space.barrage_view.curve(1.0).distance_to(expected)).is_less(0.001)
	for t in range(60200, 60500, 50):
		r.push_sample({"t": t, "seq": t + 1, "cadence": 80, "power": 150, "resistance": 33})
		r.advance(t + 50)
		space.update_view(r, 0.05, 0, -1, false, "")
	assert_int(space.barrage_view.effects_count).is_equal(1)
	space.update_view(r, 0, 0, -1, false, "")
	assert_int(space.barrage_view.effects_count).is_equal(1)


func test_fast_drop_outcome_is_render_rate_independent_and_sensor_pause_freezes_it() -> void:
	var expected := _attack(true, 10).result()
	for frame_ms in [16, 33, 100]: assert_dict(_attack(true, frame_ms).result()).is_equal(expected)
	var r := _attack(true, 10, 60200)
	var shot := r.barrage.current_shot().duplicate(true)
	r.pause("sensor")
	r.advance(65000)
	assert_int(r.elapsed_ms).is_equal(60200)
	assert_dict(r.barrage.current_shot()).is_equal(shot)
	assert_bool(r.barrage.current_shot().resolved).is_false()


func test_final_minute_is_cooldown_at_every_speed_without_mutating_saved_course() -> void:
	for rpm in [0, 60, 95, 140]:
		var course := NeonCourse.load_course("ls_10_01")
		course.barrages = []
		var fingerprint := NeonCourse.fingerprint(course)
		var rules := NeonRules.new()
		assert_array(rules.configure(course, "challenging", 150)).is_empty()
		var previous := 0
		for t in range(0, 600000, 100):
			var target := int(rules.current_event().get("laneIndex", 0))
			if rules.cooldown:
				assert_int(target).is_less_equal(2)
				assert_int(absi(target - previous)).is_less_equal(3)
			previous = target
			rules.push_sample({"t": t, "seq": t + 1, "cadence": rpm, "power": 150, "resistance": NeonRules.band(target, "challenging").x + 3})
			rules.advance(t + 100)
			assert_bool(rules.cooldown).is_equal(t + 100 >= 540000)
		assert_str(NeonCourse.fingerprint(rules.course)).is_equal(fingerprint)
		assert_str(rules.result().status).is_equal("completed")
		assert_int(rules.events.size()).is_equal(rules.event_states.size())
		assert_int(int(rules.current_event().get("laneIndex", 0))).is_less_equal(1)


func test_jets_stay_anchored_outside_the_tail_at_all_pedalling_speeds() -> void:
	var bike: LaneSmashBike = auto_free(LaneSmashBike.new())
	add_child(bike)
	assert_int(bike.flames.size()).is_equal(2)
	for rpm in [20, 60, 95, 140]:
		bike.animate(rpm, 0)
		for jet in bike.flames:
			assert_bool(jet.visible).is_true()
			assert_float(jet.position.z).is_equal(LaneSmashBike.NOZZLE_AT.z)
			assert_float(absf(jet.position.x)).is_equal_approx(0.30, 0.00001)
			assert_float(jet.mesh.get_aabb().position.z).is_zero()
			assert_float(jet.scale.z).is_greater(0.45)
	bike.animate(0, 0)
	for jet in bike.flames: assert_bool(jet.visible).is_false()


func test_a_last_moment_wrong_lane_never_delays_the_existing_impact() -> void:
	var r := _attack(false, 10, 68800)
	var shot := r.barrage.current_shot()
	var original_impact := int(shot.impactMs)
	r.push_sample({"t": 68800, "seq": 68801, "cadence": 80, "power": 150, "resistance": 100})
	r.advance(68850)
	assert_bool(shot.get("rapid", false)).is_true()
	assert_int(int(shot.impactMs)).is_equal(original_impact)
	assert_int(int(shot.rapidLaneIndex)).is_equal(5)  # above range still renders in the far-right lane


func test_invalid_saved_bomb_schedules_are_rejected_before_inspection() -> void:
	for malformed: Variant in [null, "invalid", [null], [3], [{}]]:
		var course := NeonCourse.load_course("ls_10_01")
		course.barrages = malformed
		assert_array(NeonCourse.validate(course)).contains(["Invalid incoming-fire sections"])
	for missing in ["laneIndex", "prepareMs"]:
		var course := NeonCourse.load_course("ls_10_01")
		course.barrages[0].erase(missing)
		assert_array(NeonCourse.validate(course)).contains(["Invalid incoming-fire sections"])
