extends GdUnitTestSuite
## Machine-gun fire over cadence sections (scoring version 7): holding the band is safe, riding
## outside it costs whole points per round, bounded per section, identically at any frame rate.

const TRACK := "ls_10_01"


func _rules(course_version := 8) -> NeonRules:
	var course: Dictionary = preload("res://tests/fixtures/catalog_v7.gd").load_track(TRACK)
	course.courseVersion = course_version
	var rules := NeonRules.new()
	assert_array(rules.configure(course, "challenging", 150)).is_empty()
	return rules


func _first_hold(rules: NeonRules) -> Dictionary:
	for event: Dictionary in rules.course.events:
		if event.type == "hold": return event
	return {}


## Rides from the rules' current time to `until_ms` at `cadence.call(rules, sample_ms)`, in the
## target lane (or `fixed_lane`). Sensor samples always arrive every 50 ms; `advance_step` is how
## often the rules are advanced (the display's frame time), which must not change any outcome.
func _ride(rules: NeonRules, until_ms: int, cadence: Callable, advance_step := 50, fixed_lane := -1) -> void:
	var t := rules.elapsed_ms
	var next_advance := rules.elapsed_ms + advance_step
	while t < until_ms:
		var lane := fixed_lane if fixed_lane >= 0 else int(rules.current_event().get("laneIndex", 0))
		var rpm: float = cadence.call(rules, t)
		rules.push_sample({"t": t, "seq": t + 1, "cadence": rpm, "power": 150, "resistance": NeonRules.band_center(lane, rules.tier)})
		t += 50
		while next_advance <= mini(t, until_ms):
			rules.advance(next_advance)
			next_advance += advance_step
	rules.advance(until_ms)


func _in_hold(rules: NeonRules, hold: Dictionary) -> bool:
	return rules.road_time_ms() >= int(hold.startMs) and rules.road_time_ms() < int(hold.endMs)


func test_new_tracks_use_course_twelve_and_preserve_legacy_scoring() -> void:
	var course := NeonCourse.load_course(TRACK)
	assert_int(int(course.courseVersion)).is_equal(13)
	assert_int(int(course.generatorVersion)).is_equal(10)
	var rules := NeonRules.new()
	assert_array(rules.configure(course, "challenging", 150)).is_empty()
	assert_int(rules.scoring_version).is_equal(12)
	assert_int(_rules(11).scoring_version).is_equal(10)
	assert_int(_rules(10).scoring_version).is_equal(9)
	# A course 8 snapshot keeps scoring 7: machine-gun fire, no sweet-spot bonus.
	assert_int(_rules(8).scoring_version).is_equal(7)
	assert_int(rules.score_scale).is_equal(18)
	assert_dict(rules.result("pending").gunfire).is_equal({"hits": 0, "penaltyUnits": 0})


func test_holding_the_band_is_never_hit_and_reports_live_fire() -> void:
	var rules := _rules()
	var hold := _first_hold(rules)
	var middle := (float(hold.cadenceMin) + float(hold.cadenceMax)) * 0.5
	var saw_fire := false
	var saw_grace := false
	while rules.road_time_ms() < int(hold.endMs) + 500:
		_ride(rules, rules.elapsed_ms + 100, func(_r, _t): return middle)
		var fire := rules.gunfire()
		if _in_hold(rules, hold) and not fire.is_empty():
			saw_fire = true
			assert_str(fire.eventId).is_equal(hold.eventId)
			assert_bool(fire.exposed).is_false()
			if int(fire.graceLeftMs) > 0: saw_grace = true
	assert_bool(saw_fire).is_true()
	assert_bool(saw_grace).is_true()
	assert_int(rules.gun_hits).is_zero()
	assert_int(rules.gun_penalty_units).is_zero()
	assert_dict(rules.gunfire()).is_empty()  # the section is behind the rider
	assert_int(rules.score_units).is_greater(0)


func test_both_band_edges_are_safe() -> void:
	for edge: String in ["cadenceMin", "cadenceMax"]:
		var rules := _rules()
		# Sit exactly on the edge of whichever cadence section is current, for two minutes.
		_ride(rules, 120000, func(r: NeonRules, _t): return float(r.current_event().get(edge, 80)))
		assert_int(rules.gun_hits).override_failure_message(edge).is_zero()
		assert_int(rules.score_units).is_greater(0)


func test_riding_too_slow_or_too_fast_takes_rounds_after_the_warning() -> void:
	for offset: float in [-25.0, 25.0]:
		var rules := _rules()
		var hold := _first_hold(rules)
		var middle := (float(hold.cadenceMin) + float(hold.cadenceMax)) * 0.5
		var outside: float = (float(hold.cadenceMin) if offset < 0 else float(hold.cadenceMax)) + offset
		# Arrive in the band, then drift outside once the section is active.
		while not _in_hold(rules, hold): _ride(rules, rules.elapsed_ms + 50, func(_r, _t): return middle)
		rules.score_units = 100000 * NeonRules.UNIT
		var before := rules.score_units
		var entered := rules.elapsed_ms
		# Grace: nothing lands during the first two seconds, however far outside the rider is.
		_ride(rules, entered + NeonRules.GUN_GRACE_MS - 100, func(_r, _t): return outside)
		assert_int(rules.gun_hits).is_zero()
		assert_bool(rules.gunfire().exposed).is_false()
		# Then the first round needs 600 ms of exposure.
		_ride(rules, entered + NeonRules.GUN_GRACE_MS + NeonRules.GUN_FIRST_HIT_MS - 100, func(_r, _t): return outside)
		assert_int(rules.gun_hits).is_zero()
		assert_bool(rules.gunfire().exposed).is_true()
		_ride(rules, entered + NeonRules.GUN_GRACE_MS + NeonRules.GUN_FIRST_HIT_MS + 50, func(_r, _t): return outside)
		assert_int(rules.gun_hits).is_equal(1)
		# One more every half second.
		_ride(rules, entered + NeonRules.GUN_GRACE_MS + NeonRules.GUN_FIRST_HIT_MS + 1050, func(_r, _t): return outside)
		assert_int(rules.gun_hits).is_equal(3)
		assert_int(rules.gun_penalty_units).is_equal(3 * NeonRules.GUN_HIT_POINTS * NeonRules.UNIT)
		assert_int(rules.penalty_units).is_equal(rules.gun_penalty_units)
		# The section's own points only count inside the band, so the loss is exactly the rounds.
		assert_int(rules.score_units).is_equal(before - 3 * NeonRules.GUN_HIT_POINTS * NeonRules.UNIT)


func test_a_stopped_rider_is_capped_per_section_and_never_goes_negative() -> void:
	var rules := _rules()
	var hold := _first_hold(rules)
	var middle := (float(hold.cadenceMin) + float(hold.cadenceMax)) * 0.5
	# Arrive with only a little on the board (the lead-in ridden mostly in the wrong lane), so
	# the rounds that land cost more than the ride has earned.
	var wrong := (int(hold.laneIndex) + 3) % 6
	while rules.road_time_ms() < int(hold.startMs) - 1500: _ride(rules, rules.elapsed_ms + 50, func(_r, _t): return middle, 50, wrong)
	while not _in_hold(rules, hold): _ride(rules, rules.elapsed_ms + 50, func(_r, _t): return middle)
	var earned := rules.score_units
	assert_int(earned).is_greater(0)
	# Stop completely: the road does not advance, the section stays active, the fire keeps coming.
	_ride(rules, rules.elapsed_ms + 40000, func(_r, _t): return 0.0)
	assert_int(rules.gun_hits).is_equal(NeonRules.GUN_MAX_HITS)
	assert_bool(rules.gunfire().spent).is_true()
	# Whole points only: a ride with fewer points than the rounds cost keeps just its fraction.
	assert_int(earned).is_less(NeonRules.GUN_MAX_HITS * NeonRules.GUN_HIT_POINTS * NeonRules.UNIT)
	assert_int(rules.score_units).is_between(0, NeonRules.UNIT - 1)
	assert_int(rules.penalty_units).is_equal(earned - rules.score_units)
	assert_int(rules.gun_penalty_units).is_equal(rules.penalty_units)
	assert_str(rules.pause_reason).is_empty()
	var result := rules.result("ended")
	assert_int(int(result.gunfire.hits)).is_equal(NeonRules.GUN_MAX_HITS)
	assert_int(int(result.earnedScoreUnits) - int(result.penaltyUnits)).is_equal(int(result.scoreUnits))


func test_a_brief_slip_outside_the_band_is_forgiven() -> void:
	var rules := _rules()
	var hold := _first_hold(rules)
	var middle := (float(hold.cadenceMin) + float(hold.cadenceMax)) * 0.5
	while not _in_hold(rules, hold): _ride(rules, rules.elapsed_ms + 50, func(_r, _t): return middle)
	_ride(rules, rules.elapsed_ms + NeonRules.GUN_GRACE_MS + 200, func(_r, _t): return middle)
	for slip in 4:
		_ride(rules, rules.elapsed_ms + 400, func(_r, _t): return float(hold.cadenceMax) + 15.0, 10)
		assert_bool(rules.gunfire().exposed).is_true()
		_ride(rules, rules.elapsed_ms + 300, func(_r, _t): return middle, 10)
		assert_int(int(rules.gunfire().exposedMs)).is_zero()
	assert_int(rules.gun_hits).is_zero()


func test_older_snapshots_keep_scoring_six_without_gunfire() -> void:
	var rules := _rules(7)
	assert_int(rules.scoring_version).is_equal(6)
	var hold := _first_hold(rules)
	assert_bool(rules.event_states[rules.course.events.find(hold)].has("gunMs")).is_false()
	_ride(rules, 60000, func(_r, _t): return 30.0)
	assert_int(rules.gun_hits).is_zero()
	assert_int(rules.penalty_units).is_zero()
	assert_dict(rules.gunfire()).is_empty()


func test_outcome_is_identical_at_any_update_rate() -> void:
	var outcomes: Array = []
	for step: int in [10, 30, 50, 100]:
		var rules := _rules()
		var hold := _first_hold(rules)
		# A deterministic wobble across the top of the band, a function of the sample time only.
		_ride(rules, 45000, func(_r, t: int): return float(hold.cadenceMax) - 6.0 + 14.0 * absf(sin(floorf(t / 100.0) * 0.21)), step, int(hold.laneIndex))
		outcomes.append([rules.gun_hits, rules.score_units, rules.penalty_units, rules.distance_units])
	assert_int(int(outcomes[0][0])).is_greater(0)
	for outcome: Array in outcomes: assert_array(outcome).is_equal(outcomes[0])


func test_saved_records_accept_scoring_seven_and_reject_unknown_versions() -> void:
	var rules := _rules()
	var record := {"version": 1, "attemptId": NeonRecords.new_id(), "riderId": "1", "comparisonKey": rules.comparison_key("1"),
		"course": rules.course.duplicate(true), "result": rules.result("pending"), "ghost": []}
	assert_int(int(record.result.scoringVersion)).is_equal(7)
	assert_bool(NeonRecords.valid_record(record)).is_true()
	record.result.scoringVersion = NeonRules.SCORING_VERSION
	assert_bool(NeonRecords.valid_record(record)).is_true()
	record.result.scoringVersion = NeonRules.SCORING_VERSION + 1
	assert_bool(NeonRecords.valid_record(record)).is_false()
