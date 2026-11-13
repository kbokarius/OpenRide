class_name LaneSmashTrackCard
extends Button
## A single canvas shader, clipped by the library; no per-card cameras or viewports.
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

func configure(row: Dictionary, index: int, look: GameTheme, action: Callable) -> void:
	custom_minimum_size = Vector2(1016, 188)
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	pressed.connect(action)
	accent = Color(NeonWorlds.world(row.theme).accent)
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
	preview.offset_left = 3
	preview.offset_top = 3
	preview.offset_right = -3
	preview.offset_bottom = -3
	resized.connect(func(): _material.set_shader_parameter("aspect", maxf(1.0, size.x / maxf(1.0, size.y))))
	var stripe := ColorRect.new()
	stripe.color = accent
	stripe.position = Vector2(3, 22)
	stripe.size = Vector2(4, 144)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stripe)
	var number := look.label("%02d" % (index + 1), 32, accent)
	number.position = Vector2(28, 24)
	add_child(number)
	var title := look.label(str(row.title), 44, Color("f1f6fb"))
	title.position = Vector2(88, 18)
	add_child(title)
	var description := look.label("%s · %s" % [row.description, LaneSmashEnvironment.TITLES[row.background]], 32, accent.lightened(0.25))
	description.position = Vector2(88, 76)
	add_child(description)
	score_label = look.label("", 32, Color("c2cfdb"))
	score_label.position = Vector2(88, 125)
	add_child(score_label)
	selected_label = look.label("SELECTED", 32, Color("e5f8ff"))
	selected_label.position = Vector2(816, 24)
	selected_label.add_theme_stylebox_override("normal", _badge())
	add_child(selected_label)
	mouse_entered.connect(func(): _hovered = true; _restyle())
	mouse_exited.connect(func(): _hovered = false; _restyle())
	set_summary("No previous ride at this difficulty", false)

func _badge() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("112430")
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func set_summary(summary: String, selected: bool) -> void:
	score_label.text = summary
	_selected = selected
	selected_label.visible = selected
	_material.set_shader_parameter("selected", 1.0 if selected else 0.0)
	_restyle()

func _restyle() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0d1824")
	style.border_color = Color(accent, 1.0 if _selected else 0.75 if _hovered else 0.4)
	style.set_border_width_all(3 if _selected else 2)
	style.set_corner_radius_all(10)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, style)

func _process(delta: float) -> void:
	# Only the handful of cards inside the scroll viewport need uniform updates.
	if not is_visible_in_tree() or not is_instance_valid(preview_clip) or not preview_clip.get_global_rect().intersects(get_global_rect()): return
	if reduced_motion: return
	preview_distance += delta * 5.0
	_material.set_shader_parameter("preview_m", preview_distance)
