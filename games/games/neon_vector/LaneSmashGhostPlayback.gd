class_name LaneSmashGhostPlayback
extends RefCounted
## Playback coverage is independent of score eligibility. Configure only with rows already
## accepted by NeonRecords; never extrapolate across missing time or beyond an early end.
const SAMPLE_MS := 100
const FADE_MS := 500

var complete := false
var available := false
var opacity := 0.0
var lane := -1.0
var distance := -1.0
var cadence := 0.0
var score_units := 0
var notice := ""

var _ticks: Array = []
var _spans: Array[Vector2i] = []
var _duration_ms := 0
var _last_expected_ms := 0
var _cursor := 0
var _span_index := 0
var _last_ms := -1


func configure(ticks: Array, duration_ms: int) -> void:
	_ticks = ticks
	_duration_ms = duration_ms
	_last_expected_ms = duration_ms - posmod(duration_ms, SAMPLE_MS)
	_cursor = 0
	_span_index = 0
	_last_ms = -1
	_spans.clear()
	complete = false
	_clear()
	for tick: Array in ticks:
		var time := int(tick[0])
		if _spans.is_empty() or time - _spans[-1].y > SAMPLE_MS:
			_spans.append(Vector2i(time, time))
		else:
			_spans[-1].y = time
	if _spans.size() == 1:
		complete = _spans[0].x <= SAMPLE_MS and _spans[0].y >= _last_expected_ms


func _clear() -> void:
	available = false
	opacity = 0.0
	lane = -1.0
	distance = -1.0
	cadence = 0.0
	score_units = 0
	notice = ""


func update(elapsed_ms: int, legacy_distance: float) -> void:
	_clear()
	if _ticks.is_empty(): return
	if elapsed_ms < _last_ms:
		_cursor = 0
		_span_index = 0
	_last_ms = elapsed_ms
	if elapsed_ms < _spans[0].x:
		if _spans[0].x > SAMPLE_MS: notice = "GHOST RECORDING UNAVAILABLE"
		return
	if elapsed_ms > _duration_ms or (elapsed_ms > _spans[-1].y and _spans[-1].y < _last_expected_ms):
		notice = "GHOST RECORDING ENDED"
		return
	while _span_index + 1 < _spans.size() and _spans[_span_index + 1].x <= elapsed_ms:
		_span_index += 1
	var span := _spans[_span_index]
	if elapsed_ms > span.y and _span_index + 1 < _spans.size():
		notice = "GHOST RECORDING UNAVAILABLE"
		return
	opacity = 1.0
	if span.x > SAMPLE_MS:
		opacity *= smoothstep(float(span.x), float(span.x + FADE_MS), float(elapsed_ms))
	if span.y < _last_expected_ms:
		opacity *= 1.0 - smoothstep(float(span.y - FADE_MS), float(span.y), float(elapsed_ms))
	if opacity <= 0.0:
		notice = "GHOST RECORDING ENDED" if elapsed_ms >= _spans[-1].y else "GHOST RECORDING UNAVAILABLE"
		return
	while _cursor + 1 < _ticks.size() and int(_ticks[_cursor + 1][0]) <= elapsed_ms:
		_cursor += 1
	var tick: Array = _ticks[_cursor]
	lane = float(tick[1])
	score_units = int(tick[2])
	distance = float(tick[3]) / 1000.0 if tick.size() == 4 else legacy_distance
	available = true
	if tick.size() == 3:
		cadence = 80.0 # Legacy records have no recorded distance; preserve their presentation.
		return
	if _cursor + 1 < _ticks.size() and int(_ticks[_cursor + 1][0]) <= span.y:
		var following: Array = _ticks[_cursor + 1]
		var interval := int(following[0]) - int(tick[0])
		cadence = _cadence(tick, following)
		var blend := clampf(float(elapsed_ms - int(tick[0])) / interval, 0, 1)
		distance = lerpf(distance, float(following[3]) / 1000.0, blend)
		if lane >= 0 and int(following[1]) >= 0: lane = lerpf(lane, float(following[1]), blend)
	elif _cursor > 0 and int(_ticks[_cursor - 1][0]) >= span.x:
		# A complete final sample gets its own measured cadence, not a stale render value.
		cadence = _cadence(_ticks[_cursor - 1], tick)


static func _cadence(a: Array, b: Array) -> float:
	return clampf(float(int(b[3]) - int(a[3])) / maxi(1, int(b[0]) - int(a[0])) / NeonRules.MAX_SPEED_MPS * NeonRules.MAX_CADENCE, 0, NeonRules.MAX_CADENCE)
