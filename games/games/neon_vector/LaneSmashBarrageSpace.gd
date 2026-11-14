class_name LaneSmashBarrageSpace
extends Node3D
## A single reusable attacker; analytic, world-fixed flight paths and bounded landing geometry.
const ENERGY := Color("7dffe0")
const DEPTH := 110.0
const ACTOR_SCALE := 7.0
var space: Node3D
var attacker: LaneSmashAttacker
var _dots: MultiMeshInstance3D
var _trail: MultiMeshInstance3D
var _orb: MultiMeshInstance3D
var _plasma: ShaderMaterial
var _zone: MeshInstance3D
var _zone_material: ShaderMaterial
var _shot_id := ""
var _source := Vector3.ZERO
var _target := Vector3.ZERO
var _control := Vector3.ZERO
var _up := Vector3.UP
var _frozen := false
var _impact_done := false
var _feedback: Dictionary = {}
var effects_count := 0

func _ready() -> void:
	attacker = LaneSmashAttacker.new()
	add_child(attacker)
	attacker.visible = false
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 12
	ball.rings = 6
	_dots = space._instances(ball, 40, NeonSpace._material(Color.WHITE, 1.5, true, true))
	_trail = space._instances(ball, 32, NeonSpace._material(Color.WHITE, 2.0, true, true))
	_plasma = ShaderMaterial.new()
	_plasma.shader = preload("res://games/neon_vector/barrage_plasma.gdshader")
	_orb = space._instances(ball, 2, _plasma)
	_zone_material = ShaderMaterial.new()
	_zone_material.shader = preload("res://games/neon_vector/barrage_zone.gdshader")
	_zone = space._mesh(ArrayMesh.new(), _zone_material, self)
	_hide()

func _hide() -> void:
	attacker.visible = false
	_zone.visible = false
	for pool in [_dots, _trail, _orb]: pool.multimesh.visible_instance_count = 0

func update_view(rules: NeonRules, _delta: float) -> void:
	var shot := rules.barrage.current_shot()
	if shot.is_empty():
		_hide()
		if space._warming: _warmup()
		return
	var now := rules.elapsed_ms
	var since_impact := (now - int(shot.impactMs)) / 1000.0
	if since_impact > 1.2:
		_hide()
		return
	if _shot_id != str(shot.shotId):
		_shot_id = str(shot.shotId)
		_target = space.pose(float(shot.targetMeters), 0, 0.12).origin
		_up = space.road_basis(float(shot.targetMeters)).y
		_zone.mesh = _landing_mesh(float(shot.targetMeters))
		_frozen = false
		_impact_done = false
		_feedback = {}
	var charge := clampf(float(now - int(shot.lockMs)) / LaneSmashBarrage.CHARGE_MS, 0, 1)
	var since_fire := (now - int(shot.fireMs)) / 1000.0
	var fade := smoothstep(0.0, 0.8, (now - int(shot.lockMs)) / 1000.0) * (1.0 - smoothstep(0.15, 1.3, since_fire))
	# Before the shot, the translocator holds its soldier above the road in screen space.
	# After launch, projectile coordinates are frozen independently of that visual rig.
	var actor_at := _actor_transform(float(rules.road_distance()), int(shot.slot))
	attacker.transform = actor_at
	attacker.animate(fade, now / 1000.0, since_fire)
	if since_fire < 0:
		_source = attacker.muzzle.global_position
		_control = _source.lerp(_target, 0.5) + _camera_at(space.distance).basis.y * 17.0
	elif not _frozen:
		# Reconstruct from the authoritative fire-distance snapshot, including captures/seeks.
		var saved_transform := attacker.transform
		attacker.transform = _actor_transform(float(shot.fireRiderMeters), int(shot.slot))
		attacker.animate(fade, int(shot.fireMs) / 1000.0, -1)
		_source = attacker.muzzle.global_position
		_control = _source.lerp(_target, 0.5) + _camera_at(float(shot.fireRiderMeters)).basis.y * 17.0
		attacker.transform = saved_transform
		attacker.animate(fade, now / 1000.0, since_fire)
		_frozen = true
	var flight := clampf(float(now - int(shot.fireMs)) / (LaneSmashBarrage.WARNING_MS - LaneSmashBarrage.CHARGE_MS), 0, 1)
	_zone.visible = true
	_zone_material.set_shader_parameter("progress", clampf(float(now - int(shot.lockMs)) / LaneSmashBarrage.WARNING_MS, 0, 1))
	_zone_material.set_shader_parameter("visibility", smoothstep(0.0, 0.5, (now - int(shot.lockMs)) / 1000.0) * (1.0 - smoothstep(0.25, 1.0, since_impact)))
	_zone_material.set_shader_parameter("detonation", (1.0 - smoothstep(0.0, 0.6, since_impact)) if since_impact >= 0 else 0.0)
	_plasma.set_shader_parameter("phase", now / 1000.0)
	var dot_alpha := (0.28 if since_fire < 0 else 0.14) * (1.0 - smoothstep(-0.2, 0.15, since_impact))
	for i in 40:
		var t := (i + 1) / 40.0
		var pos := curve(t)
		_dots.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.32), pos))
		_dots.multimesh.set_instance_color(i, Color(ENERGY, dot_alpha * (0.6 + 0.4 * sin(t * 38.0 - now * 0.003))))
	_dots.multimesh.visible_instance_count = 40 if since_impact < 0.15 else 0
	if since_fire < 0:
		_orb.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.3 + charge * 1.7)), _source))
		_orb.multimesh.set_instance_color(0, Color(1, 1, 1, fade))
		_orb.multimesh.visible_instance_count = 1
		_trail.multimesh.visible_instance_count = 0
	elif since_impact < 0:
		_orb.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.6), curve(flight)))
		_orb.multimesh.set_instance_color(0, Color.WHITE)
		_orb.multimesh.visible_instance_count = 1
		# A short actual flight-history tail makes motion legible without GPU trail support.
		for i in 32:
			var t := maxf(0, flight - i * 0.0024)
			var size := 0.80 * pow(1.0 - i / 32.0, 1.5)
			_trail.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), curve(t)))
			_trail.multimesh.set_instance_color(i, Color(ENERGY.lerp(Color.WHITE, 0.5), 0.8 * (1.0 - i / 32.0)))
		_trail.multimesh.visible_instance_count = 32
	else:
		_orb.multimesh.visible_instance_count = 0
		_trail.multimesh.visible_instance_count = 0
	if bool(shot.resolved) and not _impact_done:
		_impact_done = true
		effects_count += 1
		for lane_x in [-6.0, 0.0, 6.0]:
			space._explode(space.pose(float(shot.targetMeters), lane_x, 0.8).origin, ENERGY, 32, 2.6)
		_feedback = {"hit": shot.hit, "points": shot.points,
			"anchor": space.pose(space.distance + LaneSmashCyclist.FRONT_REACH, (rules.selected_lane - 2.5) * NeonSpace.LANE_WIDTH, 2.5).origin,
			"up": space.road_basis(space.distance).y}

func curve(t: float) -> Vector3:
	return (1.0 - t) * (1.0 - t) * _source + 2.0 * t * (1.0 - t) * _control + t * t * _target

func _warmup() -> void:
	# Draw tiny, nearly transparent samples beneath the intro overlay. Shader compilation
	# then happens before active riding, including on devices without a populated cache.
	attacker.transform = space.pose(space.distance + 10, 0, 0.15, Vector3.ONE * 0.03)
	attacker.animate(0.005, 0, -1)
	if _zone.mesh.get_surface_count() == 0:
		_zone.mesh = _landing_mesh(space.distance + 70)
	_zone.visible = true
	_zone_material.set_shader_parameter("visibility", 0.002)
	for pool in [_dots, _trail, _orb]:
		pool.multimesh.set_instance_transform(0, space.pose(space.distance + 12, 0, 0.1, Vector3.ONE * 0.04))
		pool.multimesh.set_instance_color(0, Color(1, 1, 1, 0.005))
		pool.multimesh.visible_instance_count = 1

func take_feedback() -> Dictionary:
	var result := _feedback
	_feedback = {}
	return result

func _camera_at(distance: float) -> Transform3D:
	var road: Transform3D = space.coaster.at(distance)
	var origin := road.origin + road.basis.z * 12.0 + road.basis.y * 6.0
	return Transform3D(Basis.IDENTITY, origin).looking_at(road.origin - road.basis.z * 34.0 + road.basis.y * 1.6, road.basis.y)

func _actor_transform(distance: float, slot: int) -> Transform3D:
	var cam := _camera_at(distance)
	var uv: Vector2 = LaneSmashBarrage.SCREEN_SLOTS[slot]
	var height := tan(deg_to_rad(68.0 * 0.5)) * DEPTH
	var center := cam * Vector3((uv.x * 2.0 - 1.0) * height * 16.0 / 9.0, (1.0 - uv.y * 2.0) * height, -DEPTH)
	var origin := center - cam.basis.y * 1.9 * ACTOR_SCALE
	var aim := origin.lerp(_target, 0.5) + cam.basis.y * 12.0
	return Transform3D(Basis.looking_at(aim - origin, cam.basis.y, true).scaled(Vector3.ONE * ACTOR_SCALE), origin)

func _landing_mesh(center: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 32
	for i in steps:
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var v := (i + corner.y) / steps
			var at := center - LaneSmashBarrage.HALF_LENGTH + v * LaneSmashBarrage.HALF_LENGTH * 2
			surface.set_uv(Vector2(corner.x, v))
			surface.set_normal(space.road_basis(at).y)
			surface.add_vertex(space.pose(at, (corner.x - 0.5) * 18.0, 0.08).origin)
	return surface.commit()
