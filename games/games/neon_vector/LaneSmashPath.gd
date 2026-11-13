class_name LaneSmashPath
extends RefCounted
## Fixed, distance-based 3D route. Its saved control points never move during a ride.
const VERSION := 1
const MIN_SPAN := 480
const MAX_SPAN := 800
var nodes: Array = []
var opacity := 0.74

static func generate(seed_value: int, length: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x4C534D
	var points: Array = [{"distanceMeters": 0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0}, {"distanceMeters": 80, "yaw": rng.randf_range(-0.08, 0.08), "pitch": 0.02, "roll": 0.0}]
	var distance := 80
	var yaw := float(points[-1].yaw)
	var pitch_turns := 0.0
	var roll_turns := 0.0
	var count := 0
	while distance <= length + 900:
		var kind: String = "loop" if count == 0 else ["turn", "roll", "climb", "loop", "twist", "glide"][rng.randi_range(0, 5)]
		distance += rng.randi_range(MIN_SPAN, MAX_SPAN)
		var pitch := pitch_turns
		var roll := roll_turns
		if kind == "loop":
			pitch_turns += TAU
			pitch = pitch_turns
			yaw += rng.randf_range(-0.08, 0.08)
		elif kind in ["roll", "twist"]:
			roll_turns += TAU * (-1.0 if rng.randi_range(0, 1) == 0 else 1.0)
			roll = roll_turns
			yaw += rng.randf_range(-0.4, 0.4)
			pitch += rng.randf_range(-0.25, 0.25) if kind == "twist" else 0.0
		else:
			yaw += rng.randf_range(0.4, 0.9) * (-1.0 if rng.randi_range(0, 1) == 0 else 1.0)
			pitch += rng.randf_range(-0.25, 0.25)
			roll += rng.randf_range(-0.4, 0.4)
		points.append({"distanceMeters": distance, "yaw": yaw, "pitch": pitch, "roll": roll})
		count += 1
	return {"version": VERSION, "roadOpacity": 0.74, "path": points}

static func valid(data: Variant, length: float) -> bool:
	if not data is Dictionary or data.get("version") != VERSION: return false
	if not _number(data.get("roadOpacity")) or float(data.roadOpacity) < 0.5 or float(data.roadOpacity) > 1: return false
	if not data.get("path") is Array or data.path.size() < 3 or data.path.size() > 256: return false
	var previous := -1.0
	for i in data.path.size():
		var node: Variant = data.path[i]
		if not node is Dictionary: return false
		for field in ["distanceMeters", "yaw", "pitch", "roll"]:
			if not _number(node.get(field)): return false
		var at := float(node.distanceMeters)
		if i == 0 and at != 0: return false
		if i == 1 and at < 80: return false
		if i > 1 and at - previous < MIN_SPAN: return false
		previous = at
	return previous >= length

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func load_config(data: Dictionary, seed_value: int, length: float) -> void:
	if not valid(data, length): data = generate(seed_value, length)
	nodes = data.path.duplicate(true)
	opacity = float(data.roadOpacity)

func orientation(distance: float, reduced: bool) -> Basis:
	var index := 0
	while index + 2 < nodes.size() and distance >= float(nodes[index + 1].distanceMeters): index += 1
	var a: Dictionary = nodes[index]
	var b: Dictionary = nodes[index + 1]
	var t := clampf((distance - float(a.distanceMeters)) / (float(b.distanceMeters) - float(a.distanceMeters)), 0, 1)
	var ease := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	var yaw := lerpf(float(a.yaw), float(b.yaw), ease)
	var pitch := lerpf(float(a.pitch), float(b.pitch), ease)
	var roll := lerpf(float(a.roll), float(b.roll), ease)
	if reduced:
		yaw *= 0.4
		pitch = sin(pitch) * 0.08
		roll = sin(roll) * 0.06
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.FORWARD, roll)
