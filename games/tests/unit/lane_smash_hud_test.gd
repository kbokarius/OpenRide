extends GdUnitTestSuite

func test_rolling_score_keeps_caption_and_panel_fixed_at_digit_boundaries() -> void:
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	hud.set_process(false)
	hud.effort.hide()
	hud.metrics.refresh(118, 1888, 100)
	var status: NeonStatus = NeonStatus.new()
	hud.add_widget(status)
	var skin := GameTheme.new(Color("79b8d5"), Color("0b1019"), 0, false, true).hud_skin()
	skin.score_rollup = true
	skin.manual_pause = false
	hud.set_skin(skin)
	var positions: Array[Vector2] = []
	var sizes: Array[Vector2] = []
	for value in ["0", "9999", "10000", "99999", "150000", "1500000"]:
		hud.score.set_value(value)
		for frame in 4: await get_tree().process_frame
		positions.append(hud.score._caption.global_position)
		sizes.append(hud.clock_panel.size)
		var font := hud.score._value.get_theme_font("font")
		var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, hud.score._value.get_theme_font_size("font_size")).x
		assert_bool(width <= hud.score._value.size.x).override_failure_message("Score was clipped: " + value).is_true()
		assert_bool(hud.clock_panel.get_global_rect().end.x <= 1880).is_true()
	for i in range(1, positions.size()):
		assert_vector(positions[i]).is_equal(positions[0])
		assert_vector(sizes[i]).is_equal(sizes[0])
	hud.clear_widgets()
	assert_int(hud.score.tight_from).is_equal(5)

func test_power_value_does_not_shift_its_instruction_or_caption() -> void:
	var status: NeonStatus = auto_free(NeonStatus.new())
	add_child(status)
	status.size = Vector2(740, 166)
	status.target.hide()
	status.power_row.show()
	var positions: Array[Vector2] = []
	for value in [0, 9, 99, 999, 9999, 99999]:
		status._update_power_text(value)
		for frame in 3: await get_tree().process_frame
		positions.append(status.power_row.get_child(0).global_position)
		assert_bool(status.power_row.size.x <= 740).is_true()
	for i in range(1, positions.size()): assert_vector(positions[i]).is_equal(positions[0])


func test_interface_colour_moves_only_with_the_music_and_keeps_its_alpha() -> void:
	var edge := Color(LaneSmashMenuTheme.ACCENT, 0.34)
	# Silence leaves every accent exactly as designed.
	assert_bool(LaneSmashLook.pulsed(edge, Vector4.ZERO).is_equal_approx(edge)).is_true()
	var loud := LaneSmashLook.pulsed(edge, Vector4(1.0, 1.0, 1.0, 0.5))
	assert_float(loud.a).is_equal_approx(0.34, 0.0001)
	assert_bool(loud.is_equal_approx(edge)).is_false()
	# It leans toward the companion hue, never to an unrelated colour.
	var companion := LaneSmashLook.companion(edge)
	assert_float(absf(loud.h - edge.h)).is_less_equal(absf(companion.h - edge.h) + 0.01)
	# The meter rests flat and eases toward the live bands.
	var bars := LaneSmashSpectrum.blank()
	assert_int(bars.size()).is_equal(LaneSmashSpectrum.BARS)
	bars = LaneSmashSpectrum.eased(bars, 1.0 / 30)
	for level in bars: assert_float(level).is_between(0.0, 1.0)
