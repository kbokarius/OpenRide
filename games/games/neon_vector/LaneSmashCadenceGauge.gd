class_name LaneSmashCadenceGauge
extends RefCounted
## The cadence gauge that floats beside the motorcycle during a cadence section, and for a
## moment before one: a vertical track from the section's lowest rpm (bottom) to its highest
## (top), a bright band in the middle for the sweet spot, and a marker where the rider is now.
## Same idea as the gauge Lanebreak puts on its wheel, with the sweet spot drawn in.
##
## It is drawn by the view that owns the HUD (`paint`), and never changes the rules.
const SIZE := Vector2(244, 400)
const TRACK_TOP := 78.0     ## from the panel's top to the top of the track (the highest rpm)
const TRACK_HEIGHT := 244.0
const TRACK_X := 58.0       ## centre of the track from the panel's left edge
const TRACK_WIDTH := 32.0
const OVERSHOOT := 0.14     ## how far past either end the marker can travel when out of range
const FADE_PER_SEC := 5.0
const FOLLOW := 10.0        ## how quickly the marker follows the measured cadence
const MINT := LaneSmashLook.MINT
const HOT := LaneSmashLook.HOT
const DANGER := LaneSmashLook.DANGER

var target: Dictionary = {}  ## the last `NeonRules.cadence_target()`; kept while fading out
var alpha := 0.0
var shown_rpm := 0.0
var centre := Vector2(-1, -1)  ## where the panel's centre is on the stage; set by `follow`
var _side := 0.0
var _style: StyleBoxFlat


## Advances the fade, the marker and the panel's place beside the bike (`bike` is the
## motorcycle's position on the stage; `bounds` is where the panel may sit).
func update(delta: float, live: Dictionary, bike: Vector2, bounds: Rect2) -> void:
	if not live.is_empty():
		if target.get("eventId", "") != live.eventId or alpha <= 0.0: shown_rpm = float(live.rpm)
		target = live
	alpha = move_toward(alpha, 1.0 if not live.is_empty() else 0.0, delta * FADE_PER_SEC if delta > 0.0 else 1.0)
	if target.is_empty(): return
	shown_rpm = lerpf(shown_rpm, float(target.rpm), 1.0 - exp(-delta * FOLLOW)) if delta > 0.0 else float(target.rpm)
	# Beside the bike, on the side away from the middle of the road, so it never covers the
	# lane ahead. It changes side only once the bike is clearly across the middle.
	var middle := bounds.get_center().x
	if _side == 0.0 or absf(bike.x - middle) > 90.0: _side = -1.0 if bike.x < middle else 1.0
	var wanted := Vector2(bike.x + _side * (SIZE.x * 0.5 + 104.0), bike.y - 90.0)
	wanted.x = clampf(wanted.x, bounds.position.x + SIZE.x * 0.5, bounds.end.x - SIZE.x * 0.5)
	wanted.y = clampf(wanted.y, bounds.position.y + SIZE.y * 0.5, bounds.end.y - SIZE.y * 0.5)
	centre = wanted if centre.x < 0.0 or delta <= 0.0 else centre.lerp(wanted, 1.0 - exp(-delta * 7.0))


## Where an rpm sits on the track: 0 at the section's minimum, 1 at its maximum, and a
## little beyond either end when the rider is out of range.
static func level(rpm: float, low: float, high: float) -> float:
	return clampf((rpm - low) / maxf(1.0, high - low), -OVERSHOOT, 1.0 + OVERSHOOT)


## The state the gauge is showing: "ahead" before the section starts, then "sweet", "in",
## "slow" or "fast".
func state() -> String:
	if target.is_empty(): return ""
	if not bool(target.active): return "ahead"
	if shown_rpm < float(target.cadenceMin) - 0.5: return "slow"
	if shown_rpm > float(target.cadenceMax) + 0.5: return "fast"
	return "sweet" if bool(target.bonus) and shown_rpm >= float(target.sweetMin) and shown_rpm <= float(target.sweetMax) else "in"


func paint(canvas: CanvasItem, caps: Font, digits: Font, look: LaneSmashMenuTheme) -> void:
	if alpha <= 0.001 or target.is_empty() or centre.x < 0.0: return
	if _style == null: _style = look._shape(Color(LaneSmashMenuTheme.SURFACE, 0.9), Color(MINT, 0.55), 2)
	var now := state()
	var tone := HOT if now == "sweet" else (MINT if now in ["in", "ahead"] else DANGER)
	var origin := centre - SIZE * 0.5
	_style.bg_color = Color(LaneSmashMenuTheme.SURFACE, 0.9 * alpha)
	_style.border_color = Color(tone, (0.9 if now != "ahead" else 0.5) * alpha)
	canvas.draw_style_box(_style, Rect2(origin, SIZE))
	var low := float(target.cadenceMin)
	var high := float(target.cadenceMax)
	var title := "NEXT · RPM" if now == "ahead" else "RPM"
	var title_width := caps.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	canvas.draw_string(caps, origin + Vector2((SIZE.x - title_width) * 0.5, 44), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(LaneSmashMenuTheme.TEXT_MUTED, alpha))
	# The track: the whole range dim, the sweet spot bright.
	var track := Rect2(origin + Vector2(TRACK_X - TRACK_WIDTH * 0.5, TRACK_TOP), Vector2(TRACK_WIDTH, TRACK_HEIGHT))
	canvas.draw_rect(track, Color(MINT, 0.26 * alpha))
	canvas.draw_rect(Rect2(track.position, Vector2(TRACK_WIDTH, 4)), Color(MINT, 0.9 * alpha))
	canvas.draw_rect(Rect2(Vector2(track.position.x, track.end.y - 4), Vector2(TRACK_WIDTH, 4)), Color(MINT, 0.9 * alpha))
	if bool(target.bonus):
		var top := track.end.y - TRACK_HEIGHT * level(float(target.sweetMax), low, high)
		var bottom := track.end.y - TRACK_HEIGHT * level(float(target.sweetMin), low, high)
		var sweet := Rect2(Vector2(track.position.x - 7, top), Vector2(TRACK_WIDTH + 14, bottom - top))
		canvas.draw_rect(sweet, Color(HOT if now == "sweet" else MINT, (0.95 if now == "sweet" else 0.62) * alpha))
	# The range, at the ends of the track.
	for pair: Array in [[high, track.position.y + 16.0], [low, track.end.y + 10.0]]:
		canvas.draw_string(digits, Vector2(track.end.x + 22, float(pair[1])), "%d" % int(pair[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(LaneSmashMenuTheme.TEXT_MUTED, alpha))
	# The rider: a marker across the track and the measured rpm beside it.
	var y := track.end.y - TRACK_HEIGHT * level(shown_rpm, low, high)
	var marker := PackedVector2Array([Vector2(track.position.x - 22, y - 14), Vector2(track.position.x - 4, y), Vector2(track.position.x - 22, y + 14)])
	canvas.draw_colored_polygon(marker, Color(tone, alpha))
	canvas.draw_rect(Rect2(Vector2(track.position.x - 6, y - 4), Vector2(TRACK_WIDTH + 12, 8)), Color(Color.WHITE if now != "ahead" else tone, alpha))
	var value := "%d" % roundi(shown_rpm)
	var value_at := Vector2(track.end.x + 20, clampf(y + 23, track.position.y + 76, track.end.y - 30))
	canvas.draw_string_outline(digits, value_at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, 68, 8, Color(0.01, 0.02, 0.045, 0.85 * alpha))
	canvas.draw_string(digits, value_at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, 68, Color(tone.lerp(Color.WHITE, 0.35), alpha))
	# One word under the track says what to do.
	var word: String = {"ahead": "GET READY", "sweet": "SWEET SPOT", "in": "HOLD IT", "slow": "FASTER", "fast": "SLOWER"}[now]
	if now == "in" and bool(target.bonus): word = "AIM FOR MIDDLE"
	var size := 28
	var word_width := caps.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(caps, origin + Vector2((SIZE.x - word_width) * 0.5, SIZE.y - 22), word, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(tone, alpha))
