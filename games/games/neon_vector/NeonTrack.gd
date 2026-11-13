class_name NeonTrack
extends Node2D
## Original 2D perspective art. Projection is cosmetic; rules never read a pixel position.
## Bounded geometry, no full-screen bloom/shadow passes or continuously allocated textures.

const HORIZON := 340.0
const HIT_Y := 880.0
const PREVIEW_MS := 8000.0
const GOLD := Color("ffdb73")
const HOLD := Color("9ce8c3")
const CHARGE := Color("cfacff")
const WHITE := Color("f0f4ff")
const MUTED := Color("b8c6e0")

var rules: NeonRules
var world_id := "city"
var trail_id := "ion"
var visual_lane := 2.0
var ghost_lane := -1.0
var ghost_delta := 0
var ghost_visible := false
var motion := 0.0
var reduced_motion := false
var preview_time := -1  # capture tool only: -1 follows live course
var _band_styles: Array[StyleBoxFlat] = []
var _band_world := ""
var _font: Font


func _ready() -> void:
	_font = GameTheme.display_font()
	Stage.changed.connect(queue_redraw)


func update_view(delta: float) -> void:
	if rules:
		var raw := float(rules.latest.get("resistance", NeonRules.TIERS[rules.tier]))
		var lane := clampf(floorf((raw - NeonRules.TIERS[rules.tier]) / 7.0), 0.0, 5.0)
		visual_lane = move_toward(visual_lane, lane, delta * 34.0)
		motion = rules.elapsed_ms / 1000.0
	queue_redraw()


static func project(lane_edge: float, ahead_ms: float) -> Vector2:
	var fraction := clampf(1.0 - ahead_ms / PREVIEW_MS, 0.0, 1.15)
	var depth := fraction * fraction
	return Vector2(960.0 + (lane_edge / 6.0 - 0.5) * (170.0 + 1300.0 * depth), HORIZON + (HIT_Y - HORIZON) * depth)


func _draw() -> void:
	if _font == null:
		return
	var world := NeonWorlds.world(world_id)
	var accent := Color(world.accent)
	var secondary := Color(world.second)
	var sky := Color(world.sky)
	var haze := Color(world.haze)
	var bleed := Stage.bleed_rect()
	# Broad vertical gradient without a post-processing framebuffer.
	for i in 60:
		var y := i * 18.0
		var mix := 0.65 * exp(-pow((y - 350.0) / 220.0, 2.0))
		draw_rect(Rect2(bleed.position.x, y, bleed.size.x, 19), sky.lerp(haze, mix))
	_stars(accent)
	_world(world_id, accent, secondary, sky)
	# Horizon fog lines and a quiet route signal at the vanishing point.
	for i in range(3, 0, -1):
		draw_line(Vector2(-200, HORIZON + 6 * i), Vector2(2120, HORIZON + 6 * i), Color(accent, 0.028 * (4 - i)), 9.0)
	draw_arc(Vector2(960, 322), 82, PI, TAU, 48, Color(accent, 0.22), 3.0, true)
	draw_arc(Vector2(960, 322), 94, PI + 0.28, TAU - 0.28, 48, Color(secondary, 0.15), 2.0, true)
	_road(accent, secondary)
	if rules:
		_events()
		_bands(accent)
		_tutorial_help(accent)
	if ghost_visible and ghost_lane >= 0:
		_rider(ghost_lane, -58.0, Color("d0c5ff"), true)
	_rider(visual_lane, 0.0, accent, false)
	# Nameplate and distance strip stay below shared Pause/End/metrics.
	_text("NEON VECTOR", Vector2(52, 327), 36, WHITE)
	_text(str(world.title).to_upper(), Vector2(52, 378), 34, MUTED)
	if rules and not rules.course.is_empty():
		var t := rules.elapsed_ms
		var progress := clampf(float(t) / float(rules.course.durationMs), 0.0, 1.0)
		draw_line(Vector2(52, 1040), Vector2(1868, 1040), Color(accent, 0.15), 5.0)
		draw_line(Vector2(52, 1040), Vector2(52 + 1816 * progress, 1040), accent, 5.0)
		for phase: Dictionary in rules.course.phases:
			if t >= int(phase.startMs) and t < int(phase.endMs):
				_text(str(phase.name).to_upper(), Vector2(52, 1017), 34, MUTED)
				break
		var label := "GHOST  %+d" % ghost_delta if ghost_visible else "TURN RESISTANCE TO CHANGE LANES"
		_text(label, Vector2(1120, 1017), 34, WHITE if ghost_visible else MUTED)


func _stars(accent: Color) -> void:
	for i in 68:
		var x := fposmod(i * 137.31 + 51.0, 2060.0) - 70.0
		var y := fposmod(i * 83.73 + 17.0, 285.0)
		var radius := 1.2 if i % 4 else 2.2
		draw_circle(Vector2(x, y), radius, Color(accent.lerp(WHITE, 0.5), 0.24 if i % 4 else 0.5))


func _world(id: String, accent: Color, secondary: Color, ink: Color) -> void:
	if id == "orbit":
		for i in range(12, 0, -1):
			draw_circle(Vector2(1440, 220), 120 + i * 3, Color(secondary, 0.012))
		draw_circle(Vector2(1440, 220), 119, ink.lerp(secondary, 0.25))
		draw_arc(Vector2(1440, 220), 121, 3.6, 6.2, 80, accent, 3.0, true)
		draw_set_transform(Vector2(1440, 220), -0.3, Vector2(1.65, 0.28))
		draw_arc(Vector2.ZERO, 130, 0, TAU, 96, Color(secondary, 0.6), 7.0, true)
		draw_set_transform(Vector2.ZERO)
		for side: int in [-1, 1]:
			var points := PackedVector2Array([Vector2(960 + side * 380, 330), Vector2(960 + side * 920, 110), Vector2(960 + side * 1100, 200), Vector2(960 + side * 550, 360)])
			draw_colored_polygon(points, ink.lerp(accent, 0.09))
			draw_polyline(points, Color(accent, 0.3), 3.0, true)
	elif id == "abyss":
		for i in 7:
			var x := 100.0 + i * 290.0
			var points := PackedVector2Array([Vector2(x, 0), Vector2(x + 60, 0), Vector2(x + 320, 700), Vector2(x + 120, 700)])
			draw_colored_polygon(points, Color(accent, 0.025))
		for i in 12:
			var x := fposmod(i * 177.7, 1920)
			var y := 280 + fposmod(i * 71.1, 360)
			draw_arc(Vector2(x, y), 8 + i % 4 * 3, 0, TAU, 24, Color(accent, 0.22), 2.0, true)
	elif id == "canyon":
		for layer in range(3, 0, -1):
			for side: int in [-1, 1]:
				var points := PackedVector2Array([Vector2(960 + side * 150, 850)])
				for i in 12:
					points.append(Vector2(960 + side * (150 + i * 90), 330 - sin(i * 1.7 + layer) * 38 - i * 9 + layer * 18))
				points.append(Vector2(960 + side * 1150, 850))
				draw_colored_polygon(points, ink.lerp(secondary, 0.07 + layer * 0.04))
				draw_polyline(points, Color(accent, 0.13), 3.0, true)
	else:
		# Deterministic silhouettes; windows only on the outer skyline, leaving targets clear.
		for side: int in [-1, 1]:
			for i in 17:
				var x := 960.0 + side * (150 + i * 57)
				var height := 45.0 + fposmod(i * 79.7, 130.0)
				var width := 24.0 + fposmod(i * 19.1, 40.0)
				var rect := Rect2(x - width / 2.0, 350 - height, width, height + 20)
				draw_rect(rect, ink.lerp(accent, 0.08 + float(i % 3) * 0.02))
				draw_line(rect.position, rect.position + Vector2(width, 0), Color(accent, 0.24), 2.0)
				for row in int(height / 21):
					if (row + i) % 3 != 0:
						draw_line(rect.position + Vector2(6, 12 + row * 21), rect.position + Vector2(width - 6, 12 + row * 21), Color(secondary, 0.26), 3.0)


func _road(accent: Color, secondary: Color) -> void:
	var road := PackedVector2Array([project(0, 8000), project(6, 8000), project(6, -650), project(0, -650)])
	draw_colored_polygon(road, Color("0c142a"))
	for lane in 6:
		var tile := PackedVector2Array([project(lane, 8000), project(lane + 1, 8000), project(lane + 1, -650), project(lane, -650)])
		draw_colored_polygon(tile, Color(accent, 0.025 if lane % 2 else 0.055))
	for lane in 7:
		var a := project(lane, 8000)
		var b := project(lane, -650)
		var color := accent if lane in [0, 6] else accent.lerp(secondary, 0.5)
		draw_line(a, b, Color(color, 0.04), 14.0, true)
		draw_line(a, b, Color(color, 0.5 if lane in [0, 6] else 0.21), 2.5, true)
	for i in 14:
		var ahead := fposmod(i * 660.0 - (0 if reduced_motion else motion * 700), 8700) - 650
		var a := project(0, ahead)
		var b := project(6, ahead)
		draw_line(a, b, Color(accent, 0.045), 2.0, true)
	# Outer conduits give forward motion without moving the lane geometry.
	for side: int in [-1, 1]:
		for j in 3:
			var edge := -0.25 - j * 0.3 if side < 0 else 6.25 + j * 0.3
			draw_line(project(edge, 8000), project(edge, -600), Color(secondary, 0.13 - j * 0.03), 3.0, true)
	var a := project(0, 0)
	var b := project(6, 0)
	draw_line(a, b, Color(accent, 0.055), 26.0, true)
	draw_line(a, b, Color(accent, 0.18), 9.0, true)
	draw_line(a, b, Color(accent, 0.8), 3.0, true)


func _events() -> void:
	var time := rules.elapsed_ms if preview_time < 0 else preview_time
	# Draw far to near. The cursor bounds work to the preview, even on a 30-minute course.
	var visible: Array[int] = []
	for i in range(maxi(0, rules._event_cursor - 1), rules.course.events.size()):
		var event: Dictionary = rules.course.events[i]
		if int(event.startMs) > time + int(PREVIEW_MS):
			break
		if int(event.endMs) >= time - 250:
			visible.append(i)
	visible.reverse()
	for index in visible:
		var event: Dictionary = rules.course.events[index]
		var state: Dictionary = rules.event_states[index]
		var options := NeonCourse.choices(event)
		for c in options.size():
			var choice: Dictionary = options[c]
			var lane := int(choice.laneIndex)
			var color := GOLD if event.type == "pickup" else (HOLD if event.type == "hold" else CHARGE)
			var muted := int(state.choice) >= 0 and int(state.choice) != c
			if muted:
				color.a = 0.18
			if event.type == "pickup":
				if bool(state.hit):
					continue
				var at := float(event.hitMs) - time
				var centre := project(lane + 0.5, at)
				var width := project(lane + 0.85, at).x - centre.x
				var height := maxf(4.0, width * 0.28)
				var gem := PackedVector2Array([centre + Vector2(-width, 0), centre + Vector2(0, -height), centre + Vector2(width, 0), centre + Vector2(0, height), centre + Vector2(-width, 0)])
				draw_colored_polygon(gem, Color(color, color.a * 0.18))
				draw_polyline(gem, color, 4.0, true)
				draw_line(centre + Vector2(-width * 0.55, 0), centre + Vector2(width * 0.55, 0), WHITE, 3.0, true)
			else:
				var near_ms := maxf(0, float(event.startMs) - time)
				var far_ms := minf(PREVIEW_MS, float(event.endMs) - time)
				var a := project(lane + 0.12, near_ms)
				var b := project(lane + 0.88, near_ms)
				var d := project(lane + 0.12, far_ms)
				var e := project(lane + 0.88, far_ms)
				var quad := PackedVector2Array([a, b, e, d, a])
				draw_colored_polygon(quad, Color(color, color.a * 0.12))
				draw_polyline(quad, Color(color, color.a * 0.8), 3.0, true)
				for tick in range(0, 9):
					var ahead := near_ms + tick * 1000.0
					if ahead > far_ms:
						break
					var p := project(lane + 0.5, ahead)
					var w := (project(lane + 0.78, ahead).x - p.x)
					if event.type == "hold":
						draw_polyline(PackedVector2Array([p + Vector2(-w, 8), p + Vector2(0, -5), p + Vector2(w, 8)]), Color(color, color.a * 0.55), 3.0, true)
					else:
						draw_polyline(PackedVector2Array([p + Vector2(-w * 0.3, -14), p + Vector2(w * 0.2, -2), p + Vector2(-w * 0.2, 2), p + Vector2(w * 0.3, 14)]), color, 4.0, true)
				if options.size() > 1 and near_ms < 3500:
					_text("+25%" if int(choice.get("rewardPercent", 100)) > 100 else "FLOW", (a + b) / 2 + Vector2(-54, -18), 34, color)


func _bands(accent: Color) -> void:
	if _band_world != world_id:
		_band_world = world_id
		_band_styles.clear()
		for selected in [false, true]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(accent, 0.18) if selected else Color("101a32")
			style.border_color = Color(accent, 0.8) if selected else Color(accent, 0.2)
			style.set_border_width_all(2)
			style.set_corner_radius_all(14)
			_band_styles.append(style)
	for lane in 6:
		var band := NeonRules.band(lane, rules.tier)
		var x := project(lane + 0.5, 0).x
		var selected := lane == rules.selected_lane
		var rect := Rect2(x - 99, 914, 198, 65)
		draw_style_box(_band_styles[1 if selected else 0], rect)
		_text("%d–%d" % [band.x, band.y], Vector2(x - 52, 958), 36, WHITE if selected else MUTED)
		_text(str(lane + 1), Vector2(x - 9, 908), 34, accent if selected else MUTED)


func _rider(lane: float, shift: float, color: Color, ghost: bool) -> void:
	var centre := project(lane + 0.5, 0) + Vector2(0, -34 + shift)
	var alpha := 0.35 if ghost else 1.0
	# The ion trail extends behind the wheel, never into upcoming targets.
	if not ghost:
		for i in range(6, 0, -1):
			var w := 12 + i * 5.0
			var trail_color := color.lerp(Color("bc9fff"), float(i) / 6) if trail_id == "prism" else color
			draw_colored_polygon(PackedVector2Array([centre + Vector2(-w, 12), centre + Vector2(w, 12), centre + Vector2(w * 0.25, 65), centre + Vector2(-w * 0.25, 65)]), Color(trail_color, 0.018 * (7 - i)))
		if trail_id == "comet":
			for i in 9:
				draw_circle(centre + Vector2(sin(i * 8.1) * 29, 20 + i * 5), 2, Color(WHITE, 0.4))
	for radius in [53, 47, 42]:
		draw_arc(centre, radius, 0, TAU, 64, Color(color, alpha * 0.08), 8.0, true)
	draw_circle(centre, 37, Color("14283f", alpha))
	draw_arc(centre, 38, 0, TAU, 64, Color(color, alpha), 4.0, true)
	draw_arc(centre, 29, 0.3, TAU - 0.5, 48, Color(WHITE, alpha * 0.85), 3.0, true)
	var chevron := PackedVector2Array([centre + Vector2(-15, 8), centre + Vector2(0, -12), centre + Vector2(15, 8), centre + Vector2(0, 0), centre + Vector2(-15, 8)])
	draw_colored_polygon(chevron, Color(WHITE, alpha))


func _text(value: String, at: Vector2, size: int, color: Color) -> void:
	draw_string_outline(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7, Color("0a1022"))
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _tutorial_help(accent: Color) -> void:
	if rules.course.get("courseId", "") != "tutorial":
		return
	var minute := rules.elapsed_ms / 60000
	var cards := [
		["01 / STEER", "Turn the resistance knob.", "Match the ranges below.", "Diamonds earn points."],
		["02 / HOLD", "Stay inside the ribbon.", "Match its cadence range.", "Each second earns points."],
		["03 / FIND YOUR RHYTHM", "Aim for smooth changes.", "Watch the next target.", "No music cues needed."],
		["04 / CHARGE", "Stay on the violet bolts.", "Power fills the meter.", "Above 120 rpm: ease off."],
		["05 / READY FOR MORE", "Finish at an easy pace.", "Try a longer course next.", "Surge branches add 25%."],
	]
	var card: Array = cards[clampi(minute, 0, 4)]
	_text(card[0], Vector2(52, 445), 34, accent)
	for i in range(1, card.size()):
		_text(card[i], Vector2(52, 445 + i * 44), 34, MUTED)
