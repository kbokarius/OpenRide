extends GdUnitTestSuite
## A highlighted lane is a promise of content, including around active-time attacks/cooldown.

func _rules(events: Array, version := 12) -> NeonRules:
	var course := NeonCourse.load_course("ls_10_01")
	course.courseVersion = version
	course.events = events
	course.hazards = []
	course.barrages = [{"barrageId": "handoff", "prepareMs": 51000, "startMs": 60000, "endMs": 95000, "laneIndex": 2, "slots": [0, 1]}]
	var rules := NeonRules.new()
	assert_array(rules.configure(course, "challenging", 150)).is_empty()
	return rules

func _until(rules: NeonRules, end: int) -> void:
	while rules.elapsed_ms < end:
		var time := rules.elapsed_ms
		rules.push_sample({"t": time, "seq": time + 1, "cadence": 140, "power": 150,
			"resistance": NeonRules.band_center(LaneSmashSteering.target_for(rules), rules.tier)})
		rules.advance(mini(time + 50, end))

func test_attack_honors_a_lane_already_announced_during_its_approach() -> void:
	var rules := _rules([
		{"eventId": "first", "type": "cruise", "startMs": 40000, "endMs": 50000, "laneIndex": 2},
		{"eventId": "promised", "type": "cruise", "startMs": 61000, "endMs": 71000, "laneIndex": 5}])
	_until(rules, 50500)
	assert_int(LaneSmashSteering.target_for(rules)).is_equal(5)
	_until(rules, 70500)
	assert_bool(rules.barrage.active).is_false()
	assert_int(LaneSmashSteering.target_for(rules)).is_equal(5)
	_until(rules, 72000)
	assert_bool(rules.barrage.active).is_true()
	assert_int(int(rules.event_states[1].possibleMs)).is_greater_equal(9990)
	assert_int(int(rules.event_states[1].scoreUnits)).is_greater(0)
	assert_int(int(rules.course.barrages[0].prepareMs)).is_equal(51000)

func test_final_marker_fade_does_not_flash_the_following_ordinary_lane() -> void:
	var rules := _rules([
		{"eventId": "first", "type": "cruise", "startMs": 45000, "endMs": 55000, "laneIndex": 2},
		{"eventId": "later", "type": "cruise", "startMs": 64000, "endMs": 74000, "laneIndex": 5}])
	_until(rules, 54500)
	for time in range(54500, 56000, 50):
		_until(rules, time + 50)
		assert_int(LaneSmashSteering.target_for(rules)).override_failure_message("Phantom lane at %d" % time).is_equal(2)
	assert_bool(rules.barrage.active).is_true()
	assert_int(int(rules.event_states[0].possibleMs)).is_greater_equal(9990)

func test_cooldown_delivers_content_in_a_lane_already_requested() -> void:
	var rules := _rules([
		{"eventId": "work", "type": "cruise", "startMs": 525000, "endMs": 535000, "laneIndex": 2},
		{"eventId": "promised", "type": "cruise", "startMs": 548000, "endMs": 558000, "laneIndex": 5}])
	rules.barrage.schedule = []
	_until(rules, 539500)
	assert_int(LaneSmashSteering.target_for(rules)).is_equal(5)
	_until(rules, 540000)
	assert_bool(rules.cooldown).is_true()
	assert_int(LaneSmashSteering.target_for(rules)).is_equal(5)
	var first := rules.current_event()
	assert_int(int(first.endMs) - int(first.startMs)).is_greater_equal(10000)
	_until(rules, int(first.endMs) + 50)
	assert_int(LaneSmashSteering.target_for(rules)).is_equal(2)
	assert_int(int(rules.event_states[rules._event_cursor - 1].scoreUnits)).is_greater(0)

func test_saved_course_eleven_keeps_its_original_attack_timing() -> void:
	var rules := _rules([
		{"eventId": "first", "type": "cruise", "startMs": 40000, "endMs": 50000, "laneIndex": 2},
		{"eventId": "promised", "type": "cruise", "startMs": 61000, "endMs": 71000, "laneIndex": 5}], 11)
	_until(rules, 51500)
	assert_int(rules.scoring_version).is_equal(10)
	assert_bool(rules.barrage.active).is_true()

func test_cooldown_waits_for_a_cadence_section_that_just_started() -> void:
	var rules := _rules([{"eventId":"late-hold", "type":"hold", "startMs":539000, "endMs":549000, "laneIndex":5, "cadenceMin":55, "cadenceMax":75}])
	rules.barrage.schedule = []
	_until(rules,540000)
	assert_bool(rules.cooldown).is_false()
	assert_bool(rules.cadence_target().active).is_true()
	_until(rules,549050)
	assert_bool(rules.cooldown).is_true()
	assert_int(int(rules.event_states[0].possibleMs)).is_greater_equal(9990)
	assert_bool(rules.event_states[0].get("closed",false)).is_false()
