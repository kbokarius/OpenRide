class_name LaneSmashSpectrum
extends Control
## A small eight-bar meter of the music that is playing: bass on the left, treble on the right.
## It reads the jukebox's live bands and eases them, so the bars swing with the music without
## twitching. With nothing playing it rests as a row of dots.
##
## Used as a control in the menus, and through `eased`/`paint` by views that draw their own
## interface (the ride's track chip).
const BARS := 8
const ATTACK := 16.0  ## per second
const RELEASE := 5.0
const GAP := 3.0
var color := LaneSmashMenuTheme.ACCENT
var levels := blank()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(92, 52)


func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	levels = eased(levels, delta)
	queue_redraw()


func _draw() -> void:
	paint(self, Rect2(Vector2.ZERO, size), levels, color, LaneSmashLook.companion(color))


static func blank() -> PackedFloat32Array:
	var list := PackedFloat32Array()
	list.resize(BARS)
	list.fill(0.0)
	return list


## `levels` moved one frame toward the jukebox's live bands (toward zero when nothing plays).
static func eased(from: PackedFloat32Array, delta: float) -> PackedFloat32Array:
	var player := LaneSmashLook.jukebox()
	var live: bool = player != null and player.bands.size() >= BARS
	var to := from.duplicate()
	for i in BARS:
		var target := float(player.bands[i]) if live else 0.0
		var value := lerpf(to[i], target, 1.0 - exp(-delta * (ATTACK if target > to[i] else RELEASE)))
		to[i] = 0.0 if value < 0.004 and target <= 0.0 else value
	return to


## Draws the bars inside `rect` on `canvas`, running from `first` (bass) to `last` (treble).
static func paint(canvas: CanvasItem, rect: Rect2, bars: PackedFloat32Array, first: Color, last: Color, alpha := 1.0) -> void:
	var width := (rect.size.x - GAP * (BARS - 1)) / BARS
	for i in BARS:
		var level := clampf(bars[i], 0.0, 1.0) if i < bars.size() else 0.0
		var height := maxf(3.0, roundf(rect.size.y * level))
		var tone := first.lerp(last, i / float(BARS - 1))
		canvas.draw_rect(Rect2(rect.position.x + i * (width + GAP), rect.end.y - height, width, height), Color(tone, (0.45 + 0.55 * level) * alpha))
