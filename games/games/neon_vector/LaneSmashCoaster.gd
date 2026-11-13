class_name LaneSmashCoaster
extends RefCounted
## Distance-sampled route with continuous orientation through loops and barrel rolls.
## Shape never reads resistance or scoring lanes. Each sample advances exactly STEP metres.
const STEP := 2.0
var points := PackedVector3Array()
var frames: Array[Quaternion] = []
var reduced := false
var seed_value := 0

func build(length: float, course_seed: int, reduced_motion: bool) -> void:
	reduced = reduced_motion
	seed_value = course_seed
	points.clear()
	frames.clear()
	var point := Vector3.ZERO
	var count := ceili((length + 400.0) / STEP) + 1
	for i in count:
		points.append(point)
		frames.append(_orientation(i * STEP).get_rotation_quaternion())
		# Midpoint integration follows the tangent even through a vertical/inverted span.
		point += -_orientation((i + 0.5) * STEP).z * STEP

func _orientation(s: float) -> Basis:
	var phase := fposmod(s, 1800.0)
	var offset := float(seed_value % 97) * 0.01
	var yaw := 0.24 * sin(s / 155.0 + offset) + 0.13 * sin(s / 61.0)
	var pitch := 0.06 * sin(s / 83.0)
	var roll := 0.16 * sin(s / 91.0)
	if not reduced:
		if phase >= 100 and phase < 700:
			pitch += TAU * smoothstep(100.0, 700.0, phase)
		elif phase >= 700:
			pitch += TAU
		if phase >= 760 and phase < 1180:
			var t := (phase - 760.0) / 420.0
			roll += TAU * smoothstep(0.0, 1.0, t)
			pitch += sin(t * TAU) * pow(sin(t * PI), 2) * 0.65
		elif phase >= 1180:
			roll += TAU
		if phase >= 1220:
			pitch += TAU * smoothstep(1220.0, 1800.0, phase)
	else:
		yaw *= 0.5
		pitch *= 0.5
		roll *= 0.4
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.FORWARD, roll)

func at(s: float) -> Transform3D:
	if points.size() < 2: return Transform3D(Basis.IDENTITY, Vector3(0, 0, -s))
	if s < 0: return Transform3D(Basis(frames[0]), points[0] - Basis(frames[0]).z * s)
	var f := clampf(s / STEP, 0, points.size() - 1.001)
	var i := floori(f)
	var t := f - i
	return Transform3D(Basis(frames[i].slerp(frames[i + 1], t)), points[i].lerp(points[i + 1], t))
