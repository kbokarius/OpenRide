extends GdUnitTestSuite
## Revision 19: reward timing, sustained sections, constant guidance, and dense fair mines.

func _bomb_rules(version := 11) -> NeonRules:
	var course := NeonCourse.load_course("ls_10_01")
	course.courseVersion = version
	course.events = [{"eventId": "long", "type": "cruise", "startMs": 0, "endMs": 10000, "laneIndex": 2}]
	course.hazards = []
	course.barrages = [{"barrageId": "test", "prepareMs": 51000, "startMs": 60000, "endMs": 95000, "slots": [0, 1], "laneIndex": 2}]
	var rules := NeonRules.new()
	assert_array(rules.configure(course, "challenging", 150)).is_empty()
	return rules

func _until(rules: NeonRules, until: int, rpm: float, lane := 2) -> void:
	while rules.elapsed_ms < until:
		var time := rules.elapsed_ms
		rules.push_sample({"t": time, "seq": time + 1, "cadence": rpm, "power": 150, "resistance": NeonRules.band_center(lane, "challenging")})
		rules.advance(mini(until, time + 10))

func test_pass_pays_on_full_clearance_before_impact_once() -> void:
	var rules := _bomb_rules()
	_until(rules, 60000, 80)
	var shot := rules.barrage.current_shot()
	var before_score := rules.score_units
	var previous_distance := rules.road_distance()
	while not bool(shot.resolved):
		previous_distance = rules.road_distance()
		_until(rules, rules.elapsed_ms + 10, 140)
	var edge := float(shot.targetMeters) + LaneSmashBarrage.HALF_LENGTH + LaneSmashBarrage.RIDER_RADIUS
	assert_float(previous_distance).is_less_equal(edge)
	assert_float(rules.road_distance()).is_greater(edge)
	assert_int(int(shot.resolvedMs)).is_less(int(shot.impactMs))
	assert_int(int(shot.points)).is_equal(1800)
	assert_int(rules.score_units - before_score).is_equal(1800 * NeonRules.UNIT)
	var awarded := rules.score_units
	_until(rules, 70000, 140)
	assert_int(rules.score_units).is_equal(awarded)
	assert_bool(shot.impactRecorded).is_true()
	assert_str(shot.outcome).is_equal("passed")

func test_popup_happens_at_clearance_but_bomb_explodes_at_impact() -> void:
	var rules := _bomb_rules()
	_until(rules, 60000, 80)
	var shot := rules.barrage.current_shot()
	while not bool(shot.resolved): _until(rules, rules.elapsed_ms + 10, 140)
	var space: NeonSpace = auto_free(NeonSpace.new())
	add_child(space)
	space._warming = false
	space.update_view(rules, 0, 2, -1, false, "")
	assert_int(space.barrage_view.effects_count).is_zero()
	assert_int(int(space.barrage_view.take_feedback().points)).is_equal(1800)
	space.update_view(rules, 0, 2, -1, false, "")
	assert_dict(space.barrage_view.take_feedback()).is_empty()
	_until(rules, int(shot.impactMs) + 10, 140)
	space.update_view(rules, 0, 2, -1, false, "")
	assert_int(space.barrage_view.effects_count).is_equal(1)
	assert_dict(space.barrage_view.take_feedback()).is_empty()

func test_waiting_behind_still_earns_zero_and_legacy_pass_waits_for_impact() -> void:
	var slow := _bomb_rules()
	_until(slow, 60000, 80)
	_until(slow, 68990, 45)
	assert_bool(slow.barrage.current_shot().resolved).is_false()
	_until(slow, 69000, 45)
	assert_str(slow.barrage.current_shot().outcome).is_equal("held_back")
	assert_int(int(slow.barrage.current_shot().points)).is_zero()
	var legacy := _bomb_rules(10)
	_until(legacy, 60000, 80)
	_until(legacy, 68990, 140)
	assert_bool(legacy.barrage.current_shot().resolved).is_false()
	_until(legacy, 69000, 140)
	assert_int(int(legacy.barrage.current_shot().points)).is_equal(1800)
	assert_bool(legacy.barrage.current_shot().has("resolvedMs")).is_false()

func test_every_track_has_full_sections_paired_cadence_and_guarded_mines() -> void:
	var burst_lengths := {}
	for minutes in LaneSmashCatalog.LENGTHS:
		var ids: Array = LaneSmashCatalog.tracks(minutes).map(func(row): return row.id)
		for seed_value in range(1, 33): ids.append(LaneSmashCatalog.random_id(minutes, seed_value * 947))
		for id: String in ids:
			var course := NeonCourse.load_course(id)
			assert_array(NeonCourse.validate(course)).override_failure_message(id).is_empty()
			assert_array(course.hazards).is_equal(LaneSmashHazards.generate_guarded(course.events))
			assert_int(course.hazards.size()).is_less_equal(LaneSmashHazards.DENSE_LIMIT)
			for event: Dictionary in course.events:
				var length := int(event.endMs) - int(event.startMs)
				if event.type == "burst":
					assert_int(length).is_between(5000, 7000)
					burst_lengths[length] = true
				else: assert_int(length).is_greater_equal(10000)
				if event.type == "hold" and int(event.startMs) >= LaneSmashCatalog.WARMUP_ROAD_MS:
					assert_int(int(event.cadenceMin)).is_equal([85, 85, 70, 70, 55, 55][int(event.laneIndex)])
					assert_int(int(event.cadenceMax) - int(event.cadenceMin)).is_equal(20)
	assert_int(burst_lengths.size()).is_equal(3)

func test_mines_penalize_each_wrong_lane_but_never_the_target_or_transition() -> void:
	for lane in 6:
		var course := NeonCourse.load_course("ls_10_01")
		course.events = [{"eventId": "mines", "type": "cruise", "startMs": 2000, "endMs": 12000, "laneIndex": 3}]
		course.barrages = []
		course.hazards = LaneSmashHazards.generate_dense(course.events)
		var rules := NeonRules.new()
		assert_array(rules.configure(course, "challenging", 150)).is_empty()
		rules.score_units = 5000 * NeonRules.UNIT
		_until(rules, 3790, 140, lane)
		assert_int(rules.penalty_units).is_zero()
		_until(rules, 3810, 140, lane)
		assert_int(rules.penalty_units).is_equal(0 if lane == 3 else 1800 * NeonRules.UNIT)
		assert_int(rules._hazard_cursor).is_equal(5)
		for mine: Dictionary in rules.hazards:
			assert_int(int(mine.hitMs)).is_between(3800, 10200)
			assert_int(int(mine.laneIndex)).is_not_equal(3)

func test_nightfall_return_has_full_section_no_extra_dead_block_and_matching_guidance() -> void:
	for minutes in LaneSmashCatalog.LENGTHS:
		var rules := NeonRules.new()
		var course := NeonCourse.load_course("ls_%d_01" % minutes)
		var original := NeonCourse.fingerprint(course)
		rules.configure(course, "challenging", 150)
		var returned := false
		var previous_attack := false
		for time in range(0, 145000, 50):
			var target := LaneSmashSteering.target_for(rules)
			assert_int(target).is_between(0, 5)
			var event := rules.current_event()
			var rpm := 80.0
			if event.get("type") == "hold": rpm = (float(event.cadenceMin) + float(event.cadenceMax)) * 0.5
			_until(rules, time + 50, rpm, target)
			if previous_attack and not rules.barrage.active:
				returned = true
				var next := rules.current_event()
				var gap := int(next.startMs) - rules.road_time_ms()
				assert_int(gap).is_between(6000, 9010)
				assert_int(int(next.endMs) - int(next.startMs)).is_greater_equal(5000 if next.type == "burst" else 10000)
				# The first return corridor starts at the actual attack endpoint, not an
				# authored event; gap_mines_test checks that runtime-only approach.
				var future_mines := rules.hazards.filter(func(row): return int(row.hitMs) >= int(next.startMs))
				assert_bool(LaneSmashHazards.valid_dense(future_mines, rules.events.slice(rules._event_cursor), true)).is_true()
				var hazard_ids := {}
				for hazard: Dictionary in rules.hazards: hazard_ids[hazard.hazardId] = true
				assert_int(hazard_ids.size()).is_equal(rules.hazards.size())
			previous_attack = rules.barrage.active
		assert_bool(returned).is_true()
		assert_str(NeonCourse.fingerprint(rules.course)).is_equal(original)

func test_incoming_fire_waits_for_the_final_marker_without_dimming_the_section() -> void:
	var rules := _bomb_rules()
	var course := rules.course.duplicate(true)
	course.events = [{"eventId": "before-attack", "type": "cruise", "startMs": 45000, "endMs": 55000, "laneIndex": 2}]
	assert_array(rules.configure(course, "challenging", 150)).is_empty()
	_until(rules, 52000, 140)
	assert_bool(rules.barrage.active).is_false()
	assert_float(rules.barrage.normal_alpha(rules.elapsed_ms)).is_equal(1.0)
	_until(rules, 55200, 140)
	assert_bool(rules.barrage.active).is_false()
	assert_float(rules.barrage.normal_alpha(rules.elapsed_ms)).is_greater(0.0)
	_until(rules, 55800, 140)
	assert_bool(rules.barrage.active).is_true()
	assert_int(int(rules.event_states[0].possibleMs)).is_greater_equal(10000)
	assert_int(int(rules.course.barrages[0].prepareMs)).is_equal(51000)

# End of flow regressions.
