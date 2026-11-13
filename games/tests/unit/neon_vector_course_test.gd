extends GdUnitTestSuite


func test_library_has_ten_valid_complete_courses() -> void:
	var courses := NeonCourse.library()
	assert_int(courses.size()).is_equal(10)
	for course in courses:
		assert_array(NeonCourse.validate(course)).is_empty()
		assert_int(NeonCourse.maximum(course)).is_greater(0)
		assert_int(int(course.events[0].startMs)).is_equal(3000)
		for tier in NeonRules.TIERS:
			var rules := NeonRules.new()
			assert_array(rules.configure(course, tier, 150)).is_empty()
			assert_int(rules.max_units).is_equal(NeonCourse.maximum(course))


func test_a_year_of_daily_courses_is_valid_and_reproducible() -> void:
	var hashes := {}
	for day in range(1, 366):
		var date := "2026-day-%03d" % day
		var a := NeonCourse.daily(date)
		var b := NeonCourse.daily(date)
		assert_array(NeonCourse.validate(a)).is_empty()
		assert_str(NeonCourse.fingerprint(a)).is_equal(NeonCourse.fingerprint(b))
		hashes[NeonCourse.fingerprint(a)] = true
	assert_int(hashes.size()).is_equal(365)


func test_rejects_conflicting_unreachable_and_out_of_course_events() -> void:
	var course := NeonCourse.load_course("steady_flow_10")
	var overlapping := course.duplicate(true)
	overlapping.events[1].startMs = 8000
	assert_array(NeonCourse.validate(overlapping)).is_not_empty()
	var unreachable := course.duplicate(true)
	unreachable.events[2].startMs = 35000
	unreachable.events[2].hitMs = 35250
	unreachable.events[2].endMs = 35510
	unreachable.events[2].laneIndex = 5
	assert_array(NeonCourse.validate(unreachable)).is_not_empty()
	var outside := course.duplicate(true)
	outside.events[-1].endMs = int(course.durationMs) + 10
	assert_array(NeonCourse.validate(outside)).is_not_empty()
	var duplicate := course.duplicate(true)
	duplicate.events[1].eventId = duplicate.events[0].eventId
	assert_array(NeonCourse.validate(duplicate)).is_not_empty()


func test_comparison_identity_separates_course_tier_targets_and_riders() -> void:
	var course := NeonCourse.load_course("steady_flow_10")
	var keys := {}
	for tier in NeonRules.TIERS:
		for power in [150, 151]:
			var rules := NeonRules.new()
			rules.configure(course, tier, power)
			for rider in ["a", "b"]:
				keys[rules.comparison_key(rider)] = true
	assert_int(keys.size()).is_equal(NeonRules.TIERS.size() * 4)
	var r := NeonRules.new()
	r.configure(course, "intermediate", 150)
	var old := r.comparison_key("a")
	course.courseVersion = 3
	for event in course.events: event.erase("alternatives")
	assert_array(r.configure(course, "intermediate", 150)).is_empty()
	assert_str(r.comparison_key("a")).is_not_equal(old)


func test_daily_recovery_stays_gentle_and_bonus_routes_always_raise_resistance() -> void:
	var original := NeonCourse.load_course("steady_flow_20")
	var patterns := {}
	for day in 365:
		var course := NeonCourse.daily(Time.get_date_string_from_unix_time(1767225600 + day * 86400))
		patterns[JSON.stringify(course.events).sha256_text()] = true
		for i in course.events.size():
			var event: Dictionary = course.events[i]
			for phase: Dictionary in course.phases:
				if int(event.startMs) >= int(phase.startMs) and int(event.startMs) < int(phase.endMs) and phase.role != "work":
					assert_int(int(event.laneIndex)).is_equal(int(original.events[i].laneIndex))
			if event.has("alternatives"):
				assert_int(int(event.alternatives[1].laneIndex)).is_greater(int(event.alternatives[0].laneIndex))
				assert_int(int(event.alternatives[1].rewardPercent)).is_equal(125)
				assert_int(int(event.laneIndex)).is_equal(int(event.alternatives[0].laneIndex))
	assert_int(patterns.size()).is_greater(200)


func test_v2_courses_keep_scoring_frequent_and_all_three_mechanics() -> void:
	for course in NeonCourse.library():
		var active := 0
		var end := 0
		var types := {}
		for event: Dictionary in course.events:
			assert_int(int(event.startMs) - end).is_less_equal(3000)
			active += int(event.endMs) - int(event.startMs)
			end = int(event.endMs)
			types[event.type] = true
		assert_int(active * 100 / int(course.durationMs)).is_equal(85)
		assert_bool(types.has_all(["cruise", "hold", "burst"])).is_true()
