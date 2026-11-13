class_name NeonTrack
extends Node2D
## A 3D space course under the existing, full-resolution 2D HUD.
## Geometry travels in course coordinates, independent of scoring and display frame rate.

const PREVIEW_MS := 14000.0
const GOLD := Color("ffd369")
const HOLD := Color("6fffd0")
const CHARGE := Color("c6a0ff")
const WHITE := Color("f0f4ff")
const MUTED := Color("b8c6e0")

var rules: NeonRules
var world_id := "arctic"
var trail_id := "ion"
var visual_lane := 2.0
var ghost_lane := -1.0
var ghost_delta := 0
var ghost_distance := -1.0
var ghost_gap := 0.0
var ghost_cadence := 80.0
var ghost_visible := false
var _text_second := -1
var _speed_text := ""
var _ghost_text := ""
var motion := 0.0
var reduced_motion := false
var preview_time := -1
var space: NeonSpace
var view: SubViewport
var _band_styles: Array[StyleBoxFlat] = []
var _band_world := ""
var _font: Font
var _completion_cursor := 0
var _completion_age := 10.0
var _completion_text := ""
var _completion_kind := "cruise"
var completed_sections := {"cruise": 0, "hold": 0, "burst": 0}
var _intro_alpha := 0.0:
	set(value):
		_intro_alpha = value
		# Redraw even while waiting for the first sensor batch.
		queue_redraw()


func _ready() -> void:
	_font = GameTheme.house().font()
	view = SubViewport.new()
	view.name = "SpaceViewport"
	view.size = Vector2i(1600, 900)
	view.msaa_3d = Viewport.MSAA_2X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.audio_listener_enable_3d = false
	view.world_3d = World3D.new()
	add_child(view)
	space = NeonSpace.new()
	view.add_child(space)
	var image := TextureRect.new()
	image.texture = view.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.show_behind_parent = true
	add_child(image)
	Stage.bleed(image)
	Stage.changed.connect(queue_redraw)
	create_tween().tween_property(self, "_intro_alpha", 1.0, 0.7).set_trans(Tween.TRANS_SINE)


func update_view(delta: float) -> void:
	if rules and space:
		var raw := float(rules.latest.get("resistance", NeonRules.TIERS[rules.tier]))
		var lane := clampf(floorf((raw - NeonRules.TIERS[rules.tier]) / 7.0), 0.0, 5.0)
		visual_lane = lerpf(visual_lane, lane, 1.0 - exp(-delta * 12.0)) if delta > 0 else lane
		motion = rules.elapsed_ms / 1000.0
		space.ghost_distance = ghost_distance
		space.ghost_cadence = ghost_cadence
		space.reduced_motion = reduced_motion
		space.set_world(world_id)
		space.update_view(rules, delta, visual_lane, ghost_lane, ghost_visible, trail_id)
		_update_completions(delta)
		var second := rules.elapsed_ms / 1000
		if second != _text_second:
			_text_second = second
			_speed_text = "%.1f mph   /   %.2f mi" % [rules.speed_kph / 1.609344, rules.road_distance() / 1609.344]
			var position_text := "%.0f ft ahead" % (ghost_gap * 3.28084) if ghost_gap > 1.4 else ("%.0f ft behind" % (-ghost_gap * 3.28084) if ghost_gap < -1.4 else "alongside")
			_ghost_text = "BEST RIDE  %s  ·  %+d PTS" % [position_text, ghost_delta] if ghost_visible else "TURN RESISTANCE TO CHANGE LANES"
	queue_redraw()


func _draw() -> void:
	if _font == null or rules == null:
		return
	var world := NeonWorlds.world(world_id)
	var accent := Color(world.accent)
	# A quiet bottom dock gives the lane numbers breathing room below the road.
	for i in 14:
		draw_rect(Rect2(0, 890 + i * 14, 1920, 15), Color(0.025, 0.035, 0.08, minf(0.9, i * 0.065)))
	_bands(accent)
	_text("Lane Smash", Vector2(52, 306), 34, Color(WHITE, _intro_alpha))
	_text(str(rules.course.get("title", world.title)), Vector2(52, 350), 30, Color(MUTED, _intro_alpha))
	if rules.distance_based:
		_text(_speed_text, Vector2(52, 395), 32, MUTED)

	if rules.course.is_empty():
		return
	if _completion_age < 2.0:
		var alpha := smoothstep(0.0, 0.12, _completion_age) * (1.0 - smoothstep(1.2, 2.0, _completion_age))
		var color := GOLD if _completion_kind == "cruise" else (HOLD if _completion_kind == "hold" else CHARGE)
		var width := _font.get_string_size(_completion_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		var y := 410.0 - minf(_completion_age, 1.5) * 20.0
		draw_rect(Rect2(960 - width / 2 - 24, y - 46, width + 48, 66), Color(0.025, 0.035, 0.06, 0.8 * alpha))
		_text(_completion_text, Vector2(960 - width / 2, y), 40, Color(color, alpha))
	var progress := clampf(float(rules.elapsed_ms) / float(rules.course.durationMs), 0.0, 1.0)
	draw_line(Vector2(52, 1055), Vector2(1868, 1055), Color(accent, 0.15), 5.0)
	draw_line(Vector2(52, 1055), Vector2(52 + 1816 * progress, 1055), accent, 5.0)
	if rules.distance_based:
		_text("RIDE PROGRESS", Vector2(52, 1040), 28, MUTED)
	else:
		for phase: Dictionary in rules.course.phases:
			if rules.elapsed_ms >= int(phase.startMs) and rules.elapsed_ms < int(phase.endMs):
				_text(str(phase.name).to_upper(), Vector2(52, 1040), 28, MUTED)
				break
	_text(_ghost_text, Vector2(1160, 1040), 28, WHITE if ghost_visible else MUTED)


func _bands(accent: Color) -> void:
	if _band_world != world_id:
		_band_world = world_id
		_band_styles.clear()
		for selected in [false, true]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(accent, 0.18) if selected else Color("101a32")
			style.border_color = Color(accent, 0.8) if selected else Color(accent, 0.2)
			style.set_border_width_all(2)
			style.set_corner_radius_all(6)
			_band_styles.append(style)
	for lane in 6:
		var band := NeonRules.band(lane, rules.tier)
		var x := 345.0 + lane * 246.0
		var selected := lane == rules.selected_lane
		var rect := Rect2(x - 105, 948, 210, 66)
		draw_style_box(_band_styles[1 if selected else 0], rect)
		_text("%d–%d" % [band.x, band.y], Vector2(x - 52, 994), 36, WHITE if selected else MUTED)
		_text(str(lane + 1), Vector2(x - 9, 931), 34, accent if selected else MUTED)


func _text(value: String, at: Vector2, size: int, color: Color) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _tutorial_help(accent: Color) -> void:
	if rules.course.get("courseId", "") != "tutorial":
		return
	var minute := rules.elapsed_ms / 60000
	var cards := [
		["01 / FIND YOUR LINE", "Turn resistance to steer.", "Gold bars earn points."],
		["02 / LOCK THE RHYTHM", "Follow the raised arrows.", "Stay in the rpm range."],
		["03 / RIDE THE CURVE", "Look ahead. Change smoothly.", "Every scoring lane counts."],
		["04 / POWER BURST", "Build your total output.", "More energy. More points."],
		["05 / KEEP THE FLOW", "Easy pedals to the finish.", "Try a longer course next."],
	]
	var card: Array = cards[clampi(minute, 0, 4)]
	var phase_time := fmod(rules.elapsed_ms / 1000.0, 60.0)
	var alpha := smoothstep(0.0, 0.8, phase_time) * (1.0 - smoothstep(57.0, 59.5, phase_time))
	_text(card[0], Vector2(52, 415), 30, Color(accent, alpha))
	for i in range(1, card.size()):
		_text(card[i], Vector2(52, 415 + i * 39), 28, Color(MUTED, alpha))


func _update_completions(delta: float) -> void:
	_completion_age += delta
	while _completion_cursor < rules.course.events.size() and int(rules.course.events[_completion_cursor].endMs) <= rules.road_time_ms():
		var event: Dictionary = rules.course.events[_completion_cursor]
		var points := int(rules.event_states[_completion_cursor].scoreUnits) / NeonRules.UNIT
		_completion_cursor += 1
		if points <= 0: continue
		_completion_kind = str(event.type)
		_completion_text = "%s  +%d" % [{"cruise": "SECTION COMPLETE", "hold": "CADENCE COMPLETE", "burst": "POWER BURST COMPLETE"}.get(_completion_kind, "SECTION COMPLETE"), points]
		_completion_age = 0.0
		completed_sections[_completion_kind] = int(completed_sections.get(_completion_kind, 0)) + 1
		space.section_completed(_completion_kind, int(event.laneIndex))
