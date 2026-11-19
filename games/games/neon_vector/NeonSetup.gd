class_name NeonSetup
extends HubScreen
## The Lane Smash selector: the only landing screen. A scrollable track library on the left,
## the ride's setup and Start on the right; no scrollbar is shown.
##
## Layout (1920x1080 stage, LaneSmashMenuTheme's 8 px grid, 56 px screen margin):
##   Header   y 24-144    Exit · LANE SMASH · now playing · Settings & history
##   Library  x 56-1096   caption row at y 172, then the list from y 224 to 1056
##   Setup    x 1136-1864 one panel from y 172 to 1056: duration, resistance, the selected
##                         track, sensor status and Start, on 32 px side padding
## Every touch target is at least 120 px tall and 24 px from its neighbours (the hub's rule),
## and no text is under 34 px.
const TOP := 24.0
const HEADER_H := 120.0
const CONTENT_TOP := 172.0
const CONTENT_BOTTOM := 1056.0
const LIBRARY_W := 1040.0
const PANEL_X := 1136.0
const PANEL_W := 728.0
const PANEL_PAD := 32.0

var minutes := 20
var tier := "challenging"
var reference_power := 150
var selected_index := 0
var random_seed := 0
var look := LaneSmashMenuTheme.shared()
var course: Dictionary = {}
var tier_buttons: Dictionary = {}
var track_buttons: Array[LaneSmashTrackCard] = []
var _score_text_cache := {}
var _track_rows: Array[Dictionary] = []
var length_picker: Segmented
var length_label: Label
var range_label: Label
var course_label: Label
var palette_label: Label
var score_label: Label
var start_button: Button
var sensor_label: Label
var playing_label: Label
var track_list: VBoxContainer
var track_scroll: ScrollContainer
var library_drag: LaneSmashDragScroll   ## finger scrolling for the track library, cards included
var _panel_drag: LaneSmashDragScroll    ## and for the settings and history list
var _waiting := false
var _loading_records := true
var _progress: Dictionary = {}
var _panel: Control
var _replay_id := ""
var _replay_course: Dictionary = {}
var _backdrop: ShaderMaterial
var _wordmark: Label     ## "SMASH": tinted through self_modulate so it can pulse with the music
var _rule: ColorRect     ## the line under the header
var _travel := 0.0
var _reduced := false


func build() -> void:
	var info := GameRegistry.info("neon_vector")
	for key in ["music", "sfx"]: GameOptions.get_value(info, key, rider_id)
	GameOptions.apply_audio()
	_reduced = GameOptions.get_value(info, "motion", rider_id) == "reduced"
	_build_backdrop()
	_build_header()
	_build_library()
	_build_setup()
	InputBus.frame_updated.connect(_refresh_sensors)
	_rebuild_tracks()
	_refresh_course()
	_load_progress.call_deferred()


## The selected track's own sky, far back and dark, across the whole window.
func _build_backdrop() -> void:
	_backdrop = ShaderMaterial.new()
	_backdrop.shader = preload("res://games/neon_vector/menu_backdrop.gdshader")
	var sky := ColorRect.new()
	sky.name = "Backdrop"
	sky.material = _backdrop
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	Stage.bleed(sky)
	_backdrop.set_shader_parameter("aspect", Stage.visible_size.x / Stage.visible_size.y)


func _build_header() -> void:
	# One row across the margins, so nothing in it can overlap whatever its text measures.
	var bar := HBoxContainer.new()
	bar.name = "TopBar"
	bar.position = Vector2(LaneSmashMenuTheme.MARGIN, TOP)
	bar.size = Vector2(HubTheme.W - 2 * LaneSmashMenuTheme.MARGIN, HEADER_H)
	bar.add_theme_constant_override("separation", LaneSmashMenuTheme.S4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var exit := look.button("Exit", back_pressed, GameTheme.SECONDARY)
	exit.name = "Back"
	exit.custom_minimum_size = Vector2(220, HEADER_H)
	bar.add_child(exit)
	# The wordmark: one line in two colours, on the header's centre line.
	var mark := HBoxContainer.new()
	mark.name = "Title"
	mark.add_theme_constant_override("separation", 18)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(mark)
	for part: Array in [["LANE", LaneSmashMenuTheme.TEXT], ["SMASH", Color.WHITE]]:
		var word := look.label(part[0], 92, part[1])
		word.add_theme_font_override("font", look.caps_font())
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.add_child(word)
		_wordmark = word
	_wordmark.self_modulate = LaneSmashMenuTheme.ACCENT
	# What the jukebox is playing, right-aligned against the settings button.
	var playing := VBoxContainer.new()
	playing.name = "NowPlaying"
	playing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playing.alignment = BoxContainer.ALIGNMENT_CENTER
	playing.add_theme_constant_override("separation", 0)
	playing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(playing)
	var playing_caption := look.caption("Now playing", LaneSmashMenuTheme.TEXT_FAINT, LaneSmashMenuTheme.LABEL)
	playing_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	playing.add_child(playing_caption)
	playing_label = look.label("", LaneSmashMenuTheme.BODY, LaneSmashMenuTheme.TEXT_MUTED)
	playing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	playing_label.clip_text = true
	playing_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	playing.add_child(playing_label)
	# A small live meter of the soundtrack beside its title.
	var meter := LaneSmashSpectrum.new()
	meter.name = "Spectrum"
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(meter)
	var extras := look.button("Settings & history", _open_extras, GameTheme.SECONDARY)
	extras.name = "Extras"
	extras.custom_minimum_size = Vector2(400, HEADER_H)
	bar.add_child(extras)
	var jukebox := LaneSmashLook.jukebox()
	if jukebox != null:
		jukebox.track_changed.connect(func(_index: int): _refresh_playing())
		jukebox.playback_changed.connect(_refresh_playing)
	AudioDirector.user_audio_changed.connect(_refresh_playing)
	_refresh_playing()
	var rule := ColorRect.new()
	rule.position = Vector2(LaneSmashMenuTheme.MARGIN, TOP + HEADER_H + 12)
	rule.size = Vector2(HubTheme.W - 2 * LaneSmashMenuTheme.MARGIN, 2)
	rule.color = Color(LaneSmashMenuTheme.ACCENT, 0.22)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	_rule = rule


func _refresh_playing() -> void:
	if not is_instance_valid(playing_label): return
	var jukebox := LaneSmashLook.jukebox()
	var title := str(jukebox.title()) if jukebox != null else ""
	playing_label.text = "Music off" if not AudioDirector.user_music_enabled else (title if not title.is_empty() else "—")


func _build_library() -> void:
	var caption := look.caption("Track library", LaneSmashMenuTheme.TEXT_MUTED, LaneSmashMenuTheme.LABEL)
	caption.position = Vector2(LaneSmashMenuTheme.MARGIN, CONTENT_TOP)
	add_child(caption)
	var count := look.caption("25 tracks · scroll to explore", LaneSmashMenuTheme.TEXT_FAINT, LaneSmashMenuTheme.LABEL)
	count.position = Vector2(LaneSmashMenuTheme.MARGIN, CONTENT_TOP)
	count.size = Vector2(LIBRARY_W, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(count)
	track_scroll = ScrollContainer.new()
	track_scroll.position = Vector2(LaneSmashMenuTheme.MARGIN, CONTENT_TOP + 52)
	track_scroll.size = Vector2(LIBRARY_W, CONTENT_BOTTOM - CONTENT_TOP - 52)
	track_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	track_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	track_scroll.follow_focus = true
	add_child(track_scroll)
	library_drag = LaneSmashDragScroll.new()
	track_scroll.add_child(library_drag)
	track_list = VBoxContainer.new()
	track_list.custom_minimum_size = Vector2(LIBRARY_W, 0)
	track_list.add_theme_constant_override("separation", LaneSmashMenuTheme.S3)
	track_scroll.add_child(track_list)


func _build_setup() -> void:
	var inner := PANEL_W - 2 * PANEL_PAD
	var panel := Panel.new()
	panel.name = "Setup"
	panel.position = Vector2(PANEL_X, CONTENT_TOP)
	panel.size = Vector2(PANEL_W, CONTENT_BOTTOM - CONTENT_TOP)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", look.panel_style(Color(LaneSmashMenuTheme.SURFACE_SOLID, 0.9)))
	add_child(panel)
	var box := VBoxContainer.new()
	box.position = Vector2(PANEL_X + PANEL_PAD, CONTENT_TOP + LaneSmashMenuTheme.S3)
	box.size = Vector2(inner, CONTENT_BOTTOM - CONTENT_TOP - 2 * LaneSmashMenuTheme.S3)
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	length_label = look.caption("Duration", LaneSmashMenuTheme.TEXT_MUTED, LaneSmashMenuTheme.LABEL)
	box.add_child(length_label)
	box.add_child(_gap(LaneSmashMenuTheme.S1))
	length_picker = Segmented.new(["10", "15", "20", "30"], ["10 min", "15 min", "20 min", "30 min"], str(minutes), look, 140)
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
	box.add_child(length_picker)
	box.add_child(_gap(LaneSmashMenuTheme.S2))
	var resistance := HBoxContainer.new()
	resistance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(resistance)
	var resistance_caption := look.caption("Resistance", LaneSmashMenuTheme.TEXT_MUTED, LaneSmashMenuTheme.LABEL)
	resistance_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resistance.add_child(resistance_caption)
	range_label = look.caption("", LaneSmashMenuTheme.TEXT_FAINT, LaneSmashMenuTheme.LABEL)
	range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	resistance.add_child(range_label)
	box.add_child(_gap(LaneSmashMenuTheme.S1))
	var tiers := VBoxContainer.new()
	tiers.add_theme_constant_override("separation", LaneSmashMenuTheme.S3)
	box.add_child(tiers)
	for row_ids in [["kid", "light", "moderate"], ["hard", "challenging", "extreme"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", LaneSmashMenuTheme.S3)
		tiers.add_child(row)
		for id: String in row_ids:
			var button := look.button(id.capitalize(), func(): _pick_tier(id), GameTheme.SECONDARY)
			button.name = "Tier_" + id
			button.custom_minimum_size = Vector2(180, 120)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", 34)
			row.add_child(button)
			tier_buttons[id] = button
	box.add_child(_gap(LaneSmashMenuTheme.S2))
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(inner, 2)
	rule.color = Color(LaneSmashMenuTheme.ACCENT, 0.18)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	box.add_child(_gap(LaneSmashMenuTheme.S2 - 4))
	course_label = look.label("", LaneSmashMenuTheme.HEADING, LaneSmashMenuTheme.TEXT)
	course_label.clip_text = true
	course_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(course_label)
	palette_label = look.label("", LaneSmashMenuTheme.LABEL, LaneSmashMenuTheme.ACCENT.lerp(Color.WHITE, 0.3))
	palette_label.clip_text = true
	box.add_child(palette_label)
	score_label = look.label("", LaneSmashMenuTheme.LABEL, LaneSmashMenuTheme.TEXT_MUTED)
	score_label.clip_text = true
	score_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(score_label)
	var spring := Control.new()
	spring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spring)
	sensor_label = look.label("", LaneSmashMenuTheme.LABEL, LaneSmashMenuTheme.TEXT_MUTED)
	box.add_child(sensor_label)
	box.add_child(_gap(LaneSmashMenuTheme.S1 + 4))
	start_button = look.button("Start ride", _start, GameTheme.PRIMARY)
	start_button.name = "Start"
	start_button.custom_minimum_size = Vector2(inner, 120)
	box.add_child(start_button)


static func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _process(delta: float) -> void:
	if _backdrop == null or is_instance_valid(_panel) or not is_visible_in_tree(): return
	if _reduced: return
	_travel += delta * 3.5
	_backdrop.set_shader_parameter("travel", _travel)
	var jukebox := LaneSmashLook.jukebox()
	if jukebox != null:
		_backdrop.set_shader_parameter("music", Vector4(jukebox.calm_bass, jukebox.calm_mid, jukebox.calm_treble, jukebox.pulse))
		_backdrop.set_shader_parameter("swirl", jukebox.flow)
	_pulse_chrome(LaneSmashLook.music())


## The menu's accent pieces breathe with the music: the wordmark, the header rule and the
## Start button's edge drift toward the companion hue and lift on each kick. Text stays put.
func _pulse_chrome(levels: Vector4) -> void:
	var live := LaneSmashLook.pulsed(LaneSmashMenuTheme.ACCENT, levels)
	if is_instance_valid(_wordmark): _wordmark.self_modulate = live
	if is_instance_valid(_rule): _rule.color = Color(live, 0.22 + 0.4 * levels.w + 0.2 * levels.x)
	if is_instance_valid(start_button) and not start_button.disabled:
		var edge := start_button.get_theme_stylebox("normal") as StyleBoxFlat
		var wanted := Color(live, 0.95)
		if edge != null and not edge.border_color.is_equal_approx(wanted): edge.border_color = wanted


func _rebuild_tracks() -> void:
	for child in track_list.get_children():
		track_list.remove_child(child)
		child.queue_free()
	track_buttons.clear()
	_score_text_cache.clear()
	_track_rows = LaneSmashCatalog.tracks(minutes)
	var random_button := look.button("Generate random track  ↻", library_drag.guard(_random_track), GameTheme.SECONDARY)
	random_button.name = "Random"
	random_button.custom_minimum_size = Vector2(LIBRARY_W, 120)
	random_button.mouse_filter = Control.MOUSE_FILTER_PASS  # a drag that starts on it scrolls the library
	track_list.add_child(random_button)
	for item in _track_rows:
		var index := track_buttons.size()
		var button := LaneSmashTrackCard.new()
		button.preview_clip = track_scroll
		button.configure(item, index, look, library_drag.guard(func(): _pick_track(index)))
		button.reduced_motion = _reduced
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
	course = _replay_course.duplicate(true) if not _replay_course.is_empty() else NeonCourse.for_difficulty(NeonCourse.load_course(id), tier)
	for i in track_buttons.size():
		var row: Dictionary = _track_rows[i]
		track_buttons[i].set_summary(_score_text(row.id), i == selected_index and random_seed == 0 and _replay_id.is_empty())
	for key in tier_buttons:
		look.style_button(tier_buttons[key], GameTheme.PRIMARY if key == tier else GameTheme.SECONDARY)
		tier_buttons[key].add_theme_font_size_override("font_size", 34)
	length_picker.visible = _replay_id.is_empty()
	length_label.text = "DURATION" if _replay_id.is_empty() else "SAVED RIDE · %d MIN" % minutes
	range_label.text = "%d–%d ACROSS SIX LANES" % [NeonRules.band(0, tier).x, NeonRules.band(5, tier).y]
	var palette := NeonWorlds.world(str(course.get("theme", "arctic")))
	var sky_id := str(course.get("background", "orbital"))
	course_label.text = str(course.get("title", ""))
	palette_label.text = "%s  ·  %s" % [palette.title, LaneSmashEnvironment.TITLES.get(sky_id, "Prismatic flow")]
	score_label.text = _score_text(str(course.get("courseId", "")))
	# The backdrop previews the selected track's own colours and sky.
	var colors := LaneSmashEnvironment.palette(Color(palette.accent))
	_backdrop.set_shader_parameter("primary", colors[0])
	_backdrop.set_shader_parameter("secondary", colors[1])
	_backdrop.set_shader_parameter("style", maxi(0, LaneSmashEnvironment.TITLES.keys().find(sky_id)))
	_refresh_sensors()

func _refresh_sensors() -> void:
	if not is_instance_valid(start_button): return
	var fresh := InputBus.sample_age_ms <= 1500
	start_button.disabled = _waiting or _loading_records or not fresh or course.is_empty()
	sensor_label.text = "Loading saved rides…" if _loading_records else ("Bike connected · ready" if fresh else "Waiting for bike sensor data")
	sensor_label.add_theme_color_override("font_color", GameTheme.GOOD if fresh and not _loading_records else LaneSmashMenuTheme.TEXT_MUTED)

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
	_score_text_cache.clear()
	_loading_records = false
	if not bool(_progress.get("ok", false)):
		notice.emit(str(_progress.get("error", "Could not load saved rides.")))
	_refresh_course()


func _close_panel() -> void:
	for card in track_buttons: card.set_process(true)
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
	for card in track_buttons: card.set_process(false)
	var width := HubTheme.W - 2 * LaneSmashMenuTheme.MARGIN
	_panel = Control.new()
	_panel.size = Vector2(1920, 1080)
	add_child(_panel)
	var shade := ColorRect.new()
	shade.color = Color("060b15")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(shade)
	Stage.bleed(shade)
	var heading := look.label(title, LaneSmashMenuTheme.TITLE, LaneSmashMenuTheme.TEXT)
	heading.add_theme_font_override("font", look.caps_font())
	heading.position = Vector2(LaneSmashMenuTheme.MARGIN, TOP)
	heading.size = Vector2(width - 340, HEADER_H)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(heading)
	var done := look.button("Done", _close_panel, GameTheme.PRIMARY)
	done.name = "Done"
	done.custom_minimum_size = Vector2(300, HEADER_H)
	done.size = done.custom_minimum_size
	done.position = Vector2(HubTheme.W - LaneSmashMenuTheme.MARGIN - 300, TOP)
	_panel.add_child(done)
	var rule := ColorRect.new()
	rule.position = Vector2(LaneSmashMenuTheme.MARGIN, TOP + HEADER_H + 12)
	rule.size = Vector2(width, 2)
	rule.color = Color(LaneSmashMenuTheme.ACCENT, 0.22)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(LaneSmashMenuTheme.MARGIN, CONTENT_TOP)
	scroll.size = Vector2(width, CONTENT_BOTTOM - CONTENT_TOP)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	_panel.add_child(scroll)
	_panel_drag = LaneSmashDragScroll.new()
	scroll.add_child(_panel_drag)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(width, 0)
	content.add_theme_constant_override("separation", LaneSmashMenuTheme.S3)
	scroll.add_child(content)
	return content


func _open_extras() -> void:
	var box := _modal("Settings & ride history")
	var width := HubTheme.W - 2 * LaneSmashMenuTheme.MARGIN
	var info := GameRegistry.info("neon_vector")
	for group: Array in [["Audio", ["music", "sfx"]], ["Ride", ["ghost", "motion", "graphics"]]]:
		box.add_child(look.caption(group[0], LaneSmashMenuTheme.TEXT_MUTED, LaneSmashMenuTheme.LABEL))
		for key: String in group[1]:
			var row := OptionRow.new(info.option_spec(key), GameOptions.get_value(info, key, rider_id), width, look)
			row.changed.connect(func(k: String, v: String):
				if not GameOptions.set_value(info, k, v, rider_id):
					notice.emit("Could not save this setting. Please try again.")
					_open_extras.call_deferred()
					return
				if k == "motion":
					_reduced = v == "reduced"
					for card in track_buttons: card.reduced_motion = _reduced)
			box.add_child(row)
			if row.segmented != null: row.segmented.animate_selection = false
			if key == "music":
				# The track picker and seek slider sit directly under the Music switch.
				box.add_child(LaneSmashMusicPanel.new(look, width, HubTheme.TARGET, HubTheme.GAP))
	box.add_child(look.caption("Recent rides · tap one to replay its saved course", LaneSmashMenuTheme.TEXT_MUTED, LaneSmashMenuTheme.LABEL))
	var history: Array = _progress.get("history", [])
	if history.is_empty():
		box.add_child(look.label("Your rides appear here after you start a track.\nTap a saved ride to replay the same course.", LaneSmashMenuTheme.BODY, LaneSmashMenuTheme.TEXT_FAINT))
	for record: Dictionary in history:
		var result: Dictionary = record.result
		var date := Time.get_date_string_from_unix_time(int(record.get("updatedMs", 0)) / 1000)
		var text := "%s · %s · %s\n%s · %s points · %d stars · %s" % [date, result.get("title", result.courseId), str(result.status).capitalize(), HubTheme.clock(int(result.activeDurationMs) / 1000.0), HudTheme.grouped(int(result.scoreUnits) / NeonRules.UNIT), int(result.get("stars", 0)), str(result.get("difficulty", "challenging")).capitalize()]
		var replay := look.button(text, _panel_drag.guard(func(): _replay(str(record.attemptId))), GameTheme.SECONDARY)
		replay.custom_minimum_size = Vector2(width, 160)
		replay.add_theme_font_size_override("font_size", 34)
		replay.mouse_filter = Control.MOUSE_FILTER_PASS  # a drag that starts on a ride scrolls the history
		box.add_child(replay)


func _replay(id: String) -> void:
	var reply := await NeonRecords.request({"action": "get", "attemptId": id}, rider_id)
	if not bool(reply.get("ok", false)):
		notice.emit(str(reply.get("error", "Saved ride not found.")))
		return
	var record: Dictionary = reply.get("record", {})
	if not NeonRecords.valid_record(record):
		notice.emit("This saved ride is damaged and cannot be replayed.")
		return
	var saved_tier := str(record.result.get("difficulty", "challenging"))
	var saved_power: Variant = record.result.get("referencePower", 150)
	if not NeonRules.TIERS.has(saved_tier) or not LaneSmashPath._number(saved_power) or float(saved_power) < 1 or float(saved_power) > 2000:
		notice.emit("This saved ride has invalid difficulty settings.")
		return
	var errors := NeonCourse.validate(record.course)
	if not errors.is_empty():
		notice.emit("This saved course cannot be played by this version.")
		return
	_replay_id = id
	_replay_course = record.course
	tier = saved_tier
	reference_power = int(saved_power)
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
	if not _score_text_cache.has(cache_key):
		var data := _replay_course if id == _replay_course.get("courseId", "") else NeonCourse.for_difficulty(NeonCourse.load_course(id), tier)
		if data.is_empty(): return "No previous ride"
		var rules := NeonRules.new()
		if not rules.configure(data, tier, reference_power).is_empty(): return "No previous ride"
		_score_text_cache[cache_key] = NeonBenchmark.menu_text(NeonBenchmark.select(_progress.get("trackStats", {}), rules, rider_id))
	return _score_text_cache[cache_key]
