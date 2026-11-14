class_name LaneSmashAudioControls
extends Button
## A compact in-ride audio menu. Opening it never changes the ride clock or pause state.
##
##   Audio (Button, in the HUD's button row)
##   └ AudioPanel (PanelContainer, drops below the button, right-aligned to the HUD margin)
##     └ Margin › VBox
##       ├ Header: "AUDIO", Done
##       ├ Option_music (On / Off)
##       ├ MusicPanel (now playing, track picker, seek slider)
##       ├ Option_sfx (On / Off)
##       └ error line (only after a failed save)

const PANEL_WIDTH := 820.0
const PADDING := 20
const ROW_HEIGHT := 76.0
const SEPARATION := 12

var panel: PanelContainer
var rows: Dictionary = {}
var music_panel: LaneSmashMusicPanel
var info: GameInfo
var rider_id := "guest"
var look := LaneSmashMenuTheme.new()
var error_label: Label

func _ready() -> void:
	name = "LaneSmashAudio"
	text = "Audio"
	custom_minimum_size = Vector2(160, 86)
	look.style_button(self, GameTheme.SECONDARY)
	add_theme_font_size_override("font_size", 34)
	pressed.connect(func():
		LaneSmashSound.ui("tap")
		panel.visible = not panel.visible
		if panel.visible:
			_refresh()
			music_panel.refresh()
			panel.position = Vector2(1920 - HudTheme.MARGIN - global_position.x - PANEL_WIDTH, size.y + 16))
	panel = PanelContainer.new()
	panel.name = "AudioPanel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.z_index = 50
	var panel_style := look.panel_style(Color("101f2d"))
	for side in ["left", "right", "top", "bottom"]: panel_style.set("content_margin_" + side, 0.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, PADDING)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := look.label("AUDIO", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := look.button("Done", _close, GameTheme.SECONDARY)
	close.custom_minimum_size = Vector2(150, 72)
	close.add_theme_font_size_override("font_size", 30)
	header.add_child(close)
	var inner := PANEL_WIDTH - 2 * PADDING
	_add_row(box, "music", inner)
	music_panel = LaneSmashMusicPanel.new(look, inner)
	box.add_child(music_panel)
	_add_row(box, "sfx", inner)
	error_label = look.label("", 26, GameTheme.MUTED)
	error_label.visible = false
	box.add_child(error_label)
	panel.hide()
	AudioDirector.user_audio_changed.connect(_refresh)


## An On/Off row at the panel's compact height (the hub's rows are 120 px tall).
func _add_row(box: VBoxContainer, key: String, width: float) -> void:
	var row := OptionRow.new(info.option_spec(key), GameOptions.get_value(info, key, rider_id), width, look)
	row.custom_minimum_size.y = ROW_HEIGHT
	(row.get_node("Label") as Control).custom_minimum_size.y = ROW_HEIGHT
	row.segmented.animate_selection = false
	for button in row.segmented.buttons: button.custom_minimum_size.y = ROW_HEIGHT
	row.changed.connect(_change)
	box.add_child(row)
	rows[key] = row

func _close() -> void:
	LaneSmashSound.ui("tap")
	panel.hide()

func _change(key: String, value: String) -> void:
	var saved := GameOptions.set_value(info, key, value, rider_id)
	error_label.text = "Could not save. Please try again." if not saved else ""
	error_label.visible = not saved
	_refresh()
	LaneSmashSound.ui("tap")

func _refresh() -> void:
	for key in rows:
		var value := GameOptions.get_value(info, key, rider_id)
		rows[key].value = value
		rows[key].segmented.show_value(value)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(panel) or not panel.visible: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		panel.hide()
		get_viewport().set_input_as_handled()
	elif (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		var at: Vector2 = get_global_mouse_position() if event is InputEventMouseButton else get_global_transform_with_canvas().affine_inverse() * event.position + global_position
		if not panel.get_global_rect().has_point(at) and not get_global_rect().has_point(at): panel.hide()
