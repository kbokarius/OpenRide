class_name LaneSmashGovernor
extends RefCounted
## Decides when the picture should drop a quality tier (Auto only). It watches the frame rate
## in four-second windows and asks for a step down after two slow windows in a row. A single
## long frame (a shader compiling, a track loading, the tier itself changing) is not the
## frame rate: it is left out, so one hitch can no longer cost the rest of the ride its
## resolution, which is what happened before.
const WINDOW_SEC := 4.0
const SETTLE_SEC := 3.0   ## ignored at the start of a ride and after each step
const MIN_FPS := 50.0
const HITCH_SEC := 0.2    ## a frame longer than this is a hitch
const SLOW_WINDOWS := 2

var last_fps := 0.0
var _time := -SETTLE_SEC
var _frames := 0
var _slow := 0


func reset() -> void:
	_time = -SETTLE_SEC
	_frames = 0
	_slow = 0


## Feeds one frame; true when it is time to step down a tier (the governor then settles again).
func observe(delta: float) -> bool:
	if delta <= 0.0 or delta > HITCH_SEC: return false
	_time += delta
	if _time < 0.0: return false
	_frames += 1
	if _time < WINDOW_SEC: return false
	last_fps = _frames / _time
	_time = 0.0
	_frames = 0
	_slow = _slow + 1 if last_fps < MIN_FPS else 0
	if _slow < SLOW_WINDOWS: return false
	reset()
	return true
