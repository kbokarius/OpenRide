class_name NeonSetup
extends HubScreen
## Scrollable track library; primary ride controls stay fixed and no scrollbar is shown.
var minutes := 20
var tier := "challenging"
var reference_power := 150
var selected_index := 0
var random_seed := 0
var look := GameTheme.new(Color("79b8d5"), Color("0b1019"), 0.0, false, true)
var course: Dictionary = {}
var tier_buttons: Dictionary = {}
var track_buttons: Array[Button] = []
var _track_keys := {}
var _track_rows: Array[Dictionary] = []
var length_picker: Segmented
var length_label: Label
var range_label: Label
var course_label: Label
var start_button: Button
var sensor_label: Label
var track_list: VBoxContainer
var track_scroll: ScrollContainer
var _waiting := false
var _loading_records := true
var _progress: Dictionary = {}
var _panel: Control
var _replay_id := ""
var _replay_course: Dictionary = {}

func build() -> void:
	var background := ColorRect.new()
	background.color = Color("090f18")
	background.size = size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var bar := top_bar("Lane Smash", look)
	bar.get_node("Title").text = "Lane Smash"
	bar.get_node("Back").text = "Exit"
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var extras := look.button("Settings & history", _open_extras, GameTheme.SECONDARY)
	extras.custom_minimum_size = Vector2(380, 120)
	bar.add_child(extras)
	var label := look.label("TRACK LIBRARY", 34, GameTheme.MUTED)
	label.position = Vector2(56, 170)
	add_child(label)
	var count := look.label("25 tracks · scroll to explore", 34, GameTheme.MUTED)
	count.position = Vector2(590, 170)
	add_child(count)
	track_scroll = ScrollContainer.new()
	track_scroll.position = Vector2(56, 234)
	track_scroll.size = Vector2(1040, 810)
	track_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	track_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	track_scroll.follow_focus = true
	add_child(track_scroll)
	track_list = VBoxContainer.new()
	track_list.custom_minimum_size = Vector2(1016, 0)
	track_list.add_theme_constant_override("separation", 24)
	track_scroll.add_child(track_list)
	var right := VBoxContainer.new()
	right.position = Vector2(1150, 170)
	right.custom_minimum_size = Vector2(714, 0)
	right.add_theme_constant_override("separation", 12)
	add_child(right)
	length_label = look.label("DURATION", 34, GameTheme.MUTED)
	right.add_child(length_label)
	length_picker = Segmented.new(["10", "15", "20", "30"], ["10 min", "15 min", "20 min", "30 min"], str(minutes), look, 160)
	length_picker.font_size = 34
	length_picker.animate_selection = false
	for button in length_picker.buttons:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 34)
	length_picker.changed.connect(func(value: String):
		minutes = int(value)
		reference_power = 150
		random_seed = 0
		_replay_id = ""
		_replay_course = {}
		_rebuild_tracks()
		_refresh_course())
	right.add_child(length_picker)
	right.add_child(look.label("RESISTANCE", 34, GameTheme.MUTED))
	var tiers := VBoxContainer.new()
	tiers.add_theme_constant_override("separation", 24)
	right.add_child(tiers)
	for row_ids in [["light", "moderate", "hard"], ["challenging", "extreme"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		tiers.add_child(row)
		for id: String in row_ids:
			var button := look.button(id.capitalize(), func(): _pick_tier(id), GameTheme.SECONDARY)
			button.custom_minimum_size = Vector2(222 if row_ids.size() == 3 else 345, 120)
			button.add_theme_font_size_override("font_size", 34)
			row.add_child(button)
			tier_buttons[id] = button
	range_label = look.label("", 34, GameTheme.MUTED)
	right.add_child(range_label)
	course_label = look.label("", 38)
	course_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	course_label.custom_minimum_size = Vector2(714, 0)
	right.add_child(course_label)
	sensor_label = look.label("", 34, GameTheme.MUTED)
	sensor_label.position = Vector2(1150, 864)
	add_child(sensor_label)
	start_button = look.button("Start ride", _start, GameTheme.PRIMARY)
	start_button.name = "Start"
	start_button.position = Vector2(1150, 925)
	start_button.custom_minimum_size = Vector2(714, 120)
	add_child(start_button)
	InputBus.frame_updated.connect(_refresh_sensors)
	_rebuild_tracks()
	_refresh_course()
	_load_progress.call_deferred()

func _rebuild_tracks() -> void:
	for child in track_list.get_children():
		track_list.remove_child(child)
		child.queue_free()
	track_buttons.clear()
	_track_keys.clear()
	_track_rows = LaneSmashCatalog.tracks(minutes)
	var random_button := look.button("Generate random track  ↻", _random_track, GameTheme.SECONDARY)
	random_button.custom_minimum_size = Vector2(1016, 120)
	track_list.add_child(random_button)
	for item in _track_rows:
		var index := track_buttons.size()
		var button := look.button("%02d    %s\n         %s" % [index + 1, item.title, item.description], func(): _pick_track(index), GameTheme.SECONDARY)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(1016, 170)
		button.add_theme_font_size_override("font_size", 34)
		track_list.add_child(button)
		track_buttons.append(button)
	track_scroll.scroll_vertical = 0

func _pick_track(index: int) -> void:
	selected_index = index
	random_seed = 0
	_replay_id = ""
	_replay_course = {}
	reference_power = 150
	_refresh_course()

func _random_track() -> void:
	random_seed = randi_range(1, 2147483646)
	_replay_id = ""
	_replay_course = {}
	reference_power = 150
	_refresh_course()

func _pick_tier(id: String) -> void:
	tier = id
	_refresh_course()

func _refresh_course() -> void:
	var id := LaneSmashCatalog.random_id(minutes, random_seed) if random_seed > 0 else "ls_%d_%02d" % [minutes, selected_index + 1]
	course = _replay_course.duplicate(true) if not _replay_course.is_empty() else NeonCourse.load_course(id)
	for i in track_buttons.size():
		var row: Dictionary = _track_rows[i]
		track_buttons[i].text = "%02d    %s  /  %s\n         %s\n         %s" % [i + 1, row.title, LaneSmashEnvironment.TITLES[row.background], row.description, _score_text(row.id)]
		look.style_button(track_buttons[i], GameTheme.PRIMARY if i == selected_index and random_seed == 0 and _replay_id.is_empty() else GameTheme.SECONDARY)
		track_buttons[i].add_theme_font_size_override("font_size", 34)
	for key in tier_buttons:
		look.style_button(tier_buttons[key], GameTheme.PRIMARY if key == tier else GameTheme.SECONDARY)
		tier_buttons[key].add_theme_font_size_override("font_size", 34)
	length_picker.visible = _replay_id.is_empty()
	length_label.text = "DURATION" if _replay_id.is_empty() else "SAVED RIDE · %d MIN" % minutes
	var lo: int = NeonRules.TIERS[tier]
	range_label.text = "%d–%d resistance across six lanes" % [lo, lo + 41]
	var palette := NeonWorlds.world(str(course.get("theme", "arctic")))
	course_label.text = "%s\n%s  ·  %s\n%s" % [course.get("title", ""), palette.title, LaneSmashEnvironment.TITLES.get(course.get("background", "orbital"), "Prismatic flow"), _score_text(str(course.get("courseId", "")))]
	_refresh_sensors()

func _refresh_sensors() -> void:
	if not is_instance_valid(start_button): return
	var fresh := InputBus.sample_age_ms <= 1500
	start_button.disabled = _waiting or _loading_records or not fresh or course.is_empty()
	sensor_label.text = "Loading saved rides…" if _loading_records else ("Bike connected · ready" if fresh else "Waiting for bike sensor data")

func _start() -> void:
	if start_button.disabled: return
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
	_refresh_course()


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


func _open_extras() -> void:
	var box := _modal("SETTINGS & RIDE HISTORY")
	var info := GameRegistry.info("neon_vector")
	for key in ["ghost", "motion", "music"]:
		var row := OptionRow.new(info.option_spec(key), GameOptions.get_value(info, key, rider_id), 1700, look)
		row.changed.connect(func(k: String, v: String): GameOptions.set_value(info, k, v, rider_id))
		box.add_child(row)
	box.add_child(look.label("RECENT RIDES · tap one to replay its saved course", 40))
	var history: Array = _progress.get("history", [])
	if history.is_empty():
		box.add_child(look.label("Your rides appear here after you start a track.\nTap a saved ride to replay the same course.", 36, GameTheme.MUTED))
	for record: Dictionary in history:
		var result: Dictionary = record.result
		var date := Time.get_date_string_from_unix_time(int(record.get("updatedMs", 0)) / 1000)
		var text := "%s · %s · %s\n%s · %d points · %d stars · %s" % [date, result.get("title", result.courseId), str(result.status).capitalize(), HubTheme.clock(int(result.activeDurationMs) / 1000.0), int(result.scoreUnits) / NeonRules.UNIT, int(result.get("stars", 0)), str(result.difficulty).capitalize()]
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
	minutes = int(record.course.durationMs) / 60000
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


func _score_text(id: String) -> String:
	var cache_key := "%s:%s:%d" % [id, tier, reference_power]
	if not _track_keys.has(cache_key):
		var data := _replay_course if id == _replay_course.get("courseId", "") else NeonCourse.load_course(id)
		if data.is_empty(): return "No previous ride"
		var rules := NeonRules.new()
		if not rules.configure(data, tier, reference_power).is_empty(): return "No previous ride"
		_track_keys[cache_key] = rules.comparison_key(rider_id)
	var stats: Dictionary = _progress.get("trackStats", {}).get(_track_keys[cache_key], {})
	if stats.is_empty(): return "No previous ride at this difficulty"
	var last := "Last: %d" % (int(stats.lastScoreUnits) / NeonRules.UNIT)
	if stats.lastStatus != "completed": last += " (partial)"
	var best := "Best: %d" % (int(stats.bestScoreUnits) / NeonRules.UNIT) if int(stats.bestScoreUnits) >= 0 else "No completed best"
	return "%s  /  %s" % [last, best]
