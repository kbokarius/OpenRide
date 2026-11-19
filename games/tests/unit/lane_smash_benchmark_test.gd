extends GdUnitTestSuite

var _old_path := ""


func before_test() -> void:
	_old_path = NeonRecords.path
	NeonRecords.path = "user://benchmark_test_" + NeonRecords.new_id()
	DirAccess.make_dir_recursive_absolute(NeonRecords.path)


func after_test() -> void:
	for file in DirAccess.get_files_at(NeonRecords.path):
		DirAccess.remove_absolute(NeonRecords.path.path_join(file))
	DirAccess.remove_absolute(NeonRecords.path)
	NeonRecords.path = _old_path


func _rules(old := false, tier := "hard", id := "ls_20_05") -> NeonRules:
	var course := NeonCourse.for_difficulty(NeonCourse.load_course(id), tier)
	if old:
		course.courseVersion = 12
		course.generatorVersion = 9
		course.hazards = LaneSmashHazards.generate_dense(course.events)
	var rules := NeonRules.new()
	assert_array(rules.configure(course, tier, 150)).is_empty()
	return rules


func _save(rules: NeonRules, points: int, rider := "1", complete := true) -> Dictionary:
	var record := {"version": 1, "attemptId": NeonRecords.new_id(), "riderId": rider,
		"comparisonKey": rules.comparison_key(rider), "course": rules.course, "result": rules.result("pending"), "ghost": []}
	assert_bool(NeonRecords.local_request({"action": "save", "record": record}, rider).ok).is_true()
	rules.elapsed_ms = int(rules.course.durationMs)
	rules.score_units = points * NeonRules.UNIT
	record.result = rules.result("completed" if complete else "ended")
	if complete: record.ghost = [[100, 0, 0, 1000], [rules.elapsed_ms, 4, rules.score_units, 1000000]]
	assert_bool(NeonRecords.local_request({"action": "save", "record": record}, rider).ok).is_true()
	return NeonRecords.local_request({"action": "get", "attemptId": record.attemptId}, rider).record


func _select(rules: NeonRules) -> Dictionary:
	return NeonBenchmark.select(NeonRecords.local_request({"action": "state"}, "1").trackStats, rules, "1")


func test_course_12_best_and_full_ghost_are_found_after_gap_bomb_update() -> void:
	var current := _rules()
	var old := _save(_rules(true), 154321)
	assert_dict(NeonRecords.local_request({"action": "best", "key": current.comparison_key("1")}, "1").record).is_empty()
	var selection := _select(current)
	assert_str(selection.best.attemptId).is_equal(old.attemptId)
	assert_bool(selection.differentVersion).is_true()
	var saved := NeonRecords.local_request({"action": "get", "attemptId": selection.best.attemptId}, "1")
	assert_array(saved.record.ghost).is_equal(old.ghost)
	assert_int(int(saved.record.course.courseVersion)).is_equal(12)
	assert_str(NeonBenchmark.menu_text(selection)).contains("Best 154,321").contains("different version")


func test_current_best_replaces_older_benchmark_only_when_it_beats_it() -> void:
	var old := _save(_rules(true), 154321)
	_save(_rules(), 150000)
	assert_str(_select(_rules()).best.attemptId).is_equal(old.attemptId)
	var new_best := _save(_rules(), 160000)
	var selection := _select(_rules())
	assert_str(selection.best.attemptId).is_equal(new_best.attemptId)
	assert_bool(selection.differentVersion).is_false()


func test_other_riders_difficulties_lengths_random_seeds_and_partial_rides_are_excluded() -> void:
	_save(_rules(true), 900000, "2")
	_save(_rules(true, "extreme"), 900000)
	_save(_rules(true, "hard", "ls_10_05"), 900000)
	_save(_rules(true, "hard", "ls_r_20_1234"), 900000)
	_save(_rules(), 900000, "1", false)
	assert_dict(_select(_rules()).best).is_empty()
	assert_str(_select(_rules()).last.status).is_equal("ended")


func test_changed_score_units_resistance_bands_or_kid_cadence_do_not_mix() -> void:
	var rules := _rules()
	var row := NeonRecords.benchmark(_save(_rules(true), 150000))
	for field in ["scoreScale", "referencePower", "envelopeVersion", "kidCadencePercent", "durationMs"]:
		var changed := row.duplicate(true)
		changed[field] = -1
		assert_bool(NeonBenchmark.matches(changed, rules, "1")).is_false()
	row.laneBands = [[0, 5]]
	assert_bool(NeonBenchmark.matches(row, rules, "1")).is_false()


func test_old_best_survives_history_limit_and_state_omits_course_and_trace() -> void:
	var old := _save(_rules(true), 154321)
	# Many later attempts on the same track must not erase the older winning trace.
	for i in 51: _save(_rules(), 100 + i)
	var state := NeonRecords.local_request({"action": "state"}, "1")
	assert_int(state.history.size()).is_equal(50)
	var selection := NeonBenchmark.select(state.trackStats, _rules(), "1")
	assert_str(selection.best.attemptId).is_equal(old.attemptId)
	for stat: Dictionary in state.trackStats.values():
		for key in ["last", "best"]:
			assert_bool(stat[key].has("ghost") or stat[key].has("course") or stat[key].has("events")).is_false()


func test_preview_shows_best_target_earlier_version_and_ghost_setting() -> void:
	_save(_rules(true), 154321)
	var card: LaneSmashBenchmarkCard = auto_free(LaneSmashBenchmarkCard.new())
	card.show_benchmark(_select(_rules()), true, true)
	assert_str(card.best_label.text).is_equal("PREVIOUS BEST  154,321")
	assert_str(card.target_label.text).is_equal("SCORE TO BEAT  154,322")
	assert_str(card.detail_label.text).contains("ghost").contains("Different track version")
	card.show_benchmark(_select(_rules()), false, true)
	assert_str(card.detail_label.text).contains("Ghost is off")
	card.show_benchmark({"best": {}}, true, false)
	assert_str(card.target_label.text).is_equal("Set your first high score")

# End of suite.
