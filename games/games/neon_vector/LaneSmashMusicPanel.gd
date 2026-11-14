class_name LaneSmashMusicPanel
extends VBoxContainer
## Now playing, a track picker and a seek slider for the Lane Smash jukebox.
## Used by the in-ride Audio panel and by Settings & history; it never pauses anything.
##
##   LaneSmashMusicPanel (VBox, `width` wide)
##   ├ Heading (HBox): the track's title, then its artist or the player's state
##   ├ Tracks (HBox): one button per track (hidden when there is nothing to choose)
##   └ Seek (HBox): the slider, then "12:04 / 30:50"
##
## The slider follows playback four times a second. Dragging it only previews the time;
## the jukebox seeks once, on release.

const REFRESH_SEC := 0.25
const ROW_HEIGHT := 76.0
const SEEK_HEIGHT := 72.0
const TIME_WIDTH := 250.0
const TEXT := 30
const GAP := 12

var look: GameTheme
var title_label: Label
var detail_label: Label
var track_row: HBoxContainer
var track_buttons: Array[Button] = []
var seek: SeekBar
var time_label: Label
var _seek_row: HBoxContainer
var _refresh_left := 0.0
var _shown_current := -2
var _shown_enabled := -1
var _shown_tracks := -1
var _row_height := ROW_HEIGHT
var _gap := GAP


## `row_height` and `gap` size the track buttons: the in-ride panel keeps them compact, the
## menu passes the hub's 120 px targets and 24 px gaps.
func _init(theme_look: GameTheme, width: float, row_height := ROW_HEIGHT, gap := GAP) -> void:
	look = theme_look
	_row_height = row_height
	_gap = gap
	name = "MusicPanel"
	custom_minimum_size = Vector2(width, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	var heading := HBoxContainer.new()
	heading.name = "Heading"
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", GAP)
	add_child(heading)
	title_label = look.label("", 34)
	title_label.name = "Title"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(title_label)
	detail_label = look.label("", TEXT, GameTheme.MUTED)
	detail_label.name = "Detail"
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(detail_label)
	track_row = HBoxContainer.new()
	track_row.name = "Tracks"
	track_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_row.add_theme_constant_override("separation", _gap)
	add_child(track_row)
	_seek_row = HBoxContainer.new()
	_seek_row.name = "Seek"
	_seek_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seek_row.add_theme_constant_override("separation", GAP)
	add_child(_seek_row)
	seek = SeekBar.new(look)
	seek.name = "Slider"
	seek.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seek.custom_minimum_size = Vector2(160, SEEK_HEIGHT)
	seek.preview.connect(func(_ratio: float): _show_time())
	seek.released.connect(_on_seek_released)
	_seek_row.add_child(seek)
	time_label = look.label("0:00 / 0:00", TEXT, GameTheme.MUTED)
	time_label.name = "Time"
	# Tabular figures and a reserved width: the slider never resizes as digits change.
	var tabular := FontVariation.new()
	tabular.base_font = time_label.get_theme_font("font")
	tabular.opentype_features = {"tnum": 1}
	time_label.add_theme_font_override("font", tabular)
	time_label.custom_minimum_size = Vector2(TIME_WIDTH, 0)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_seek_row.add_child(time_label)


func _ready() -> void:
	Jukebox.track_changed.connect(_on_jukebox_changed)
	Jukebox.playback_changed.connect(refresh)
	AudioDirector.user_audio_changed.connect(refresh)
	refresh()


func _on_jukebox_changed(_index: int) -> void:
	refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_refresh_left -= delta
	if _refresh_left > 0.0: return
	_refresh_left = REFRESH_SEC
	_follow()


## "12:04", or "1:02:03" from an hour on.
static func clock(seconds: float) -> String:
	var whole := maxi(0, floori(seconds))
	if whole >= 3600: return "%d:%02d:%02d" % [whole / 3600, (whole / 60) % 60, whole % 60]
	return "%d:%02d" % [whole / 60, whole % 60]


## Music can be steered: it is switched on and a track is ready (not still loading).
func enabled() -> bool:
	return AudioDirector.user_music_enabled and Jukebox.current >= 0 and not Jukebox.is_loading()


## Everything that depends on the jukebox's state. Cheap when nothing changed.
func refresh() -> void:
	if not is_inside_tree(): return
	var list: Array = Jukebox.tracks()
	if list.size() != _shown_tracks: _build_tracks(list)
	var on := enabled()
	var state := 1 if on else 0
	if Jukebox.current != _shown_current or state != _shown_enabled:
		_shown_current = Jukebox.current
		_shown_enabled = state
		for i in track_buttons.size():
			_paint(track_buttons[i], GameTheme.PRIMARY if i == Jukebox.current else GameTheme.SECONDARY)
			track_buttons[i].disabled = not on
		track_row.modulate.a = 1.0 if on else 0.45
		_seek_row.modulate.a = 1.0 if on else 0.45
		seek.disabled = not on
	_set_text(title_label, Jukebox.title() if Jukebox.current >= 0 else "No music")
	var detail := Jukebox.artist()
	if not Jukebox.subtitle().is_empty(): detail = "%s · %s" % [detail, Jukebox.subtitle()] if not detail.is_empty() else Jukebox.subtitle()
	if not AudioDirector.user_music_enabled: detail = "Music is off"
	elif Jukebox.is_loading(): detail = "Loading…"
	_set_text(detail_label, detail)
	_follow()


func _follow() -> void:
	if not seek.dragging:
		var length := Jukebox.length_sec()
		seek.set_ratio(Jukebox.position_sec() / length if length > 0.0 else 0.0)
	_show_time()


func _show_time() -> void:
	var length := Jukebox.length_sec()
	var at := seek.ratio * length if seek.dragging else Jukebox.position_sec()
	_set_text(time_label, "%s / %s" % [clock(at), clock(length)])


func _on_seek_released(ratio: float) -> void:
	Jukebox.seek(ratio * Jukebox.length_sec())
	_follow()


func _build_tracks(list: Array) -> void:
	_shown_tracks = list.size()
	_shown_current = -2
	for button in track_buttons:
		track_row.remove_child(button)
		button.queue_free()
	track_buttons.clear()
	# Nothing to choose between with a single track (the built-in fallback loop).
	track_row.visible = list.size() > 1
	if list.size() <= 1: return
	for i in list.size():
		var index := i
		var button := look.button(str(list[i].get("title", "Track %d" % (i + 1))), func(): _pick(index), GameTheme.SECONDARY)
		button.name = "Track_%s" % str(list[i].get("id", i))
		button.custom_minimum_size = Vector2(0, _row_height)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Long titles break onto a second line instead of shrinking below a readable size.
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Menu-sized rows carry the menu's minimum text size; the compact in-ride row keeps TEXT.
		button.add_theme_font_size_override("font_size", TEXT if _row_height < 100.0 else HudTheme.SMALL)
		track_row.add_child(button)
		track_buttons.append(button)


## Only the pill changes with the selection. The text keeps its size, so a wrapped title
## never re-flows (and the row never changes height) when a track is picked or music is off.
func _paint(button: Button, kind: String) -> void:
	var style := look.button_style(kind)
	for state in ["normal", "hover", "disabled", "focus"]: button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("pressed", look.button_style(kind, true))


func _pick(index: int) -> void:
	if index == Jukebox.current: return
	LaneSmashSound.ui("tap")
	Jukebox.select(index, 0.0)


static func _set_text(label: Label, text: String) -> void:
	if label.text != text: label.text = text


## A touch slider drawn in the theme's colours: a full-height hit area, a slim track.
class SeekBar extends Control:
	signal preview(ratio: float)  ## while dragging
	signal released(ratio: float)  ## the drag ended here

	const INSET := 22.0  ## room for the knob at both ends
	const TRACK := 10.0
	const KNOB := 17.0

	var ratio := 0.0
	var dragging := false
	var disabled := false:
		set(value):
			disabled = value
			if value and dragging:
				dragging = false
			queue_redraw()
	var _rail: StyleBoxFlat
	var _fill: StyleBoxFlat
	var _accent: Color
	var _ink: Color

	func _init(look: GameTheme) -> void:
		_accent = look.accent
		_ink = look.ink
		_rail = StyleBoxFlat.new()
		_rail.bg_color = Color(look.ink.lerp(look.accent, 0.22), 1.0)
		_rail.set_corner_radius_all(int(TRACK / 2))
		_fill = _rail.duplicate() as StyleBoxFlat
		_fill.bg_color = look.accent
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE

	func set_ratio(value: float) -> void:
		value = clampf(value, 0.0, 1.0)
		if not is_equal_approx(value, ratio):
			ratio = value
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if disabled: return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				_move(event.position.x)
			elif dragging:
				dragging = false
				_move(event.position.x)
				released.emit(ratio)
				queue_redraw()
			accept_event()
		elif event is InputEventMouseMotion and dragging:
			_move(event.position.x)
			accept_event()

	func _move(x: float) -> void:
		set_ratio((x - INSET) / maxf(1.0, size.x - 2.0 * INSET))
		if dragging: preview.emit(ratio)

	func _draw() -> void:
		var y := size.y / 2.0
		var span := maxf(1.0, size.x - 2.0 * INSET)
		draw_style_box(_rail, Rect2(INSET, y - TRACK / 2.0, span, TRACK))
		if ratio > 0.0: draw_style_box(_fill, Rect2(INSET, y - TRACK / 2.0, span * ratio, TRACK))
		var at := Vector2(INSET + span * ratio, y)
		var radius := KNOB + (4.0 if dragging else 0.0)
		draw_circle(at, radius + 3.0, Color(_ink, 0.9))
		draw_circle(at, radius, _accent.lerp(Color.WHITE, 0.35))
		draw_circle(at, radius * 0.42, Color(_ink, 0.85))
