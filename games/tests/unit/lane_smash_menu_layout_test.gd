extends GdUnitTestSuite
## The selector and its settings screen keep the bike-first rules on a 1920x1080 stage: every
## touch target at least 120 px on its shorter side and 24 px from its neighbours, everything
## on screen, no text under 34 px, nothing overlapping, and the ride controls inside their panel.

const STAGE := Rect2(0, 0, 1920, 1080)
var _options_path := ""
var _records_path := ""


func before() -> void:
	_options_path = GameOptions.path
	_records_path = NeonRecords.path
	GameOptions.path = "user://menu_layout_test_options.cfg"
	GameOptions.reload()
	NeonRecords.path = "user://menu_layout_test_" + NeonRecords.new_id()


func after() -> void:
	DirAccess.remove_absolute(GameOptions.path)
	GameOptions.path = _options_path
	GameOptions.reload()
	NeonRecords.path = _records_path


func _screen() -> NeonSetup:
	var screen: NeonSetup = auto_free(NeonSetup.new())
	screen.setup({"rider": {"id": 1, "name": "Rider"}}, {}, BakeQueue.new())
	add_child(screen)
	for i in 6: await get_tree().process_frame
	return screen


func _gap(a: Rect2, b: Rect2) -> float:
	return maxf(maxf(b.position.x - a.end.x, a.position.x - b.end.x), maxf(b.position.y - a.end.y, a.position.y - b.end.y))


func _check_targets(what: String, targets: Array) -> void:
	assert_bool(targets.is_empty()).is_false()
	var rects: Array[Rect2] = []
	for target: Control in targets:
		var rect := target.get_global_rect()
		assert_float(minf(rect.size.x, rect.size.y)).override_failure_message("%s: %s is %s, under 120 px" % [what, target.name, rect.size]).is_greater_equal(119.5)
		assert_bool(STAGE.grow(0.5).encloses(rect)).override_failure_message("%s: %s %s is off the stage" % [what, target.name, rect]).is_true()
		rects.append(rect)
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			assert_float(_gap(rects[i], rects[j])).override_failure_message("%s: %s and %s are %.0f px apart" % [what, targets[i].name, targets[j].name, _gap(rects[i], rects[j])]).is_greater_equal(23.5)


func _check_text(what: String, root: Node) -> void:
	for node in root.find_children("*", "Label", true, false) + root.find_children("*", "Button", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or str(control.get("text")).strip_edges().is_empty(): continue
		assert_int(control.get_theme_font_size("font_size")).override_failure_message("%s: '%s' is under 34 px" % [what, control.get("text")]).is_greater_equal(34)


func test_selector_targets_text_and_columns() -> void:
	var screen := await _screen()
	assert_int(screen.tier_buttons.size()).is_equal(6)
	assert_str(screen.tier_buttons.kid.text).is_equal("Kid")
	screen._pick_tier("kid")
	assert_str(screen.range_label.text).is_equal("0–20 ACROSS SIX LANES")
	assert_int(screen.course.events[1].cadenceMin).is_equal(38)
	var kid_rules := NeonRules.new()
	kid_rules.configure(screen.course, "kid", 150)
	assert_str(screen._track_keys["%s:kid:150" % screen.course.courseId]).is_equal(kid_rules.comparison_key(screen.rider_id))
	for duration in ["10", "15", "20", "30"]:
		screen.length_picker.pick(duration)
		for tier in NeonRules.CURRENT_TIERS:
			screen._pick_tier(tier)
			for i in 3: await get_tree().process_frame
			_check_targets("selector %s/%s" % [duration, tier], screen.targets())
	_check_text("selector", screen)
	# The ride controls stay inside the setup panel's padded column.
	var panel: Control = screen.get_node("Setup")
	var column := Rect2(panel.global_position + Vector2(NeonSetup.PANEL_PAD, 0), Vector2(NeonSetup.PANEL_W - 2 * NeonSetup.PANEL_PAD, panel.size.y))
	for control: Control in screen.length_picker.buttons + screen.tier_buttons.values() + [screen.start_button]:
		var rect := control.get_global_rect()
		assert_float(rect.position.x).override_failure_message(str(control.name) + " starts left of its column").is_greater_equal(column.position.x - 0.5)
		assert_float(rect.end.x).override_failure_message(str(control.name) + " runs past its column").is_less_equal(column.end.x + 0.5)
		assert_float(rect.end.y).is_less_equal(panel.get_global_rect().end.y - 23.5)
	# Header: nothing overlaps, and both ends sit on the screen margin.
	var bar: Control = screen.get_node("TopBar")
	var previous_end := -INF
	for child: Control in bar.get_children():
		assert_float(child.global_position.x).override_failure_message(str(child.name) + " overlaps its neighbour").is_greater_equal(previous_end)
		previous_end = child.get_global_rect().end.x
	assert_float(bar.get_node("Back").global_position.x).is_equal(float(LaneSmashMenuTheme.MARGIN))
	assert_float(bar.get_node("Extras").get_global_rect().end.x).is_equal_approx(1920.0 - LaneSmashMenuTheme.MARGIN, 0.5)
	assert_bool("Exit" in screen.targets().map(func(t): return str(t.name))).is_false()  # never beside Start


func test_track_cards_keep_their_text_inside() -> void:
	var screen := await _screen()
	assert_int(screen.track_buttons.size()).is_equal(25)
	for card in screen.track_buttons:
		assert_vector(card.size).is_equal(LaneSmashTrackCard.SIZE)
		for child in card.get_children():
			if not child is Label or not child.visible: continue
			assert_float(child.position.x).is_greater_equal(LaneSmashTrackCard.PAD)
			assert_float(child.position.x + child.size.x).override_failure_message("Card text overflows: " + child.text).is_less_equal(card.size.x - LaneSmashTrackCard.PAD + 0.5)
			assert_float(child.position.y + child.size.y).override_failure_message("Card text is clipped: " + child.text).is_less_equal(card.size.y)
	screen._pick_track(3)
	await get_tree().process_frame
	assert_bool(screen.track_buttons[3].selected_label.visible).is_true()
	assert_bool(screen.track_buttons[0].selected_label.visible).is_false()


func test_settings_screen_targets_and_text() -> void:
	var screen := await _screen()
	screen._progress = {"ok": true, "completions": 0, "history": []}
	screen._open_extras()
	for i in 6: await get_tree().process_frame
	_check_targets("settings", screen.targets())
	_check_text("settings", screen._panel)
	for key in ["music", "sfx", "ghost", "motion", "graphics"]:
		var row := screen._panel.find_child("Option_" + key, true, false) as OptionRow
		assert_object(row).override_failure_message("missing option row " + key).is_not_null()
		assert_float(row.get_global_rect().end.x).is_less_equal(1920.0 - LaneSmashMenuTheme.MARGIN + 0.5)
	assert_object(screen._panel.find_child("MusicPanel", true, false)).is_not_null()
	screen._close_panel()
	await get_tree().process_frame
	assert_bool(is_instance_valid(screen._panel)).is_false()


## A finger put down at `from` (stage coordinates), dragged to `to` in steps, and lifted. A
## touch reaches the game as mouse events as well, which is what the interface listens to.
func _touch_drag(from: Vector2, to: Vector2, steps := 8) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = from
	down.global_position = from
	down.pressed = true
	get_viewport().push_input(down, true)
	for step in steps:
		var move := InputEventMouseMotion.new()
		move.position = from.lerp(to, float(step + 1) / steps)
		move.global_position = move.position
		move.relative = (to - from) / steps
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(move, true)
		await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = to
	up.global_position = to
	up.pressed = false
	get_viewport().push_input(up, true)
	await get_tree().process_frame


func test_the_track_library_scrolls_when_the_finger_starts_on_a_card() -> void:
	var screen := await _screen()
	screen._pick_track(0)
	await get_tree().process_frame
	assert_int(screen.track_scroll.scroll_vertical).is_equal(0)
	# Put the finger on the third card and drag up by two cards.
	var card: Control = screen.track_buttons[2]
	var from := card.get_global_rect().get_center()
	await _touch_drag(from, from - Vector2(0, 420))
	assert_int(screen.track_scroll.scroll_vertical).override_failure_message("the library did not scroll").is_greater(200)
	# The drag did not pick the card it started on, or the one the finger ended over.
	assert_int(screen.selected_index).is_equal(0)
	# A small wobble under the threshold is still a tap, not a scroll.
	var before := screen.track_scroll.scroll_vertical
	await get_tree().create_timer(0.35).timeout
	var settled := screen.track_scroll.scroll_vertical
	assert_int(settled).is_greater_equal(before)  # it may coast on a little, never back
	# A tap (down and up in place) still picks a card.
	var visible_card: Control = null
	for candidate: Control in screen.track_buttons:
		if screen.track_scroll.get_global_rect().encloses(candidate.get_global_rect()): visible_card = candidate
	assert_object(visible_card).is_not_null()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = visible_card.get_global_rect().get_center()
	press.global_position = press.position
	press.pressed = true
	get_viewport().push_input(press, true)
	var release := press.duplicate()
	release.pressed = false
	get_viewport().push_input(release, true)
	await get_tree().process_frame
	assert_int(screen.selected_index).is_equal(screen.track_buttons.find(visible_card))

