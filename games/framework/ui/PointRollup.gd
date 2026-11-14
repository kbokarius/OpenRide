class_name PointRollup
extends RefCounted
## Presentation only: a replaceable cubic ease-out, never an authority for saved scores.
## One instance per counter; retarget from the displayed value, without queued animations.
const GAIN_SECONDS := 0.72
const LOSS_SECONDS := 0.30
var value := 0.0
var target := 0
var _from := 0.0
var _elapsed := 0.0
var _duration := 0.0

func reset(points: int = 0) -> void:
	value = points
	target = points
	_from = points
	_elapsed = 0.0
	_duration = 0.0

func aim(points: int) -> void:
	if points == target: return
	target = points
	_from = value
	_elapsed = 0.0
	_duration = LOSS_SECONDS if points < value else GAIN_SECONDS

func advance(delta: float) -> int:
	if _duration > 0.0:
		_elapsed = minf(_duration, _elapsed + maxf(0.0, delta))
		var remaining := 1.0 - _elapsed / _duration
		value = lerpf(_from, float(target), 1.0 - remaining * remaining * remaining)
		if _elapsed >= _duration:
			value = target
			_duration = 0.0
	return roundi(value)
