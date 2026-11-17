extends GdUnitTestSuite


func test_resistance_moves_across_each_lane_without_crossing_its_edges() -> void:
	for tier: String in NeonRules.CURRENT_TIERS:
		for lane in 6:
			var band := NeonRules.band(lane, tier)
			var previous := float(lane) - 0.5
			for resistance in range(band.x, band.y + 1):
				var visual := LaneSmashSteering.position_for(resistance, tier)
				assert_float(visual).is_greater(previous)
				assert_float(absf(visual - lane)).is_less(0.38)  # every band position can hit markers
				assert_int(NeonRules.lane_for(resistance, tier)).is_equal(lane)
				previous = visual
			assert_float(LaneSmashSteering.position_for((band.x + band.y) * 0.5, tier)).is_equal(float(lane))
			# Enough room for the main hull at both extremes, with visible clearance.
			var clearance := NeonSpace.LANE_WIDTH * (0.5 - LaneSmashSteering.TRAVEL) - 0.62 * LaneSmashBike.SCALE
			assert_float(clearance).is_greater(0.1)
	assert_float(LaneSmashSteering.position_for(-200, "challenging")).is_equal(-LaneSmashSteering.TRAVEL)
	assert_float(LaneSmashSteering.position_for(200, "challenging")).is_equal(5.0 + LaneSmashSteering.TRAVEL)


func test_threshold_changes_snap_quickly_without_overshooting_at_different_frame_rates() -> void:
	for fps in [30, 60, 120]:
		var steering := LaneSmashSteering.new()
		steering.update(0, 36, "challenging", 1)
		var start := steering.lane
		var destination := LaneSmashSteering.position_for(37, "challenging")
		var previous := start
		for frame in int(fps * 0.2):
			steering.update(1.0 / fps, 37, "challenging", 1)
			assert_float(steering.lane).is_between(previous, destination)
			previous = steering.lane
		assert_float(absf(steering.lane - destination)).is_less(0.01)
		# Reversing before an animation ends stays continuous; a skipped sensor band is fine.
		steering.update(1.0 / fps, 64, "challenging", 1)
		var before := steering.lane
		steering.update(1.0 / fps, 30, "challenging", 1)
		assert_float(steering.lane).is_between(-LaneSmashSteering.TRAVEL, before)
		before = steering.lane
		steering.update(0.1, NAN, "challenging", 1)
		assert_float(steering.lane).is_equal(before)


func test_live_resistance_reaches_ninety_percent_within_100_ms_without_prediction() -> void:
	for fps in [30, 60, 120]:
		for pair: Vector2i in [Vector2i(31, 35), Vector2i(36, 37), Vector2i(64, 58)]:
			var steering := LaneSmashSteering.new()
			steering.update(0, pair.x, "challenging", 1)
			var start := steering.lane
			var destination := LaneSmashSteering.position_for(pair.y, "challenging")
			for frame in int(fps * 0.1): steering.update(1.0 / fps, pair.y, "challenging", 1)
			var progress := absf(steering.lane - start) / absf(destination - start)
			assert_float(progress).is_between(0.90, 1.0)
			assert_float(steering.lane).is_between(minf(start, destination), maxf(start, destination))


func test_highlights_crossfade_and_arrows_stop_inside_the_whole_target_band() -> void:
	var steering := LaneSmashSteering.new()
	steering.update(0, 33, "challenging", 0)
	assert_float(steering.weights[0]).is_equal(1.0)
	assert_int(steering.direction).is_zero()
	steering.update(0.08, 33, "challenging", 2)
	assert_float(steering.weights[0]).is_between(0.6, 0.9)
	assert_float(steering.weights[2]).is_between(0.1, 0.4)
	for i in 30: steering.update(1.0 / 60, 33, "challenging", 2)
	assert_int(steering.direction).is_equal(1)
	assert_float(steering.cue_alpha).is_equal(1.0)
	for resistance in [44, 47, 50]:
		for i in 30: steering.update(1.0 / 60, resistance, "challenging", 2)
		assert_float(steering.cue_alpha).is_zero()
		assert_int(steering.direction).is_zero()
	for i in 30: steering.update(1.0 / 60, 51, "challenging", 2)
	assert_int(steering.direction).is_equal(-1)
	assert_float(steering.cue_alpha).is_equal(1.0)
	steering.update(0.05, 51, "challenging", -1)
	assert_float(steering.cue_alpha).is_between(0.5, 0.99)
	for i in 30: steering.update(1.0 / 60, 51, "challenging", -1)
	assert_float(steering.cue_alpha).is_zero()
	for weight in steering.weights: assert_float(weight).is_zero()


func test_guidance_persists_through_gaps_and_does_not_change_the_rules() -> void:
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("ls_15_01"), "challenging", 150)
	assert_int(LaneSmashSteering.target_for(rules)).is_equal(0)
	var score := rules.score_units
	rules.pause_reason = "connection"
	assert_int(LaneSmashSteering.target_for(rules)).is_equal(int(rules.current_event().laneIndex))
	rules.pause_reason = ""
	rules._event_cursor = 2  # even a distant upcoming section stays highlighted
	assert_int(LaneSmashSteering.target_for(rules)).is_equal(int(rules.current_event().laneIndex))
	assert_int(rules.score_units).is_equal(score)


func test_only_inner_edges_warn_and_crossing_keeps_the_same_seam() -> void:
	for tier: String in NeonRules.CURRENT_TIERS:
		for lane in 6:
			var band := NeonRules.band(lane, tier)
			assert_vector(LaneSmashSteering.edge_warning((band.x + band.y) * 0.5, tier)).is_equal(Vector2(-1, 0))
			assert_vector(LaneSmashSteering.edge_warning(band.x, tier)).is_equal(Vector2(lane - 1, 1) if lane > 0 else Vector2(-1, 0))
			assert_vector(LaneSmashSteering.edge_warning(band.y, tier)).is_equal(Vector2(lane, 1) if lane < 5 else Vector2(-1, 0))
			if lane < 5:
				assert_vector(LaneSmashSteering.edge_warning(band.y + 1, tier)).is_equal(Vector2(lane, 1))
	assert_vector(LaneSmashSteering.edge_warning(NAN, "challenging")).is_equal(Vector2(-1, 0))
	assert_vector(LaneSmashSteering.edge_warning(99, "challenging")).is_equal(Vector2(-1, 0))
	var steering := LaneSmashSteering.new()
	steering.update(0, 68, "challenging", 5)
	steering.update(0.1, 65, "challenging", 5)
	assert_float(steering.edge_weights[4]).is_between(0.1, 0.5)
	steering.update(1, 65, "challenging", 5)
	assert_float(steering.edge_weights[4]).is_equal(1.0)
	steering.update(0.1, 68, "challenging", 5)
	assert_float(steering.edge_weights[4]).is_between(0.5, 0.9)
	steering.update(1, 68, "challenging", 5)
	for weight in steering.edge_weights: assert_float(weight).is_zero()
