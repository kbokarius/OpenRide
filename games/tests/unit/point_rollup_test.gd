extends GdUnitTestSuite

func test_gain_flows_and_eases_to_an_exact_finish() -> void:
	var counter := PointRollup.new()
	counter.aim(150000)
	var previous := 0.0
	for frame in 180:
		counter.advance(1.0 / 60)
		assert_float(counter.value).is_between(previous, 150000.0)
		previous = counter.value
	assert_int(counter.advance(0)).is_equal(150000)
	assert_float(counter.value).is_equal(150000.0)

func test_retarget_preserves_position_and_velocity_without_restarting() -> void:
	var counter := PointRollup.new()
	counter.aim(1800)
	counter.advance(0.1)
	var value := counter.value
	var velocity := counter._velocity
	counter.aim(3600)
	assert_float(counter.value).is_equal(value)
	assert_float(counter._velocity).is_equal(velocity)
	counter.advance(0.016)
	assert_float(counter.value).is_greater(value)
	counter.aim(0)
	assert_float(counter.value).is_greater(0)
	assert_float(counter._velocity).is_zero()
	for i in 120: counter.advance(1.0 / 60)
	assert_float(counter.value).is_zero()

func test_continuous_earnings_keep_moving_through_second_boundaries() -> void:
	var counter := PointRollup.new()
	var previous := 0.0
	for frame in 240:
		counter.aim((frame + 1) * 10)
		counter.advance(1.0 / 60)
		assert_float(counter.value).is_greater(previous)
		assert_float(counter.value - previous).is_less(10.01)
		previous = counter.value
	counter.reset()
	assert_int(counter.advance(1)).is_zero()

func test_analytic_motion_is_identical_at_different_render_rates() -> void:
	var values := []
	for fps in [30, 60, 120]:
		var counter := PointRollup.new()
		counter.reset(99999)
		counter.aim(150000)
		for frame in fps / 2: counter.advance(1.0 / fps)
		values.append(counter.value)
	assert_float(values[0]).is_equal_approx(values[1], 0.000001)
	assert_float(values[1]).is_equal_approx(values[2], 0.000001)

func test_hud_accepts_new_points_between_one_second_metric_refreshes() -> void:
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	hud._roll_score = true
	hud.text_interval = 1.0
	var saved := Effort._meter.score
	Effort._meter.score = 100
	hud._process(0.05)
	Effort._meter.score = 200
	hud._process(0.05)
	assert_int(hud._score_rollup.target).is_equal(200)
	assert_float(hud._score_rollup.value).is_between(0.0, 200.0)
	Effort._meter.score = saved

# End of counter regressions.
