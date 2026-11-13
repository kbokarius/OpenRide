extends GdUnitTestSuite


func test_unchanged_deliveries_and_reads_have_distinct_freshness() -> void:
	var input := NeonLocalInput.new()
	input.record(0, 80, 150, 35)
	assert_int(input.batch(-1, 1000).sample_age_ms).is_equal(1000)
	assert_int(input.batch(-1, 1501).sample_age_ms).is_equal(1501)
	input.record(1501, 80, 150, 35)
	assert_bool(input.batch(1, 1501).fresh).is_true()
	assert_int(input.batch(1, 1501).samples.size()).is_equal(1)


func test_pause_discards_unprocessed_time_and_resume_reanchors_samples() -> void:
	var input := NeonLocalInput.new()
	input.record(1000, 80, 150, 35)
	input.control("begin", 0, 600000, 1000)
	input.control("ack", 20, 0, 1027)
	input.control("pause", 20, 0, 1027)
	assert_int(input.batch(-1, 100000).elapsed_ms).is_equal(20)
	input.record(100000, 80, 150, 35)
	input.control("resume", 0, 0, 100000)
	var batch := input.batch(-1, 100030)
	assert_int(batch.elapsed_ms).is_equal(50)
	assert_int(batch.origin_ms).is_equal(99980)
	assert_int(batch.epoch).is_equal(2)


func test_render_stall_and_ring_overflow_are_explicit() -> void:
	var input := NeonLocalInput.new()
	input.record(0, 80, 150, 35)
	input.control("begin", 0, 600000, 0)
	input.control("ack", 200, 0, 200)
	input.batch(0, 200)
	assert_str(input.batch(0, 451).pause_reason).is_equal("stall")
	assert_int(input.batch(0, 5000).elapsed_ms).is_equal(200)
	for t in range(5000, 11000, 50):
		input.record(t, 80, 150, 35)
	input.control("resume", 0, 0, 11000)
	assert_str(input.batch(0, 11000).pause_reason).is_equal("overflow")


func test_silence_pauses_even_when_values_are_still_identical() -> void:
	var input := NeonLocalInput.new()
	input.record(0, 80, 150, 35)
	input.control("begin", 0, 600000, 0)
	for t in range(100, 1501, 100):
		input.control("ack", t - 100, 0, t)
		assert_bool(input.batch(1, t).running).is_true()
	assert_str(input.batch(1, 1501).pause_reason).is_equal("sensor")
