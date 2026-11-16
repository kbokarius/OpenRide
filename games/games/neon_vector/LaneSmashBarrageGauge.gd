class_name LaneSmashBarrageGauge
extends RefCounted
## Beside-bike projection of where the rider will be when the bomb lands.
## Red is the blast, green above earns a pass bonus, slate below avoids without points.
## Reads rules only; interpolation never decides a hit or a reward.
const SIZE := Vector2(244, 400)
const RANGE_METRES := 60.0
const GREEN := Color("70efb4")
const RED := Color("ff5268")
const SLATE := Color("293b50")
const TRACK := Rect2(44, 92, 32, 218)
const FADE_PER_SEC := 5.0
const FOLLOW := 10.0
var target: Dictionary = {}
var alpha := 0.0
var shown_offset := 0.0
var centre := Vector2(-1, -1)
var _anchor := LaneSmashBikeGaugeAnchor.new()
var _style: StyleBoxFlat

static func read(rules: NeonRules) -> Dictionary:
	if not rules.barrage.active or not rules.pause_reason.is_empty(): return {}
	var shot := rules.barrage.current_shot()
	if shot.is_empty():
		return {"id": str(rules.barrage.section.barrageId), "state": "prepare", "offset": 0.0,
			"seconds": maxi(0, ceili((int(rules.barrage.section.startMs) - rules.elapsed_ms) / 1000.0)),
			"prompt": "GET READY", "detail": "Change pace to dodge"}
	var offset := rules.barrage.projected_offset(rules)
	var state := "live"
	var prompt := "PEDAL FASTER" if shot.direction == "faster" else "PEDAL SLOWER"
	var detail := "%d rpm target" % int(shot.targetRpm)
	if bool(shot.resolved):
		state = str(shot.outcome)
		offset = float(shot.get("resolvedRiderMeters", shot.impactRiderMeters)) - float(shot.targetMeters)
		prompt = {"passed": "PASSED", "held_back": "AVOIDED", "hit": "BOMB HIT"}.get(state, "KEEP PEDALLING")
		detail = ("+%d points" % int(shot.points)) if int(shot.points) > 0 else ("−%d points" % absi(int(shot.points)) if int(shot.points) < 0 else "No points")
	elif shot.get("rapid", false):
		state = "rapid"
		prompt = "WRONG LANE"
		detail = "Follow the lit lane"
	elif absf(offset) > LaneSmashBarrage.HALF_LENGTH + LaneSmashBarrage.RIDER_RADIUS + 2.0:
		prompt = "KEEP THIS PACE"
	return {"id": str(shot.shotId), "state": state, "offset": offset,
		"seconds": maxi(0, ceili((int(shot.impactMs) - rules.elapsed_ms) / 1000.0)), "prompt": prompt, "detail": detail}

func update(delta: float, live: Dictionary, bike: Vector2, bounds: Rect2) -> void:
	if not live.is_empty():
		if target.get("id", "") != live.id or alpha <= 0.0: shown_offset = float(live.offset)
		target = live
	alpha = move_toward(alpha, 1.0 if not live.is_empty() else 0.0, delta * FADE_PER_SEC if delta > 0.0 else 1.0)
	if target.is_empty(): return
	# Bound the interpolation too: a huge resolved lead must not delay the next marker.
	var wanted := clampf(float(target.offset), -RANGE_METRES, RANGE_METRES)
	shown_offset = lerpf(clampf(shown_offset, -RANGE_METRES, RANGE_METRES), wanted, 1.0 - exp(-delta * FOLLOW)) if delta > 0.0 else wanted
	centre = _anchor.follow(delta, bike, bounds, SIZE, LaneSmashCadenceGauge.BIKE_GAP)

static func level(offset: float) -> float:
	return (clampf(offset / RANGE_METRES, -1.0, 1.0) + 1.0) * 0.5

func paint(canvas: CanvasItem, caps: Font, digits: Font, look: LaneSmashMenuTheme) -> void:
	if alpha <= 0.001 or target.is_empty() or centre.x < 0: return
	var state := str(target.state)
	var safe_edge := LaneSmashBarrage.HALF_LENGTH + LaneSmashBarrage.RIDER_RADIUS
	var tone := RED if state in ["hit", "rapid"] else (GREEN if shown_offset > safe_edge or state == "passed" else (Color("a9bdd2") if shown_offset < -safe_edge or state in ["prepare", "held_back"] else RED))
	var origin := centre - SIZE * 0.5
	if _style == null: _style = look._shape(LaneSmashMenuTheme.SURFACE, RED, 2)
	_style.bg_color = Color(LaneSmashMenuTheme.SURFACE, 0.94 * alpha)
	_style.border_color = Color(tone, 0.7 * alpha)
	canvas.draw_style_box(_style, Rect2(origin, SIZE))
	_center_text(canvas, caps, "BOMB ZONE", origin, 38, 27, LaneSmashMenuTheme.TEXT)
	var subtitle := "%d s TO IMPACT" % int(target.seconds)
	if state == "prepare": subtitle = "STARTS IN %d s" % int(target.seconds)
	elif state in ["passed", "held_back", "hit"]: subtitle = "RESULT"
	_center_text(canvas, digits, subtitle, origin, 66, 21, LaneSmashMenuTheme.TEXT_MUTED)
	var track := Rect2(origin + TRACK.position, TRACK.size)
	var red_top := track.end.y - track.size.y * level(safe_edge)
	var red_bottom := track.end.y - track.size.y * level(-safe_edge)
	# A restrained gradient, rendered in a fixed number of strips; no textures or allocations.
	for i in 36:
		var fraction := (i + 0.5) / 36.0
		var y := lerpf(track.position.y, track.end.y, fraction)
		var tint := GREEN if y < red_top else (RED if y < red_bottom else SLATE)
		var bright := 0.9 if y < red_top else (0.85 if y < red_bottom else 1.0)
		canvas.draw_rect(Rect2(track.position.x, track.position.y + i * track.size.y / 36.0, track.size.x, track.size.y / 36.0 + 0.1), Color(tint.lightened((1.0 - fraction) * 0.08), bright * alpha))
	for y in [red_top, red_bottom]:
		canvas.draw_line(Vector2(track.position.x - 4, y), Vector2(track.end.x + 4, y), Color(RED.lightened(0.25), alpha), 2, true)
	for row: Array in [["PASS", 116, GREEN], ["+ POINTS", 141, GREEN], ["BLAST", 209, RED], ["BEHIND", 284, LaneSmashMenuTheme.TEXT_MUTED], ["NO POINTS", 309, LaneSmashMenuTheme.TEXT_MUTED]]:
		canvas.draw_string(caps, origin + Vector2(102, row[1]), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 23 if row[0] in ["PASS", "BLAST", "BEHIND"] else 19, Color(row[2], alpha))
	if state != "prepare":
		var y := track.end.y - track.size.y * level(shown_offset)
		canvas.draw_line(Vector2(track.position.x - 8, y), Vector2(track.end.x + 8, y), Color("08121e", alpha), 12, true)
		canvas.draw_line(Vector2(track.position.x - 8, y), Vector2(track.end.x + 8, y), Color(Color.WHITE, alpha), 5, true)
		canvas.draw_circle(Vector2(track.position.x - 16, y), 7, Color(Color.WHITE, alpha), true, -1, true)
	_center_text(canvas, caps, str(target.prompt), origin, 350, 26, tone)
	_center_text(canvas, digits, str(target.detail), origin, 379, 22, LaneSmashMenuTheme.TEXT_MUTED)

func _center_text(canvas: CanvasItem, font: Font, text: String, origin: Vector2, y: float, size: int, tint: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(font, origin + Vector2((SIZE.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(tint, alpha))
