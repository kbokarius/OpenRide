class_name LaneSmashMenuTheme
extends GameTheme
## The one Lane Smash interface look, shared by the track selector, settings, the ride HUD, the
## intro card, the end-ride and recovery cards and the results: dark glass panels with cut
## corners, a single cyan accent, and one spacing and type scale.
##
## Spacing (1920x1080 canvas): everything sits on an 8 px grid. Use the S constants rather than
## literal offsets, so gaps between groups stay consistent from screen to screen.
const ACCENT := Color("5fd8ff")
const INK_DEEP := Color("060a13")
const SURFACE := Color(0.030, 0.050, 0.090, 0.86)      ## panels over the 3D ride
const SURFACE_SOLID := Color(0.036, 0.062, 0.105, 0.98) ## cards and menus
const RAISED := Color(0.060, 0.098, 0.155, 0.96)        ## controls on a panel
const TEXT := Color("f2f6ff")
const TEXT_MUTED := Color("9fb2ca")
const TEXT_FAINT := Color("6f829c")
const S1 := 8
const S2 := 16
const S3 := 24
const S4 := 32
const S5 := 48
const S6 := 64
const MARGIN := 56          ## screen edge to content, menus
const CUT := 14             ## corner cut on panels and buttons
## Type scale. Nothing on screen is smaller than CAPTION; body text is HudTheme.SMALL or more.
const DISPLAY := 104
const TITLE := 56
const HEADING := 44
const BODY := 36
const LABEL := 34
const CAPTION := 30

static var _shared: LaneSmashMenuTheme
static var _caps: FontVariation
static var _tabular: FontVariation


func _init() -> void:
	super(ACCENT, INK_DEEP, 0.0, false, true)
	panel = SURFACE
	panel_edge = Color(ACCENT, 0.34)


static func shared() -> LaneSmashMenuTheme:
	if _shared == null: _shared = LaneSmashMenuTheme.new()
	return _shared


## The face with wide tracking, for small capital section labels.
func caps_font() -> Font:
	if _caps == null:
		_caps = FontVariation.new()
		_caps.base_font = font()
		_caps.spacing_glyph = 3
	return _caps


## The face with fixed-width digits, for numbers that change in place.
func tabular_font() -> Font:
	if _tabular == null:
		_tabular = FontVariation.new()
		_tabular.base_font = font()
		_tabular.opentype_features = {"tnum": 1}
	return _tabular


## A small capital section label ("TRACK LIBRARY").
func caption(text: String, color := TEXT_MUTED, size := CAPTION) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", caps_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _shape(fill: Color, edge: Color, width: int, cut := CUT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(width)
	s.set_corner_radius_all(cut)
	s.corner_detail = 1  # one segment per corner: a clean diagonal cut
	s.anti_aliasing = true
	return s


func panel_style(fill = null, _lean := 0.0, _radius := 22) -> StyleBoxFlat:
	var s := _shape(fill if fill != null else SURFACE, Color(ACCENT, 0.34), 1)
	s.border_width_left = 3
	s.content_margin_left = S3
	s.content_margin_right = S3
	s.content_margin_top = S1
	s.content_margin_bottom = S1 + 2
	return s


func badge_style(fill = null, slim := false) -> StyleBoxFlat:
	var s := _shape(fill if fill != null else Color(ACCENT, 0.16), Color(ACCENT, 0.75), 1, 8)
	s.content_margin_left = S2 if slim else S3
	s.content_margin_right = S2 if slim else S3
	s.content_margin_top = 2 if slim else 6
	s.content_margin_bottom = 4 if slim else 8
	return s


func card_style() -> StyleBoxFlat:
	var s := _shape(SURFACE_SOLID, Color(ACCENT, 0.5), 2, 26)
	s.content_margin_left = S5
	s.content_margin_right = S5
	s.content_margin_top = S4
	s.content_margin_bottom = S4
	return s


func button_style(kind := PRIMARY, pressed := false) -> StyleBoxFlat:
	var fill := RAISED
	var edge := Color(ACCENT, 0.30)
	var width := 1
	match kind:
		PRIMARY:
			fill = Color(0.07, 0.30, 0.40, 0.98)
			edge = Color(ACCENT, 0.95)
			width = 2
		GO:
			fill = Color(0.06, 0.34, 0.27, 0.98)
			edge = Color(0.36, 1.0, 0.78, 0.9)
			width = 2
		DANGER:
			fill = Color(0.42, 0.08, 0.15, 0.98)
			edge = Color(1.0, 0.36, 0.46, 0.9)
			width = 2
	if pressed: fill = fill.lightened(0.14)
	var s := _shape(fill, edge, width)
	# Twelve pixels a side: the duration and difficulty rows must fit their fixed columns.
	s.content_margin_left = 12
	s.content_margin_right = 12
	return s


## A dimmed, edge-only style for a control that cannot be used yet.
func disabled_style() -> StyleBoxFlat:
	var s := _shape(Color(RAISED, 0.55), Color(TEXT_FAINT, 0.35), 1)
	# Twelve pixels a side: the duration and difficulty rows must fit their fixed columns.
	s.content_margin_left = 12
	s.content_margin_right = 12
	return s


func style_button(b: Button, kind := PRIMARY) -> void:
	super.style_button(b, kind)
	b.add_theme_stylebox_override("disabled", disabled_style())
	var hover := button_style(kind)
	hover.bg_color = hover.bg_color.lightened(0.07)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_focus_color", TEXT)
	b.add_theme_color_override("font_disabled_color", TEXT_FAINT)


func hud_skin() -> Dictionary:
	var skin := super.hud_skin()
	var hud_panel := panel_style()
	hud_panel.content_margin_top = 6
	hud_panel.content_margin_bottom = S1 + 2
	skin["panel"] = hud_panel
	return skin


## A soft vertical wash for full-screen backdrops and scrims (one TextureRect, one draw call).
static func gradient(top: Color, bottom: Color) -> TextureRect:
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([top, bottom])
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 8
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
