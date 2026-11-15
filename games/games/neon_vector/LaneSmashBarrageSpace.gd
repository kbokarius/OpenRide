class_name LaneSmashBarrageSpace
extends Node3D
## A single reusable attacker; analytic, world-fixed flight paths and bounded landing geometry.
const ENERGY := LaneSmashLook.PLASMA  ## hostile energy: never the mint of a cadence target
const DEPTH := 110.0
const ACTOR_SCALE := 7.0
## The actor is a foreground rig, with the same projection as its world-space launch rig.
## This keeps road loops/gantries from hiding him without turning off his own depth testing.
const FOREGROUND_DEPTH := 8.0
const PROJECTILE_DEPTH := 4.0  # the bomb and its tail must draw in front of the foreground shooter
const DISPLAY_SLOTS := [Vector2(0.23, 0.42), Vector2(0.80, 0.42), Vector2(0.30, 0.40), Vector2(0.70, 0.40), Vector2(0.18, 0.44), Vector2(0.82, 0.44)]
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
var _rapid_started := false
var _impact_done := false
var _feedback_done := false
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
	var soft := LaneSmashLook.emissive(true, 2.0)
	soft.set_shader_parameter("soft", 0.0)
	_dots = space._instances(ball, 40, soft)
	var tail := LaneSmashLook.emissive(true, 2.6)
	tail.set_shader_parameter("soft", 0.0)
	_trail = space._instances(ball, 32, tail)
	_plasma = ShaderMaterial.new()
	_plasma.shader = preload("res://games/neon_vector/barrage_plasma.gdshader")
	_plasma.set_shader_parameter("tint", Color(ENERGY, 1.0))
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
		_target = space.pose(float(shot.get("originalTargetMeters", shot.targetMeters)), 0, 0.12).origin
		_up = space.road_basis(float(shot.targetMeters)).y
		_zone.mesh = _landing_mesh(float(shot.targetMeters))
		_frozen = false
		_rapid_started = false
		_impact_done = false
		_feedback_done = false
		_feedback = {}
	var charge := clampf(float(now - int(shot.lockMs)) / LaneSmashBarrage.CHARGE_MS, 0, 1)
	var since_fire := (now - int(shot.fireMs)) / 1000.0
	# Keep the shooter solid for the entire nine-second flight and the impact. Previously
	# he faded after firing, leaving most of the bomb's flight with no visible source.
	var since_lock := (now - int(shot.lockMs)) / 1000.0
	var fade := smoothstep(0.0, 1.4, since_lock) * (1.0 - smoothstep(0.3, 1.2, since_impact))
	# Before the shot, the translocator holds its soldier above the road in screen space.
	# After launch, projectile coordinates are frozen independently of that visual rig.
	var actor_at := _actor_transform(float(rules.road_distance()), int(shot.slot))
	attacker.transform = _foreground_transform(actor_at, space.distance)
	attacker.animate(fade, now / 1000.0, since_fire, charge if since_fire < 0 else 0.0)
	if since_fire < 0:
		_source = _world_muzzle(actor_at)
		_control = _source.lerp(_target, 0.5) + _camera_at(space.distance).basis.y * 17.0
	elif not _frozen:
		# Reconstruct from the authoritative fire-distance snapshot, including captures/seeks.
		attacker.animate(fade, int(shot.fireMs) / 1000.0, -1)
		_source = _world_muzzle(_actor_transform(float(shot.fireRiderMeters), int(shot.slot)))
		_control = _source.lerp(_target, 0.5) + _camera_at(float(shot.fireRiderMeters)).basis.y * 17.0
		attacker.animate(fade, now / 1000.0, since_fire)
		_frozen = true
	if shot.get("rapid", false) and not _rapid_started:
		# Continue from the ball's current arc point; the fast drop never teleports.
		_source = curve(float(shot.rapidProgress))
		var lateral := (int(shot.rapidLaneIndex) - 2.5) * NeonSpace.LANE_WIDTH
		_target = space.pose(float(shot.targetMeters), lateral, 0.12).origin
		_up = space.road_basis(float(shot.targetMeters)).y
		_control = _source.lerp(_target, 0.5) + _up * 4.0
		_zone.mesh = _landing_mesh(float(shot.targetMeters), int(shot.rapidLaneIndex))
		_rapid_started = true
	var flight := flight_progress(float(now - int(shot.fireMs)) / (LaneSmashBarrage.WARNING_MS - LaneSmashBarrage.CHARGE_MS))
	if _rapid_started: flight = clampf(float(now - int(shot.rapidMs)) / maxi(1, int(shot.impactMs) - int(shot.rapidMs)), 0, 1)
	_zone.visible = true
	_zone_material.set_shader_parameter("progress", clampf(float(now - int(shot.lockMs)) / LaneSmashBarrage.WARNING_MS, 0, 1))
	_zone_material.set_shader_parameter("visibility", smoothstep(0.0, 0.5, (now - int(shot.lockMs)) / 1000.0) * (1.0 - smoothstep(0.25, 1.0, since_impact)))
	_zone_material.set_shader_parameter("detonation", (1.0 - smoothstep(0.0, 0.6, since_impact)) if since_impact >= 0 else 0.0)
	_plasma.set_shader_parameter("phase", now / 1000.0)
	var dot_alpha := lerpf(0.28, 0.14, smoothstep(-0.2, 0.6, since_fire)) * smoothstep(0.2, 1.4, since_lock) * (1.0 - smoothstep(-0.2, 0.15, since_impact))
	for i in 40:
		var t := (i + 1) / 40.0
		var pos := curve(t)
		_dots.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.32), pos))
		_dots.multimesh.set_instance_color(i, Color(ENERGY, dot_alpha * (0.6 + 0.4 * sin(t * 38.0 - now * 0.003))))
	_dots.multimesh.visible_instance_count = 40 if since_impact < 0.15 else 0
	if since_fire < 0:
		_orb.multimesh.set_instance_transform(0, _projectile_transform(_source, 0.3 + charge * 1.7))
		_orb.multimesh.set_instance_color(0, Color(1, 1, 1, fade))
		_orb.multimesh.visible_instance_count = 1
		_trail.multimesh.visible_instance_count = 0
	elif since_impact < 0:
		_orb.multimesh.set_instance_transform(0, _projectile_transform(curve(flight), 1.6))
		_orb.multimesh.set_instance_color(0, Color.WHITE)
		_orb.multimesh.visible_instance_count = 1
		# A short actual flight-history tail makes motion legible without GPU trail support.
		for i in 32:
			var t := maxf(0, flight - i * 0.0024)
			var size := 0.80 * pow(1.0 - i / 32.0, 1.5)
			_trail.multimesh.set_instance_transform(i, _projectile_transform(curve(t), size))
			_trail.multimesh.set_instance_color(i, Color(ENERGY.lerp(Color.WHITE, 0.5), 0.8 * (1.0 - i / 32.0)))
		_trail.multimesh.visible_instance_count = 32
	else:
		_orb.multimesh.visible_instance_count = 0
		_trail.multimesh.visible_instance_count = 0
	if bool(shot.resolved) and now >= int(shot.impactMs) and not _impact_done:
		_impact_done = true
		effects_count += 1
		var ground: Basis = space.road_basis(float(shot.targetMeters))
		if shot.get("rapid", false):
			var lateral := (int(shot.rapidLaneIndex) - 2.5) * NeonSpace.LANE_WIDTH
			var point: Vector3 = space.pose(float(shot.targetMeters), lateral, 0.7).origin
			space._explode(point, ENERGY, 32, 1.4)
			space.fx.blast(point, ground, ENERGY, 2.4, 0.55)
			space.fx.beam(point, ground, ENERGY, 8.0, 0.45)
		else:
			for lane_x in [-6.0, 0.0, 6.0]:
				space._explode(space.pose(float(shot.targetMeters), lane_x, 0.8).origin, ENERGY, 32, 2.6)
				space.fx.blast(space.pose(float(shot.targetMeters) + lane_x * 0.6, lane_x, 1.5).origin, ground, ENERGY.lerp(LaneSmashLook.DANGER, 0.3), 7.5 if lane_x == 0.0 else 5.5, 0.85)
			space.fx.beam(space.pose(float(shot.targetMeters), 0, 0.1).origin, ground, ENERGY, 26.0, 0.9)
		# The knock is felt hardest inside the blast and only faintly from a safe distance.
		space.shake(0.9 if bool(shot.hit) else 0.3)
	if bool(shot.resolved) and not _feedback_done:
		_feedback_done = true
		_feedback = {"hit": shot.hit, "points": shot.points,
			"anchor": space.pose(space.distance + LaneSmashBike.FRONT_REACH / NeonSpace.STRETCH, (rules.selected_lane - 2.5) * NeonSpace.LANE_WIDTH, 2.5).origin,
			"up": space.road_basis(space.distance).y}

func curve(t: float) -> Vector3:
	return (1.0 - t) * (1.0 - t) * _source + 2.0 * t * (1.0 - t) * _control + t * t * _target


static func flight_progress(phase: float) -> float:
	# Launch decisively out of the muzzle instead of hovering beside the pacing shooter.
	# This only changes travel along the fixed arc, not the nine-second impact time. Its
	# derivative stays positive (at least 0.6), so it cannot backtrack or stall near landing.
	return LaneSmashBarrage.flight_progress(phase)

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
	return space.camera_pose(distance)

func _actor_transform(distance: float, slot: int) -> Transform3D:
	var cam := _camera_at(distance)
	# Display positions live outside the saved rules: keep every model below the HUD and
	# either side of its central steering prompt, including older course snapshots.
	var uv: Vector2 = DISPLAY_SLOTS[slot]
	var height := tan(deg_to_rad(NeonSpace.CAMERA_FOV * 0.5)) * DEPTH
	var viewport_size := space.get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(1.0, viewport_size.y)
	var center := cam * Vector3((uv.x * 2.0 - 1.0) * height * aspect, (1.0 - uv.y * 2.0) * height, -DEPTH)
	var origin := center - cam.basis.y * 1.9 * ACTOR_SCALE
	# Face the rider in a readable three-quarter pose. Aiming the entire body at the curved
	# landing zone could turn it edge-on, upside down or partly outside the screen.
	var facing := cam.basis * Vector3((0.5 - uv.x) * 1.6, -0.08, 1.0).normalized()
	return Transform3D(Basis.looking_at(facing, cam.basis.y, true).scaled(Vector3.ONE * ACTOR_SCALE), origin)


func _foreground_transform(world_pose: Transform3D, distance: float) -> Transform3D:
	var camera_origin := _camera_at(distance).origin
	var ratio := FOREGROUND_DEPTH / DEPTH
	return Transform3D(world_pose.basis.scaled(Vector3.ONE * ratio), camera_origin + (world_pose.origin - camera_origin) * ratio)


func _world_muzzle(world_pose: Transform3D) -> Vector3:
	# Muzzle animation is local to the same model in both rigs. Only the visible model is
	# brought forward: the ball's flight retains a world-space source and fixed target.
	return world_pose * (attacker.upper.transform * attacker.muzzle.position)


func _projectile_transform(point: Vector3, radius: float) -> Transform3D:
	# Preserve the fixed arc's screen position and apparent size, but draw it ahead of the
	# foreground actor. Otherwise the newly fired ball passes behind his near-depth torso.
	# Use the live camera (including shake) so this never nudges the ball sideways.
	var cam: Transform3D = space.camera.global_transform
	var depth := -(cam.affine_inverse() * point).z
	var ratio := minf(1.0, PROJECTILE_DEPTH / depth) if depth > 0.0 else 1.0
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * radius * ratio), cam.origin + (point - cam.origin) * ratio)

func _landing_mesh(center: float, lane := -1) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 32
	for i in steps:
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var v := (i + corner.y) / steps
			var at := center - LaneSmashBarrage.HALF_LENGTH + v * LaneSmashBarrage.HALF_LENGTH * 2
			surface.set_uv(Vector2(corner.x, v))
			surface.set_normal(space.road_basis(at).y)
			var lateral := (lane - 2.5) * NeonSpace.LANE_WIDTH if lane >= 0 else 0.0
			var width := NeonSpace.LANE_WIDTH if lane >= 0 else 6.0 * NeonSpace.LANE_WIDTH
			surface.add_vertex(space.pose(at, lateral + (corner.x - 0.5) * width, 0.08).origin)
	return surface.commit()
