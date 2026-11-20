class_name NeonTrack
extends Node2D
signal section_finished(kind: String)
signal blast_resolved(hit: bool, points: int)
signal gun_hit(points: int)  ## one machine-gun round landed on the rider
## A 3D space course under the existing, full-resolution 2D HUD.
## Geometry travels in course coordinates, independent of scoring and display frame rate.
##
## Layout (1920x1080 stage, 8 px grid, 40 px HUD margin):
##   top left     ride panel (shared HUD), then this node's track chip under it
##   bottom       the six-lane dock, centred; under it the ride progress line and one hint
## Full-width pieces (the 3D view, the dock's scrim) cover the whole window, past the stage.

const PREVIEW_MS := 14000.0
const GOLD := LaneSmashLook.GOLD
const HOLD := LaneSmashLook.MINT
const CHARGE := LaneSmashLook.VIOLET
const WHITE := LaneSmashMenuTheme.TEXT
const MUTED := LaneSmashMenuTheme.TEXT_MUTED
const MARGIN := 40.0
## The lane dock: six equal cells, centred on the stage.
const CELL := Vector2(236, 76)
const CELL_GAP := 28.0
const DOCK_TOP := 928.0
const PROGRESS_Y := 1050.0
const CHIP_AT := Vector2(MARGIN, 196)
## 3D view resolution as a share of the screen, by tier. The tablet is fill-rate bound
## (docs/GAMES.md), so fewer pixels is the lever that matters; the HUD always stays sharp.
const TIERS := ["high", "balanced", "performance"]
const VIEW_SCALE := {"high": 1.0, "balanced": 0.8, "performance": 0.66}
## The sky's own shader is the heaviest in the picture and its image is smooth, so below the
## high tier it is drawn at half this size in each direction (a quarter of the pixels).
const SKY_SCALE := {"high": 1.0, "balanced": 0.5, "performance": 0.5}
## Where the bloom comes from: the engine's own (many passes over a high-range buffer), a
## small two-pass copy added in the lens pass (a fraction of the cost), or nowhere.
const BLOOM := {"high": "engine", "balanced": "lens", "performance": "none"}
## The picture's grade when the engine is not applying one: contrast, saturation.
const GRADE := Vector2(1.07, 1.14)
const LENS_BLOOM_STRENGTH := 1.4
## How far the bloom spreads: the blur reads this many of its own pixels apart.
const LENS_BLOOM_SPREAD := 1.5

var rules: NeonRules
var world_id := "arctic"
var trail_id := "ion"
var visual_lane := 2.0
var steering := LaneSmashSteering.new()
var ghost_lane := -1.0
var ghost_delta := 0
var ghost_distance := -1.0
var ghost_gap := 0.0
var ghost_cadence := 80.0
var ghost_visible := false
var ghost_opacity := 1.0
var ghost_notice := ""
var ghost_different_version := false
var _text_second := -1
var _speed_text := ""
var _ghost_text := ""
var motion := 0.0
var reduced_motion := false
var preview_time := -1
var space: NeonSpace
var view: SubViewport
var quality := ""
var _image: TextureRect
var _scrim: TextureRect
var _lens: ShaderMaterial
var _bloom_views: Array[SubViewport] = []   ## shrink-and-keep-bright, then blur
var _bloom_materials: Array[ShaderMaterial] = []
var _look: LaneSmashMenuTheme
var _cell_styles: Array[StyleBoxFlat] = []
var _chip_style: StyleBoxFlat
var _style_world := ""
var _font: Font
var _caps: Font
var _digits: Font
var _completion_cursor := 0
var _completion_age := 10.0
var _completion_text := ""
var _completion_anchor := Vector3.ZERO
var _completion_up := Vector3.UP
var _completion_kind := "cruise"
var _danger := 0.0
var music_levels := Vector4.ZERO  ## eased bass, mids, treble and kick, as sent to the 3D view
var bomb_gauge := LaneSmashBarrageGauge.new()
var gauge := LaneSmashCadenceGauge.new()        ## the cadence gauge beside the bike
var celebration := LaneSmashCelebration.new()   ## the burst of light when a power burst is finished
## Where the celebration appears: the middle of the play area, clear of every panel.
const CELEBRATION_AT := Vector2(960, 500)
## The lowest the cadence gauge may reach: just above the lane dock. (The showcase raises it
## to keep the gauge clear of its captions.)
var gauge_floor := DOCK_TOP - 28.0
var _meter := LaneSmashSpectrum.blank()  ## the chip's small spectrum meter
var _music_on := false
const METER_SIZE := Vector2(61, 26)
var completed_sections := {"cruise": 0, "hold": 0, "burst": 0}
var _intro_alpha := 0.0:
	set(value):
		_intro_alpha = value
		# Redraw even while waiting for the first sensor batch.
		queue_redraw()


func _ready() -> void:
	_look = LaneSmashMenuTheme.shared()
	_font = _look.font()
	_caps = _look.caps_font()
	_digits = _look.tabular_font()
	view = SubViewport.new()
	view.name = "SpaceViewport"
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.audio_listener_enable_3d = false
	view.world_3d = World3D.new()
	add_child(view)
	space = NeonSpace.new()
	view.add_child(space)
	_image = TextureRect.new()
	_image.texture = view.get_texture()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.show_behind_parent = true
	_lens = ShaderMaterial.new()
	_lens.shader = preload("res://games/neon_vector/ride_view.gdshader")
	_image.material = _lens
	add_child(_image)
	# The lens bloom's two small passes. They are made after the 3D view, in the order they
	# feed each other: the engine draws sibling views in that order, so neither lags a frame.
	var feed: Texture2D = view.get_texture()
	for pass_name in ["BloomDown", "BloomBlur"]:
		var pass_view := SubViewport.new()
		pass_view.name = pass_name
		pass_view.disable_3d = true
		pass_view.transparent_bg = false
		pass_view.gui_disable_input = true
		pass_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(pass_view)
		var material := ShaderMaterial.new()
		material.shader = preload("res://games/neon_vector/bloom_down.gdshader") if pass_name == "BloomDown" else preload("res://games/neon_vector/bloom_blur.gdshader")
		material.set_shader_parameter("source", feed)
		var card := ColorRect.new()
		card.material = material
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pass_view.add_child(card)
		_bloom_views.append(pass_view)
		_bloom_materials.append(material)
		feed = pass_view.get_texture()
	_lens.set_shader_parameter("bloom_tex", feed)
	Stage.bleed(_image)
	# One smooth scrim under the dock, the full width of the window.
	_scrim = LaneSmashMenuTheme.gradient(Color(0.016, 0.026, 0.052, 0.0), Color(0.016, 0.026, 0.052, 0.92))
	_scrim.show_behind_parent = true
	add_child(_scrim)
	Stage.changed.connect(_fit)
	apply_quality(default_quality())
	_fit()
	create_tween().tween_property(self, "_intro_alpha", 1.0, 0.7).set_trans(Tween.TRANS_SINE)


## The tier a ride starts on: the phone-class GPU in the bike never gets MSAA (it halves the
## frame rate there and has rendered black in a SubViewport; docs/GAMES.md).
static func default_quality() -> String:
	return "balanced" if OS.has_feature("mobile") else "high"


## The 3D view's size as a share of the screen. The high tier is the full screen on a
## desktop; on the bike it stops a little short of that.
static func view_scale(tier: String) -> float:
	return 0.9 if tier == "high" and OS.has_feature("mobile") else float(VIEW_SCALE.get(tier, 0.8))


## Sets the 3D view's cost: resolution, anti-aliasing, bloom, and the optional set dressing.
func apply_quality(tier: String) -> void:
	if tier not in TIERS: tier = default_quality()
	if tier == quality: return
	quality = tier
	view.msaa_3d = Viewport.MSAA_2X if tier == "high" and not OS.has_feature("mobile") else Viewport.MSAA_DISABLED
	var bloom: String = BLOOM[tier]
	space.set_quality(bloom == "engine", tier == "performance", bloom != "none")
	_lens.set_shader_parameter("aberration", 1.0 if tier == "high" else 0.0)
	_lens.set_shader_parameter("smoothing", 1.0)  # edges are smoothed on every tier
	_lens.set_shader_parameter("bloom", LENS_BLOOM_STRENGTH if bloom == "lens" else 0.0)
	# The engine grades the picture itself when its bloom is on; otherwise the lens does.
	_lens.set_shader_parameter("grade", Vector2.ONE if bloom == "engine" else GRADE)
	for pass_view in _bloom_views:
		pass_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if bloom == "lens" else SubViewport.UPDATE_DISABLED
	_fit()


func _fit() -> void:
	if view == null or quality.is_empty(): return
	view.size = Stage.view_size(view_scale(quality)).max(Vector2i(320, 180))
	space.set_sky_size(view.size, float(SKY_SCALE[quality]))
	# The bloom works on a quarter of the view's width and height.
	var small := (view.size / 4).max(Vector2i(80, 45))
	for pass_view in _bloom_views: pass_view.size = small
	_bloom_materials[0].set_shader_parameter("source_pixel", Vector2.ONE / Vector2(view.size))
	_bloom_materials[1].set_shader_parameter("step_uv", Vector2(LENS_BLOOM_SPREAD, LENS_BLOOM_SPREAD) / Vector2(small))
	var bleed := Stage.bleed_rect()
	_scrim.position = Vector2(bleed.position.x, bleed.end.y - 280.0)
	_scrim.size = Vector2(bleed.size.x, 280.0)
	queue_redraw()


func update_view(delta: float) -> void:
	if rules and rules._configured and space:
		var raw := float(rules.latest.get("resistance", NeonRules.TIERS[rules.tier]))
		steering.update(delta, raw, rules.tier, LaneSmashSteering.target_for(rules))
		visual_lane = steering.lane
		space.set_lane_guidance(steering.weights)
		motion = rules.elapsed_ms / 1000.0
		var jukebox := LaneSmashLook.jukebox()
		# The kick as a soft swell (`Jukebox.pulse`), never the raw beat flag.
		var beat := float(jukebox.pulse) if jukebox != null and not reduced_motion else 0.0
		space.ghost_distance = ghost_distance
		space.ghost_cadence = ghost_cadence
		space.ghost_opacity = ghost_opacity
		space.reduced_motion = reduced_motion
		space.music_pulse = beat
		# Colour and the seam pulses read the eased levels; Reduced motion keeps a third of the
		# colour response and none of the kick.
		music_levels = LaneSmashLook.music() * (0.3 if reduced_motion else 1.0)
		if reduced_motion: music_levels.w = 0.0
		space.music = music_levels
		_music_on = jukebox != null and bool(jukebox.is_playing())
		_meter = LaneSmashSpectrum.eased(_meter, delta)
		if jukebox != null:
			space.music_bands = jukebox.bands
			space.music_beats = int(jukebox.beat_count)
		space.set_world(world_id)
		space.update_view(rules, delta, visual_lane, ghost_lane, ghost_visible, trail_id)
		space.set_edge_warning(steering.edge_weights)
		_update_completions(delta)
		celebration.update(delta)
		# The cadence gauge sits beside the motorcycle, inside the play area.
		var bike := Stage.from_view(space.camera.unproject_position(space.rider.global_position + space.rider.global_basis.y * 0.9), Vector2(view.size))
		var gauge_bounds := Rect2(MARGIN + 8.0, 340.0, HudTheme.W - 2.0 * MARGIN - 16.0, gauge_floor - 340.0)
		gauge.update(delta, rules.cadence_target() if rules.pause_reason.is_empty() else {}, bike, gauge_bounds)
		bomb_gauge.update(delta, LaneSmashBarrageGauge.read(rules), bike, gauge_bounds)
		_danger = maxf(0.0, _danger - delta * 2.6)
		_lens.set_shader_parameter("danger", 0.0 if reduced_motion else _danger)
		_lens.set_shader_parameter("beat", beat * 0.5)
		_lens.set_shader_parameter("speed", clampf(rules.speed_kph / 60.0, 0.0, 1.0))
		var second := rules.elapsed_ms / 1000
		if second != _text_second:
			_text_second = second
			# Speed and distances are shown as the picture has them: the world is drawn STRETCH
			# to one, so the bike really does cover that ground on screen.
			var scale := NeonSpace.STRETCH
			_speed_text = "%.0f mph  ·  %.2f mi" % [rules.speed_kph * scale / 1.609344, rules.road_distance() * scale / 1609.344]
			var position_text := "%.0f ft ahead" % (ghost_gap * scale * 3.28084) if ghost_gap > 1.4 else ("%.0f ft behind" % (-ghost_gap * scale * 3.28084) if ghost_gap < -1.4 else "alongside")
			_ghost_text = "%s  %s  ·  %+d PTS" % ["PRIOR BEST" if ghost_different_version else "BEST RIDE", position_text, ghost_delta] if ghost_visible else "TURN RESISTANCE TO CHANGE LANES"
			if not ghost_notice.is_empty(): _ghost_text = ghost_notice
	queue_redraw()


func _draw() -> void:
	if _font == null or rules == null:
		return
	var world := NeonWorlds.world(world_id)
	var accent := LaneSmashLook.vivid(Color(world.accent))
	_styles(accent)
	# The interface's accent lines breathe with the music: toward the companion hue with the
	# mids and treble, brighter with the bass and each kick. Text never changes colour.
	var live := LaneSmashLook.pulsed(accent, music_levels)
	_chip_style.border_color = Color(live, 0.34 + 0.4 * music_levels.w + 0.2 * music_levels.x)
	_cell_styles[1].border_color = live
	_chip(str(rules.course.get("title", world.title)), live)
	if rules.course.is_empty():
		return
	_dock(accent)
	# One local gauge at a time; let the outgoing panel finish its short fade.
	if bomb_gauge.alpha > 0.001: bomb_gauge.paint(self, _caps, _digits, _look)
	else: gauge.paint(self, _caps, _digits, _look)
	steering.paint(self, _caps, _look, reduced_motion)
	_popup()
	celebration.paint(self, CELEBRATION_AT, _caps, _digits, reduced_motion)
	var progress := clampf(float(rules.elapsed_ms) / float(rules.course.durationMs), 0.0, 1.0)
	var right := HudTheme.W - MARGIN
	draw_rect(Rect2(MARGIN, PROGRESS_Y, right - MARGIN, 4), Color(accent, 0.16))
	draw_rect(Rect2(MARGIN, PROGRESS_Y, (right - MARGIN) * progress, 4), live)
	draw_rect(Rect2(MARGIN + (right - MARGIN) * progress - 2, PROGRESS_Y - 4, 4, 12), WHITE)
	var caption := "COOL DOWN" if rules.cooldown else "RIDE PROGRESS"
	if not rules.distance_based:
		for phase: Dictionary in rules.course.phases:
			if rules.elapsed_ms >= int(phase.startMs) and rules.elapsed_ms < int(phase.endMs):
				caption = str(phase.name).to_upper()
				break
	draw_string(_caps, Vector2(MARGIN, PROGRESS_Y - 12), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, MUTED)
	var hint_width := _caps.get_string_size(_ghost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(_caps, Vector2(right - hint_width, PROGRESS_Y - 12), _ghost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, WHITE if ghost_visible else MUTED)


func _styles(accent: Color) -> void:
	if _style_world == world_id: return
	_style_world = world_id
	_cell_styles.clear()
	for selected in [false, true]:
		var style := _look._shape(Color(accent.darkened(0.55), 0.92) if selected else Color(0.035, 0.055, 0.10, 0.88),
			Color(accent, 1.0) if selected else Color(accent, 0.26), 2 if selected else 1, 12)
		_cell_styles.append(style)
	_chip_style = _look._shape(LaneSmashMenuTheme.SURFACE, Color(accent, 0.34), 1)
	_chip_style.border_width_left = 3


## The track chip under the ride panel: the track's name, then speed and distance.
func _chip(title: String, live: Color) -> void:
	var name_text := title.to_upper()
	var width := _caps.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	# Room beside the title for the soundtrack's meter while music is playing.
	if _music_on: width += METER_SIZE.x + 20.0
	if rules.distance_based:
		width = maxf(width, _digits.get_string_size(_speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x)
	var size := Vector2(maxf(300.0, ceilf(width) + 51.0), 100.0 if rules.distance_based else 60.0)
	draw_style_box(_chip_style, Rect2(CHIP_AT, size))
	draw_string(_caps, CHIP_AT + Vector2(27, 38), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(MUTED, _intro_alpha))
	if _music_on:
		LaneSmashSpectrum.paint(self, Rect2(CHIP_AT + Vector2(size.x - 24.0 - METER_SIZE.x, 14), METER_SIZE), _meter, live, LaneSmashLook.companion(live), _intro_alpha)
	if rules.distance_based:
		draw_string(_digits, CHIP_AT + Vector2(27, 82), _speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, WHITE)


## Six lane cells: the lane's number, then its resistance range. The rider's lane is filled and
## outlined; the lane the current section wants carries that section's colour along its top.
func _dock(accent: Color) -> void:
	var total := CELL.x * 6.0 + CELL_GAP * 5.0
	var left := (HudTheme.W - total) * 0.5
	var event := rules.current_event()
	var target_lane := LaneSmashSteering.target_for(rules)
	var target_color := GOLD
	if rules.barrage.active:
		target_lane = rules.barrage.target_lane()
		target_color = LaneSmashLook.PLASMA
	elif not event.is_empty():
		target_lane = int(event.laneIndex)
		target_color = GOLD if event.type in ["cruise", "pickup"] else (HOLD if event.type == "hold" else CHARGE)
	for lane in 6:
		var band := NeonRules.band(lane, rules.tier)
		var rect := Rect2(left + lane * (CELL.x + CELL_GAP), DOCK_TOP, CELL.x, CELL.y)
		var selected := lane == rules.selected_lane
		draw_style_box(_cell_styles[1 if selected else 0], rect)
		if lane == target_lane:
			draw_rect(Rect2(rect.position.x + 14, rect.position.y - 8, rect.size.x - 28, 5), target_color)
		var number := str(lane + 1)
		draw_string(_digits, rect.position + Vector2(22, 52), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, accent if selected else Color(MUTED, 0.75))
		draw_rect(Rect2(rect.position.x + 58, rect.position.y + 20, 2, rect.size.y - 40), Color(accent, 0.5 if selected else 0.22))
		var range_text := "%d–%d" % [band.x, band.y]
		var range_width := _digits.get_string_size(range_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
		draw_string(_digits, Vector2(rect.position.x + 60 + (rect.size.x - 60 - range_width) * 0.5, rect.position.y + 52), range_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, WHITE if selected else MUTED)


## The floating points label of the latest section, mine or shot, kept inside the play area.
func _popup() -> void:
	if _completion_age >= 1.4: return
	var position_3d := _completion_anchor + _completion_up * minf(_completion_age, 1.0) * 1.2
	if space.camera.is_position_behind(position_3d): return
	var screen := Stage.from_view(space.camera.unproject_position(position_3d), Vector2(view.size))
	var alpha := smoothstep(0.0, 0.08, _completion_age) * (1.0 - smoothstep(0.65, 1.4, _completion_age))
	var color := LaneSmashLook.DANGER if _completion_kind == "bomb" else (HOLD if _completion_kind == "evade" else (GOLD if _completion_kind == "cruise" else (HOLD if _completion_kind == "hold" else CHARGE)))
	var size := 58 if _completion_kind in ["bomb", "evade"] else 52
	var width := _digits.get_string_size(_completion_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(clampf(screen.x - width / 2, MARGIN + 20, HudTheme.W - MARGIN - 20 - width), clampf(screen.y, 250.0, DOCK_TOP - 40.0))
	draw_string_outline(_digits, at, _completion_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color(0.01, 0.02, 0.045, alpha * 0.9))
	draw_string(_digits, at, _completion_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color.lerp(Color.WHITE, 0.25), alpha))


func _update_completions(delta: float) -> void:
	_completion_age += delta
	while _completion_cursor < rules.events.size() and int(rules.events[_completion_cursor].endMs) <= rules.road_time_ms():
		var event: Dictionary = rules.events[_completion_cursor]
		var points := int(rules.event_states[_completion_cursor].scoreUnits) / NeonRules.UNIT
		_completion_cursor += 1
		if points <= 0 or rules.barrage.active or rules.event_states[_completion_cursor - 1].get("skipped", false): continue
		_completion_kind = str(event.type)
		_completion_text = "+%s" % HudTheme.grouped(points)
		_completion_age = 0.0
		if _completion_kind == "burst":
			# A finished power burst gets the big celebration instead of the small number.
			var state: Dictionary = rules.event_states[_completion_cursor - 1]
			var reference := int(state.get("possibleBaseUnits", 0))
			celebration.start(points, float(state.scoreUnits) / reference if reference > 0 else 1.0)
			_completion_age = 10.0
		section_finished.emit(_completion_kind)
		completed_sections[_completion_kind] = int(completed_sections.get(_completion_kind, 0)) + 1
		_completion_anchor = space.section_completed(_completion_kind, int(event.laneIndex), int(event.endMs))
		_completion_up = space.road_basis(int(event.endMs) / 1000.0 * space._unit_speed).y

	var hit := space.bombs.take_feedback(rules)
	if not hit.is_empty():
		_completion_kind = "bomb"
		_completion_text = "−%s" % HudTheme.grouped(int(hit.points)) if int(hit.points) > 0 else "BOMB HIT"
		_completion_age = 0.0
		_danger = 1.0
		blast_resolved.emit(true, -int(hit.points))
		_completion_anchor = hit.anchor
		_completion_up = hit.up

	var round := space.gunfire_view.take_feedback()
	if not round.is_empty():
		_completion_kind = "bomb"
		_completion_text = "−%d" % int(round.points)
		_completion_age = 0.0
		_danger = maxf(_danger, 0.55)
		gun_hit.emit(int(round.points))
		_completion_anchor = round.anchor
		_completion_up = round.up

	var strike := space.barrage_view.take_feedback()
	if not strike.is_empty():
		_completion_kind = "bomb" if bool(strike.hit) else "evade"
		_completion_text = ("−%s" % HudTheme.grouped(absi(int(strike.points))) if int(strike.points) < 0 else "BOMB HIT") if bool(strike.hit) else ("PASSED +%s" % HudTheme.grouped(int(strike.points)) if int(strike.points) > 0 else "BLAST AVOIDED")
		_completion_age = 0.0
		if bool(strike.hit): _danger = 1.0
		blast_resolved.emit(bool(strike.hit), int(strike.points))
		_completion_anchor = strike.anchor
		_completion_up = strike.up
