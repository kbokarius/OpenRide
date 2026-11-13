class_name LaneSmashMenuTheme
extends GameTheme
## One restrained palette for the selector, options and history.
func _init() -> void:
	super(Color("83cbdc"), Color("0b1420"), 0.0, false, true)

func button_style(kind := PRIMARY, pressed := false) -> StyleBoxFlat:
	var style := super.button_style(kind, pressed)
	var chosen := kind == PRIMARY
	style.bg_color = Color("244c60") if chosen else Color("122332")
	style.border_color = Color("85cadb") if chosen else Color("345161")
	if kind == DANGER:
		style.bg_color = Color("4c2632")
		style.border_color = Color("b77784")
	if pressed: style.bg_color = style.bg_color.lightened(0.12)
	style.set_border_width_all(2 if chosen else 1)
	style.set_corner_radius_all(12)
	return style

static func gradient(top: Color, bottom: Color) -> TextureRect:
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([top, bottom])
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.ONE
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
