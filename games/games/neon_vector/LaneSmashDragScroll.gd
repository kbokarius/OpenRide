class_name LaneSmashDragScroll
extends Node
## Finger scrolling for a list of buttons. Add it as a child of a ScrollContainer: a press
## anywhere in the list, including on a card, that moves more than a few pixels becomes a
## scroll (with a little coasting after the finger lifts), and the button it started on is not
## activated. A press that stays put is an ordinary tap.
##
## The engine's own touch scrolling only starts on the gaps between buttons (a button keeps
## the press for itself) and only where it detects a touchscreen. This works from the pointer
## events every device sends (touches arrive as mouse events too), so it is the same on the
## bike, on a desktop and under test.
const THRESHOLD := 14.0   ## stage pixels of travel before a press turns into a scroll
const COAST_DECAY := 4.5  ## per second
const TAP_GUARD_MSEC := 260

var scroll: ScrollContainer
var dragging := false
var _pressing := false
var _start_y := 0.0
var _start_scroll := 0.0
var _last_y := 0.0
var _last_msec := 0
var _velocity := 0.0   ## stage pixels per second, positive when the content moves down
var _coasting := false
var _dragged_msec := -100000


func _ready() -> void:
	scroll = get_parent() as ScrollContainer
	process_mode = Node.PROCESS_MODE_ALWAYS
	# This node does the dragging; the built-in handler would move the list a second time.
	if scroll != null: scroll.scroll_deadzone = 1000000


## Wraps a button's action so that it does nothing when the press was a scroll.
func guard(action: Callable) -> Callable:
	return func() -> void:
		if not dragged_recently(): action.call()


func dragged_recently() -> bool:
	return dragging or Time.get_ticks_msec() - _dragged_msec < TAP_GUARD_MSEC


func _input(event: InputEvent) -> void:
	if scroll == null or not scroll.is_visible_in_tree(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = scroll.make_input_local(event).position
		if event.pressed:
			_coasting = false
			dragging = false
			_pressing = Rect2(Vector2.ZERO, scroll.size).has_point(local)
			_start_y = local.y
			_last_y = local.y
			_start_scroll = scroll.scroll_vertical
			_velocity = 0.0
			_last_msec = Time.get_ticks_msec()
		elif _pressing:
			_pressing = false
			if dragging:
				dragging = false
				_dragged_msec = Time.get_ticks_msec()
				_coasting = absf(_velocity) > 60.0
	elif event is InputEventMouseMotion and _pressing:
		var y: float = scroll.make_input_local(event).position.y
		if not dragging and absf(y - _start_y) > THRESHOLD:
			dragging = true
			# Buttons drop a press when told a scroll has begun; `guard` covers the rest.
			scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		if dragging:
			scroll.scroll_vertical = roundi(_start_scroll - (y - _start_y))
			var now := Time.get_ticks_msec()
			var elapsed := maxf(0.001, (now - _last_msec) / 1000.0)
			_velocity = lerpf(_velocity, (y - _last_y) / elapsed, 0.5)
			_last_y = y
			_last_msec = now


func _process(delta: float) -> void:
	if not _coasting or scroll == null: return
	var before := scroll.scroll_vertical
	scroll.scroll_vertical = roundi(before - _velocity * delta)
	_velocity *= exp(-delta * COAST_DECAY)
	# Stop when it has slowed right down or run into either end of the list.
	if absf(_velocity) < 30.0 or scroll.scroll_vertical == before: _coasting = false
