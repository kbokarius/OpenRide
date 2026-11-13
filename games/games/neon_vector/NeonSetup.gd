class_name NeonSetup
extends HubScreen
## Full-course setup within the existing hub. Shared buttons, typography and Back behavior.

const FAMILIES := {"steady_flow": ["Steady Flow", "Steady points. Smooth lane changes."], "intervals": ["Intervals", "Power bursts. Room to recover."], "rolling_climb": ["Rolling Climb", "Climb gradually across six lanes."], "tutorial": ["First Contact", "Learn the controls in 5 minutes."]}
var family := "steady_flow"
var minutes := 20
var tier := "intermediate"
var reference_power := 150
var daily_date := ""
var look := GameTheme.new(Color("67d8ff"), Color("0b132b"))
var course: Dictionary = {}
var family_buttons: Dictionary = {}
var tier_buttons: Dictionary = {}
var length_picker: Segmented
var length_label: Label
var power_label: Button
var targets_label: Label
var range_label: Label
var course_label: Label
var start_button: Button
var sensor_label: Label
var _waiting := false
var _loading_records := true
var _progress: Dictionary = {}
var _panel: Control
var _replay_id := ""
var _replay_course: Dictionary = {}


func build() -> void:
	reference_power = clampi(int(state.rider.get("ftp_watts", 150)), 1, 2000)
	daily_date = Time.get_date_string_from_system()
	var bar := top_bar("NEON VECTOR", look)
	var bar_spacer := Control.new()
	bar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(bar_spacer)
	var extras := look.button("Style & history", _open_extras, GameTheme.SECONDARY)
	extras.custom_minimum_size = Vector2(380, 120)
	extras.add_theme_font_size_override("font_size", 40)
	bar.add_child(extras)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(1040, 0)
	left.add_theme_constant_override("separation", 24)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left_scroll := ScrollContainer.new()
	left_scroll.position = Vector2(50, 170)
	left_scroll.size = Vector2(1080, 860)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	left_scroll.follow_focus = true
	add_child(left_scroll)
	left_scroll.add_child(left)
	left.add_child(look.label("CHOOSE YOUR SIGNAL", 34, GameTheme.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	left.add_child(grid)
	for id: String in FAMILIES:
		var button := look.button("%s\n%s" % FAMILIES[id], func(): _pick_family(id), GameTheme.SECONDARY)
		button.custom_minimum_size = Vector2(510, 170)
		button.add_theme_font_size_override("font_size", 34)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(button)
		family_buttons[id] = button
	var daily := look.button("DAILY SIGNAL · %s\n20 minutes · a new course, saved for replay" % daily_date, func(): _pick_family("daily"), GameTheme.SECONDARY)
	daily.custom_minimum_size = Vector2(1040, 150)
	daily.add_theme_font_size_override("font_size", 34)
	left.add_child(daily)
	family_buttons["daily"] = daily
	course_label = look.label("", 34, GameTheme.MUTED)
	course_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(course_label)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(708, 0)
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right_scroll := ScrollContainer.new()
	right_scroll.position = Vector2(1150, 150)
	right_scroll.size = Vector2(720, 710)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	right_scroll.follow_focus = true
	add_child(right_scroll)
	right_scroll.add_child(right)
	length_label = look.label("RIDE LENGTH", 34, GameTheme.MUTED)
	right.add_child(length_label)
	length_picker = Segmented.new(["10", "20", "30"], ["10 min", "20 min", "30 min"], str(minutes), look, 220)
	length_picker.changed.connect(func(value: String): minutes = int(value); _refresh_course())
	right.add_child(length_picker)
	right.add_child(look.label("RESISTANCE DIFFICULTY", 34, GameTheme.MUTED))
	var tiers := GridContainer.new()
	tiers.columns = 2
	tiers.add_theme_constant_override("h_separation", 24)
	tiers.add_theme_constant_override("v_separation", 24)
	right.add_child(tiers)
	for id: String in NeonRules.TIERS:
		var button := look.button(id.capitalize(), func(): _pick_tier(id), GameTheme.SECONDARY)
		button.custom_minimum_size = Vector2(342, 120)
		button.add_theme_font_size_override("font_size", 40)
		tiers.add_child(button)
		tier_buttons[id] = button
	range_label = look.label("", 34, GameTheme.MUTED)
	right.add_child(range_label)
	power_label = look.button("", _open_power, GameTheme.SECONDARY)
	power_label.custom_minimum_size = Vector2(708, 120)
	power_label.add_theme_font_size_override("font_size", 40)
	right.add_child(power_label)
	targets_label = look.label("", 34, GameTheme.MUTED)
	right.add_child(targets_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(spacer)
	sensor_label = look.label("", 34, GameTheme.MUTED)
	sensor_label.position = Vector2(1150, 865)
	add_child(sensor_label)
	start_button = look.button("Enter the circuit", _start, GameTheme.GO)
	start_button.name = "Start"
	start_button.custom_minimum_size = Vector2(720, 120)
	start_button.position = Vector2(1150, 925)
	add_child(start_button)
	InputBus.frame_updated.connect(_refresh_sensors)
	_refresh_course()
	_load_progress.call_deferred()


func _pick_family(id: String) -> void:
	family = id
	_replay_id = ""
	_replay_course = {}
	_refresh_course()


func _pick_tier(id: String) -> void:
	tier = id
	_refresh_course()


func _refresh_course() -> void:
	var id := "tutorial" if family == "tutorial" else "%s_%d" % [family, minutes]
	course = _replay_course.duplicate(true) if not _replay_course.is_empty() else (NeonCourse.daily(daily_date) if family == "daily" else NeonCourse.load_course(id))
	for key in family_buttons:
		look.style_button(family_buttons[key], GameTheme.PRIMARY if key == family else GameTheme.SECONDARY)
	for key in tier_buttons:
		look.style_button(tier_buttons[key], GameTheme.PRIMARY if key == tier else GameTheme.SECONDARY)
	length_picker.visible = family not in ["daily", "tutorial"] and _replay_id.is_empty()
	length_label.text = "RIDE LENGTH" if length_picker.visible else "RIDE LENGTH · %d MIN" % (int(course.get("durationMs", 0)) / 60000)
	var lo: int = NeonRules.TIERS[tier]
	range_label.text = "%d–%d across six lanes · same course" % [lo, lo + 41]
	power_label.text = "Reference power: %d W  ›" % reference_power
	var legacy := int(course.get("courseVersion", 1)) == 1
	targets_label.text = "Charge targets: %.0f W / %.0f W" % [reference_power * 0.6, reference_power] if legacy else "Burst target: %d W · score grows with output" % reference_power
	var default_note := "150 W is a starting default. Adjust it to suit your rides." if bool(state.rider.get("ftp_is_default", false)) else "Starts from your saved FTP. Independent of resistance."
	if legacy:
		default_note = "Saved original course · original pickup and charge rules"
	course_label.text = "%s · %d minutes\n%d target points · music optional\n%s" % [course.get("title", ""), int(course.get("durationMs", 0)) / 60000, NeonCourse.maximum(course, false, reference_power) / NeonRules.UNIT, default_note]
	_refresh_sensors()


func _refresh_sensors() -> void:
	if not is_instance_valid(start_button):
		return
	var fresh := InputBus.sample_age_ms <= 1500
	start_button.disabled = _waiting or _loading_records or not fresh or course.is_empty()
	sensor_label.text = "Loading saved rides…" if _loading_records else ("Bike connected · ready to ride" if fresh else "Waiting for fresh bike sensor data")


func _start() -> void:
	if start_button.disabled:
		return
	_waiting = true
	_refresh_sensors()
	start.emit({"kind": "just_ride", "game_id": "neon_vector", "mode": "minutes", "length": int(course.durationMs) / 60000,
		"difficulty": "standard", "neon": {"course_id": course.courseId, "lane_difficulty": tier, "reference_power": reference_power, "replay_attempt_id": _replay_id}})


func start_answered() -> void:
	_waiting = false
	_refresh_sensors()


func _load_progress() -> void:
	_progress = await NeonRecords.request({"action": "state"}, rider_id)
	_loading_records = false
	if not bool(_progress.get("ok", false)):
		notice.emit(str(_progress.get("error", "Could not load saved rides.")))
	_refresh_sensors()


func _close_panel() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null


func handle_back() -> bool:
	if is_instance_valid(_panel):
		_close_panel()
		return true
	return false


func _modal(title: String) -> VBoxContainer:
	_close_panel()
	_panel = Control.new()
	_panel.size = Vector2(1920, 1080)
	add_child(_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.05, 0.12, 1.0)
	shade.size = _panel.size
	_panel.add_child(shade)
	var heading := look.label(title, 48)
	heading.position = Vector2(80, 60)
	_panel.add_child(heading)
	var done := look.button("Done", _close_panel, GameTheme.PRIMARY)
	done.position = Vector2(1530, 30)
	done.custom_minimum_size = Vector2(310, 120)
	_panel.add_child(done)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(80, 180)
	scroll.size = Vector2(1760, 850)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	_panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(1730, 0)
	content.add_theme_constant_override("separation", 24)
	scroll.add_child(content)
	return content


func _open_power() -> void:
	var box := _modal("REFERENCE POWER")
	var help := look.label("Power sets burst star targets, not a score cap. Difficulty controls the six resistance lanes.\nChoose a reference you can sustain for short efforts. You can change it before each ride.", 36, GameTheme.MUTED)
	box.add_child(help)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	box.add_child(row)
	var value := look.label("%d W" % reference_power, 64)
	value.custom_minimum_size = Vector2(400, 160)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for change in [-5, 5]:
		var button := look.button("− 5 W" if change < 0 else "+ 5 W", func():
			reference_power = clampi(reference_power + change, 1, 2000)
			value.text = "%d W" % reference_power
			_refresh_course(), GameTheme.SECONDARY)
		button.custom_minimum_size = Vector2(330, 160)
		row.add_child(button)
		if change < 0:
			row.add_child(value)
	var reset := look.button("Use my profile's %d W" % int(state.rider.get("ftp_watts", 150)), func():
		reference_power = clampi(int(state.rider.get("ftp_watts", 150)), 1, 2000)
		value.text = "%d W" % reference_power
		_refresh_course(), GameTheme.SECONDARY)
	reset.custom_minimum_size = Vector2(700, 120)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(reset)
	box.add_child(look.label("Ghosts and records are kept separately for each power target.\nNo resistance or power changes happen automatically on the Bike.", 36, GameTheme.MUTED))


func _open_extras() -> void:
	var box := _modal("YOUR SIGNAL")
	var count := int(_progress.get("completions", 0))
	box.add_child(look.label("%d completed rides · earn new worlds and trails by finishing courses" % count, 36, GameTheme.MUTED))
	var info := GameRegistry.info("neon_vector")
	for key in ["ghost", "motion", "music"]:
		var row := OptionRow.new(info.option_spec(key), GameOptions.get_value(info, key, rider_id), 1700, look)
		row.changed.connect(func(k: String, v: String): GameOptions.set_value(info, k, v, rider_id))
		box.add_child(row)
	for kind in ["world", "trail"]:
		box.add_child(look.label("WORLDS" if kind == "world" else "TRAILS", 40))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 24)
		box.add_child(grid)
		for item: Dictionary in NeonWorlds.WORLDS if kind == "world" else NeonWorlds.TRAILS:
			var unlocked := count >= int(item.rides)
			var chosen: bool = GameOptions.get_value(info, kind, rider_id) == item.id
			var label := str(item.title) + (" · selected" if chosen else (" · %d rides" % item.rides if not unlocked else ""))
			var button := look.button(label, func():
				GameOptions.set_value(info, kind, str(item.id), rider_id)
				_open_extras(), GameTheme.PRIMARY if chosen else GameTheme.SECONDARY)
			button.custom_minimum_size = Vector2(830, 130)
			button.add_theme_font_size_override("font_size", 36)
			button.name = "%s_%s" % [kind, item.id]
			button.disabled = not unlocked
			grid.add_child(button)
	box.add_child(look.label("RECENT RIDES · tap one to replay its saved course", 40))
	var history: Array = _progress.get("history", [])
	if history.is_empty():
		box.add_child(look.label("Your rides appear here, including interrupted attempts.\nFinish First Contact to learn the controls; practice rides do not unlock cosmetics.", 36, GameTheme.MUTED))
	for record: Dictionary in history:
		var result: Dictionary = record.result
		var date := Time.get_date_string_from_unix_time(int(record.get("updatedMs", 0)) / 1000)
		var text := "%s · %s · %s\n%s · %d points · %d stars · %s / %d W" % [date, result.get("title", result.courseId), str(result.status).capitalize(), HubTheme.clock(int(result.activeDurationMs) / 1000.0), int(result.scoreUnits) / NeonRules.UNIT, int(result.get("stars", 0)), str(result.difficulty).capitalize(), int(result.referencePower)]
		var replay := look.button(text, func(): _replay(str(record.attemptId)), GameTheme.SECONDARY)
		replay.custom_minimum_size = Vector2(1700, 160)
		replay.add_theme_font_size_override("font_size", 34)
		box.add_child(replay)


func _replay(id: String) -> void:
	var reply := await NeonRecords.request({"action": "get", "attemptId": id}, rider_id)
	if not bool(reply.get("ok", false)):
		notice.emit(str(reply.get("error", "Saved ride not found.")))
		return
	var record: Dictionary = reply.record
	var errors := NeonCourse.validate(record.get("course", {}))
	if not errors.is_empty():
		notice.emit("This saved course cannot be played by this version.")
		return
	_replay_id = id
	_replay_course = record.course
	tier = str(record.result.difficulty)
	reference_power = int(record.result.referencePower)
	family = str(record.course.get("family", "steady_flow"))
	_close_panel()
	_refresh_course()


func targets() -> Array[Control]:
	var out: Array[Control] = []
	_collect(_panel if is_instance_valid(_panel) else self, out)
	# Scroll containers can contain controls beyond the viewport. Only fully exposed buttons
	# are touch targets for the current frame; the rest are reached by scrolling.
	return out.filter(func(control: Control):
		var ancestor := control.get_parent()
		while ancestor != null and ancestor != self:
			if ancestor is ScrollContainer and not ancestor.get_global_rect().encloses(control.get_global_rect()):
				return false
			ancestor = ancestor.get_parent()
		return true)
