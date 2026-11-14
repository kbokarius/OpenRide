class_name LaneSmashCoaster
extends RefCounted
## Distance-sampled route with continuous orientation through loops and barrel rolls.
## Shape never reads resistance or scoring lanes. Each sample advances exactly STEP metres.
const STEP := 2.0
var points := PackedVector3Array()
var frames: Array[Quaternion] = []
var reduced := false
var seed_value := 0
var route := LaneSmashPath.new()
## World metres drawn for each road metre. Distances given to `at()` stay in road metres (the
## rules' unit, which scoring and course timing use); only the positions it returns are spread
## out, so the ride looks `stretch` times faster without changing a single rule. The route
## turns through the same angles over the longer distance, so its curves are that much wider.
var stretch := 1.0

func build(length: float, course_seed: int, reduced_motion: bool, presentation: Dictionary = {}) -> void:
	# Bound allocations even for callers outside the validated ride path.
	length = clampf(length, 0, 33000) if is_finite(length) else 0.0
	reduced = reduced_motion
	seed_value = course_seed
	route.load_config(presentation, course_seed, length)
	points.clear()
	frames.clear()
	var point := Vector3.ZERO
	var count := ceili((length + 400.0) / STEP) + 1
	for i in count:
		points.append(point)
		frames.append(_orientation(i * STEP).get_rotation_quaternion())
		# Midpoint integration follows the tangent even through a vertical/inverted span.
		point += -_orientation((i + 0.5) * STEP).z * STEP * stretch

func _orientation(s: float) -> Basis:
	return route.orientation(s, reduced)

func at(s: float) -> Transform3D:
	if points.size() < 2: return Transform3D(Basis.IDENTITY, Vector3(0, 0, -s * stretch))
	if s < 0: return Transform3D(Basis(frames[0]), points[0] - Basis(frames[0]).z * s * stretch)
	var f := clampf(s / STEP, 0, points.size() - 1.001)
	var i := floori(f)
	var t := f - i
	return Transform3D(Basis(frames[i].slerp(frames[i + 1], t)), points[i].lerp(points[i + 1], t))
