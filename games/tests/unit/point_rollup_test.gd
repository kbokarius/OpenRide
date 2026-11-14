extends GdUnitTestSuite

func test_gain_is_fast_then_slows_and_finishes_exactly() -> void:
	var counter := PointRollup.new()
	counter.aim(150000)
	var first := counter.advance(0.18)
	var second := counter.advance(0.18)
	var third := counter.advance(0.18)
	assert_int(first).is_greater(75000)
	assert_int(second - first).is_less(first)
	assert_int(third - second).is_less(second - first)
	assert_int(counter.advance(0.18)).is_equal(150000)
	assert_int(counter.advance(10)).is_equal(150000)

func test_retarget_preserves_current_value_and_replaces_old_destination() -> void:
	var counter := PointRollup.new()
	counter.aim(1800)
	var shown := counter.advance(0.1)
	counter.aim(3600)
	assert_int(counter.advance(0)).is_equal(shown)
	assert_int(counter.advance(1)).is_equal(3600)
	counter.aim(1800)
	assert_int(counter.advance(0)).is_equal(3600)
	var midway := counter.advance(0.15)
	assert_int(midway).is_less(3600)
	assert_int(midway).is_greater(1800)
	assert_int(counter.advance(0.15)).is_equal(1800)

func test_repeated_target_does_not_restart_and_reset_cancels_animation() -> void:
	var counter := PointRollup.new()
	counter.aim(1000)
	for i in 60:
		counter.aim(1000)
		counter.advance(1.0 / 60)
	assert_int(counter.advance(0)).is_equal(1000)
	counter.aim(2000)
	counter.advance(0.1)
	counter.reset()
	assert_int(counter.advance(1)).is_zero()

func test_render_rates_remain_monotonic_and_land_on_same_score() -> void:
	for fps in [30, 60, 120]:
		var counter := PointRollup.new()
		counter.reset(99999)
		counter.aim(150000)
		var previous := 99999
		for frame in fps:
			var shown := counter.advance(1.0 / fps)
			assert_bool(shown >= previous and shown <= 150000).is_true()
			previous = shown
		assert_int(previous).is_equal(150000)
