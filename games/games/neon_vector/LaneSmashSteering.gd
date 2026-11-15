class_name LaneSmashSteering
extends RefCounted
## Presentation only. Rules still use the original integer resistance bands and settle time.
## The tyre moves inside the lane, with a quick, eased hop over the seam at each threshold.
const TRAVEL := 0.28  # fraction of a lane each side; leaves room for the wide motorcycle
const FOLLOW := 11.0
const SNAP_FOLLOW := 28.0
const SNAP_SECONDS := 0.18
const FADE_SECONDS := 0.32
const COLOR := Color("c6ecff")
const CUE_SIZE := Vector2(360, 94)

var lane := 2.0
var target := -1
var weights := PackedFloat32Array([0, 0, 0, 0, 0, 0])
var direction := 0
var cue_alpha := 0.0
var cue_age := 0.0
var _band := -1
var _initialized := false
var _snap_left := 0.0
var _style: StyleBoxFlat


static func position_for(resistance: float, tier: String) -> float:
	if not is_finite(resistance): return 2.0
	var lane := NeonRules.clamped_lane_for(resistance, tier)
	var band := NeonRules.band(lane, tier)
	return lane + lerpf(-TRAVEL, TRAVEL, clampf((resistance - band.x) / float(band.y - band.x), 0.0, 1.0))


static func target_for(rules: NeonRules) -> int:
	if rules.barrage.active: return rules.barrage.target_lane()
	var event := rules.current_event()
	# Guidance persists through every approach, interruption and the final roll-out.
	return int(event.laneIndex) if not event.is_empty() else clampi(rules.last_target_lane, 0, 5)


func update(delta: float, resistance: float, tier: String, wanted_lane: int) -> void:
	target = wanted_lane if wanted_lane >= 0 and wanted_lane < 6 else -1
	var valid := is_finite(resistance)
	if valid:
		var next_band := NeonRules.clamped_lane_for(resistance, tier)
		var wanted := position_for(resistance, tier)
		if not _initialized or delta <= 0.0:
			lane = wanted
			_initialized = true
		elif next_band != _band:
			_snap_left = SNAP_SECONDS
		var rate := SNAP_FOLLOW if _snap_left > 0.0 else FOLLOW
		lane = lerpf(lane, wanted, 1.0 - exp(-maxf(delta, 0.0) * rate))
		_snap_left = maxf(0.0, _snap_left - delta)
		_band = next_band
	var fade := minf(1.0, maxf(delta, 0.0) / FADE_SECONDS) if delta > 0.0 else 1.0
	for i in 6: weights[i] = move_toward(weights[i], 1.0 if i == target else 0.0, fade)
	var wanted_direction := 0
	if target >= 0 and valid:
		var band := NeonRules.band(target, tier)
		wanted_direction = -1 if resistance > band.y else (1 if resistance < band.x else 0)
	# Fade the old instruction before reversing it; no arrow flashes in the opposite direction.
	if wanted_direction != direction:
		cue_alpha = move_toward(cue_alpha, 0.0, fade)
		if cue_alpha <= 0.0:
			direction = wanted_direction
			cue_age = 0.0
	else:
		cue_alpha = move_toward(cue_alpha, 1.0 if direction != 0 else 0.0, fade)
	cue_age += maxf(delta, 0.0)


## A compact instruction under the main ride prompt. Its stable position keeps it clear of
## the motorcycle and cadence gauge, even in the outside lanes and through a full roll.
func paint(canvas: CanvasItem, caps: Font, look: LaneSmashMenuTheme, reduced_motion: bool) -> void:
	if cue_alpha <= 0.001 or direction == 0: return
	var at := Vector2(HudTheme.W * 0.5, 286.0)
	if not reduced_motion: at.y += 12.0 * pow(1.0 - cue_alpha, 2.0)
	if _style == null: _style = look._shape(LaneSmashMenuTheme.SURFACE, COLOR, 2)
	_style.bg_color = Color(LaneSmashMenuTheme.SURFACE, 0.94 * cue_alpha)
	_style.border_color = Color(COLOR, 0.65 * cue_alpha)
	canvas.draw_style_box(_style, Rect2(at - CUE_SIZE * 0.5, CUE_SIZE))
	var arrow := at + Vector2(direction * 136.0, 0.0)
	var shift := 0.0 if reduced_motion else 4.0 * sin(cue_age * 4.5)
	for i in 2:
		var x := arrow.x + direction * (i * 15.0 - 8.0 + shift)
		var points := PackedVector2Array([Vector2(x - direction * 10.0, arrow.y - 16.0), Vector2(x + direction * 5.0, arrow.y), Vector2(x - direction * 10.0, arrow.y + 16.0)])
		canvas.draw_polyline(points, Color(COLOR, cue_alpha * (0.65 if i == 0 else 1.0)), 5.0, true)
	var text_at := at + Vector2(-direction * 30.0, 0)
	for row: Array in [["MOVE LEFT" if direction < 0 else "MOVE RIGHT", -3.0, 30], ["LESS RESISTANCE" if direction < 0 else "MORE RESISTANCE", 26.0, 21]]:
		var width := caps.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, row[2]).x
		canvas.draw_string(caps, text_at + Vector2(-width * 0.5, row[1]), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, row[2], Color(COLOR, cue_alpha))
