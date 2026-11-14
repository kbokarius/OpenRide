class_name LaneSmashTrackCard
extends Button
## A single canvas shader, clipped by the library; no per-card cameras or viewports.
##
##   LaneSmashTrackCard (1040 x 188, cut corners)
##   ├ AnimatedPreview: the track's own sky on the right, under a scrim for the text
##   ├ accent bar, number                               28 px from the left edge
##   ├ title / pattern · palette · sky / last and best   one 104 px text column
##   └ SELECTED badge                                    28 px from the right edge
const SIZE := Vector2(1040, 188)
const PAD := 28.0
const TEXT_X := 104.0
var preview_clip: Control
var preview: ColorRect
var score_label: Label
var selected_label: Label
var accent: Color
var preview_distance := 0.0
var reduced_motion := false
var _selected := false
var _hovered := false
var _material: ShaderMaterial
var _look: LaneSmashMenuTheme

func configure(row: Dictionary, index: int, look: GameTheme, action: Callable) -> void:
	_look = LaneSmashMenuTheme.shared()
	name = "Track_%02d" % (index + 1)
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	pressed.connect(action)
	accent = Color(NeonWorlds.world(row.theme).accent)
	var vivid := LaneSmashLook.vivid(accent)
	preview_distance = index * 31.0
	_material = ShaderMaterial.new()
	_material.shader = load("res://games/neon_vector/track_preview.gdshader")
	var colors := LaneSmashEnvironment.palette(accent)
	_material.set_shader_parameter("primary", colors[0])
	_material.set_shader_parameter("secondary", colors[1])
	_material.set_shader_parameter("accent", accent)
	_material.set_shader_parameter("style", maxi(0, LaneSmashEnvironment.TITLES.keys().find(row.background)))
	_material.set_shader_parameter("preview_m", preview_distance)
	preview = ColorRect.new()
	preview.name = "AnimatedPreview"
	preview.material = _material
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = 2
	preview.offset_top = 2
	preview.offset_right = -2
	preview.offset_bottom = -2
	resized.connect(_fit_preview)
	var stripe := ColorRect.new()
	stripe.color = vivid
	stripe.position = Vector2(2, 30)
	stripe.size = Vector2(5, SIZE.y - 60)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stripe)
	var number := look.label("%02d" % (index + 1), LaneSmashMenuTheme.LABEL, vivid)
	number.add_theme_font_override("font", _look.tabular_font())
	number.position = Vector2(PAD + 4, 24)
	add_child(number)
	var title := look.label(str(row.title), LaneSmashMenuTheme.HEADING, LaneSmashMenuTheme.TEXT)
	title.position = Vector2(TEXT_X, 18)
	add_child(title)
	var description := look.label("%s · %s" % [row.description, LaneSmashEnvironment.TITLES[row.background]], LaneSmashMenuTheme.LABEL, vivid.lerp(Color.WHITE, 0.35))
	description.position = Vector2(TEXT_X, 76)
	add_child(description)
	score_label = look.label("", LaneSmashMenuTheme.LABEL, LaneSmashMenuTheme.TEXT_MUTED)
	score_label.position = Vector2(TEXT_X, 124)
	add_child(score_label)
	selected_label = look.label("SELECTED", LaneSmashMenuTheme.LABEL, LaneSmashMenuTheme.TEXT)
	selected_label.add_theme_font_override("font", _look.caps_font())
	selected_label.add_theme_stylebox_override("normal", _look.badge_style(Color(0.02, 0.05, 0.09, 0.82)))
	add_child(selected_label)
	selected_label.resized.connect(_place_badge)
	mouse_entered.connect(func(): _hovered = true; _restyle())
	mouse_exited.connect(func(): _hovered = false; _restyle())
	set_summary("No previous ride at this difficulty", false)
	_fit_preview()
	_place_badge()

func _fit_preview() -> void:
	_material.set_shader_parameter("aspect", maxf(1.0, size.x / maxf(1.0, size.y)))
	_material.set_shader_parameter("size_px", (size - Vector2(4, 4)).max(Vector2.ONE))
	_place_badge()

func _place_badge() -> void:
	if selected_label: selected_label.position = Vector2(maxf(size.x, SIZE.x) - selected_label.size.x - PAD, 22)

func set_summary(summary: String, selected: bool) -> void:
	score_label.text = summary
	_selected = selected
	selected_label.visible = selected
	_material.set_shader_parameter("selected", 1.0 if selected else 0.0)
	_restyle()

func _restyle() -> void:
	var vivid := LaneSmashLook.vivid(accent)
	var style := _look._shape(Color("0a1420"), Color(vivid, 1.0 if _selected else 0.7 if _hovered else 0.32), 2)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, style)

func _process(delta: float) -> void:
	# Only the handful of cards inside the scroll viewport need uniform updates.
	if not is_visible_in_tree() or not is_instance_valid(preview_clip) or not preview_clip.get_global_rect().intersects(get_global_rect()): return
	if reduced_motion: return
	preview_distance += delta * 5.0
	_material.set_shader_parameter("preview_m", preview_distance)
	var jukebox := LaneSmashLook.jukebox()
	if jukebox != null:
		_material.set_shader_parameter("music", Vector4(jukebox.calm_bass, jukebox.calm_mid, jukebox.calm_treble, jukebox.pulse))
		_material.set_shader_parameter("swirl", jukebox.flow)
