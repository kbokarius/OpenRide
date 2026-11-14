class_name LaneSmashBarrageGauge
extends Control
## Projected landing-time position, so a curved/offscreen target remains understandable.
var offset := 0.0
var _font: Font
var _background: StyleBoxFlat
var _danger: StyleBoxFlat
func _ready() -> void:
	custom_minimum_size = Vector2(740, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = GameTheme.house().font()
	_background = _style(Color("263544"))
	_danger = _style(Color("bb4251"))

func _draw() -> void:
	if _font == null: return
	var width := size.x - 80
	var bar := Rect2(40, 10, width, 12)
	draw_style_box(_background, bar)
	var center := bar.get_center().x
	var half := (LaneSmashBarrage.HALF_LENGTH + LaneSmashBarrage.RIDER_RADIUS) / 60.0 * width * 0.5
	draw_style_box(_danger, Rect2(center - half, 8, half * 2, 16))
	var x := center + clampf(offset / 60.0, -1, 1) * width * 0.5
	var safe := absf(offset) > LaneSmashBarrage.HALF_LENGTH + LaneSmashBarrage.RIDER_RADIUS
	var tint := Color("83f9d5") if safe else Color("ffcf9d")
	draw_circle(Vector2(x, 16), 10, Color("09111c"))
	draw_circle(Vector2(x, 16), 6, tint)
	draw_string(_font, Vector2(40, 55), "BEHIND THE BLAST", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("c2d1df"))
	var text := "PAST THE BLAST"
	var length := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(_font, Vector2(40 + width - length, 55), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("c2d1df"))

func _style(tint: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(5)
	return style
