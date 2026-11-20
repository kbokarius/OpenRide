extends GdUnitTestSuite

var _options_path := ""


func before_test() -> void:
	_options_path = GameOptions.path
	GameOptions.path = "user://ghost_test_" + NeonRecords.new_id() + ".cfg"


func after_test() -> void:
	GameOptions.path = _options_path
	GameOptions.reload()


func _trace(end_ms: int, stop_ms: int = -1) -> Array:
	var ticks: Array = []
	for t in range(100, end_ms + 1, 100):
		var moving_ms := mini(t, stop_ms) if stop_ms >= 0 else t
		ticks.append([t, 2, moving_ms * 100, moving_ms * 8])
	return ticks


func _game(ticks: Array) -> Game:
	var game: Game = auto_free(load("res://games/neon_vector/NeonVector.gd").new())
	assert_array(game.rules.configure(NeonCourse.load_course("ls_15_05"), "hard", 150)).is_empty()
	game.track = auto_free(NeonTrack.new())
	game._ghost = ticks
	return game


func test_early_trace_end_hides_ghost_and_resets_animation_cadence() -> void:
	var game := _game(_trace(870000))
	game.rules.elapsed_ms = 860000
	game._update_ghost()
	assert_bool(game.track.ghost_visible).is_true()
	assert_float(game.track.ghost_cadence).is_greater(0.0)
	game.rules.elapsed_ms = 880000
	game._update_ghost()
	assert_bool(game.track.ghost_visible).is_false()
	assert_float(game.track.ghost_cadence).is_zero()


func test_complete_recording_preserves_real_stationary_tail() -> void:
	var game := _game(_trace(900000, 872200))
	for t in [873000, 885000, 899900, 900000]:
		game.rules.elapsed_ms = t
		game._update_ghost()
		assert_bool(game.track.ghost_visible).is_true()
		assert_float(game.track.ghost_distance).is_equal_approx(6977.6, 0.001)
		assert_float(game.track.ghost_cadence).is_zero()


func test_truncated_trace_fades_before_its_last_sample_and_clears_comparison() -> void:
	var game := _game(_trace(870000))
	for item: Array in [[869500, 1.0], [869750, 0.5], [870000, 0.0]]:
		game.rules.elapsed_ms = int(item[0])
		game._update_ghost()
		assert_float(game.track.ghost_opacity).is_equal_approx(float(item[1]), 0.001)
	assert_bool(game.track.ghost_visible).is_false()
	assert_float(game.track.ghost_cadence).is_zero()
	assert_float(game.track.ghost_gap).is_zero()
	assert_int(game.track.ghost_delta).is_zero()
	assert_str(game.track.ghost_notice).is_equal("GHOST RECORDING ENDED")


func test_complete_moving_trace_interpolates_and_derives_final_cadence() -> void:
	var game := _game(_trace(900000))
	game.rules.elapsed_ms = 899950
	game._update_ghost()
	assert_float(game.track.ghost_distance).is_equal_approx(7199.6, 0.001)
	game.track.ghost_cadence = 0.0
	game.rules.elapsed_ms = 900000
	game._update_ghost()
	assert_bool(game.track.ghost_visible).is_true()
	assert_float(game.track.ghost_opacity).is_equal(1.0)
	assert_float(game.track.ghost_distance).is_equal_approx(7200.0, 0.001)
	assert_float(game.track.ghost_cadence).is_equal_approx(67.2, 0.001)


func test_missing_middle_never_invents_travel_and_fades_back_into_recorded_data() -> void:
	var ticks := _trace(900000)
	ticks = ticks.slice(0, 200) + ticks.slice(300)
	var game := _game(ticks)
	assert_bool(game._ghost_playback.complete).is_false()
	game.rules.elapsed_ms = 19750
	game._update_ghost()
	assert_float(game.track.ghost_opacity).is_equal_approx(0.5, 0.001)
	game.rules.elapsed_ms = 25000
	game._update_ghost()
	assert_bool(game.track.ghost_visible).is_false()
	assert_float(game.track.ghost_cadence).is_zero()
	assert_str(game.track.ghost_notice).is_equal("GHOST RECORDING UNAVAILABLE")
	game.rules.elapsed_ms = 30350
	game._update_ghost()
	assert_bool(game.track.ghost_visible).is_true()
	assert_float(game.track.ghost_opacity).is_equal_approx(0.5, 0.001)
	assert_float(game.track.ghost_distance).is_equal_approx(242.8, 0.001)
	assert_str(game.track.ghost_notice).is_empty()


func test_missing_start_empty_trace_and_ghost_off_do_not_show_stale_state() -> void:
	var game := _game(_trace(900000).slice(100))
	game.rules.elapsed_ms = 1000
	game._update_ghost()
	assert_bool(game.track.ghost_visible).is_false()
	assert_str(game.track.ghost_notice).is_equal("GHOST RECORDING UNAVAILABLE")
	game.rules.elapsed_ms = 20000
	game._update_ghost()
	assert_bool(game.track.ghost_visible).is_true()
	game._ghost = []
	game._update_ghost()
	assert_bool(game.track.ghost_visible).is_false()
	assert_float(game.track.ghost_cadence).is_zero()
	assert_str(game.track.ghost_notice).is_empty()
	assert_bool(GameOptions.set_value(game.declared(), "ghost", "off")).is_true()
	game._ghost = _trace(10000)
	game._update_ghost()
	assert_bool(game.track.ghost_visible).is_false()
	assert_str(game.track.ghost_notice).is_empty()
	DirAccess.remove_absolute(GameOptions.path)


func test_legacy_rows_and_rewinding_keep_their_existing_behavior() -> void:
	var ticks := _trace(900000)
	for tick: Array in ticks: tick.pop_back()
	var game := _game(ticks)
	game.rules.elapsed_ms = 899900
	game._update_ghost()
	assert_bool(game.track.ghost_visible).is_true()
	assert_float(game.track.ghost_distance).is_equal(3.5)
	game.rules.elapsed_ms = 1000
	game._update_ghost()
	assert_int(game.track.ghost_delta).is_equal(-1)
	assert_bool(game._ghost_playback.complete).is_true()


func test_incomplete_recording_keeps_its_high_score_and_shows_preview_notice() -> void:
	var game := _game(_trace(870000))
	game.rules.elapsed_ms = 900000
	game.rules.score_units = 150000 * NeonRules.UNIT
	game._attempt_id = NeonRecords.new_id()
	game.rules.ghost_trace = game._ghost
	var record: Dictionary = game._record("completed")
	assert_bool(NeonRecords.valid_record(record)).is_true()
	var card: LaneSmashBenchmarkCard = auto_free(LaneSmashBenchmarkCard.new())
	card.show_benchmark({"best": NeonRecords.benchmark(record)}, true, true, game._ghost_playback.complete)
	assert_str(card.target_label.text).is_equal("SCORE TO BEAT  150,001")
	assert_str(card.detail_label.text).is_equal("Ghost recording is incomplete")


func test_all_supported_durations_cover_the_finish_but_never_run_beyond_it() -> void:
	var playback := LaneSmashGhostPlayback.new()
	for duration in [600000, 900000, 1200000, 1800000]:
		playback.configure(_trace(duration), duration)
		assert_bool(playback.complete).is_true()
		playback.update(duration, 0.0)
		assert_bool(playback.available).is_true()
		assert_float(playback.cadence).is_equal_approx(67.2, 0.001)
		playback.update(duration + 100, 0.0)
		assert_bool(playback.available).is_false()
		assert_float(playback.cadence).is_zero()


# End of suite.
