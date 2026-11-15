class_name PointRollup
extends RefCounted
## Presentation-only critically damped follower. Retargeting preserves motion, without
## restarting a tween or changing authoritative points. Analytic integration is FPS stable.
const GAIN_RATE := 12.0
const LOSS_RATE := 18.0
var value := 0.0
var target := 0
var _velocity := 0.0

func reset(points: int = 0) -> void:
	value = points
	target = points
	_velocity = 0.0

func aim(points: int) -> void:
	target = points
	if _velocity * (target - value) < 0.0: _velocity = 0.0

func advance(delta: float) -> int:
	var dt := maxf(0.0, delta)
	var rate := LOSS_RATE if target < value else GAIN_RATE
	var error := value - target
	var decay := exp(-rate * dt)
	var step := (_velocity + rate * error) * dt
	var next := target + (error + step) * decay
	_velocity = (_velocity - rate * step) * decay
	# Clamp overshoot after a retarget; settling below a hundredth of a point is invisible.
	if (next - target) * error < 0.0 or (absf(next - target) < 0.01 and absf(_velocity) < 0.05):
		next = target
		_velocity = 0.0
	value = next
	return roundi(value)
