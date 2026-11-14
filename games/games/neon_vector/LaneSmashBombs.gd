class_name LaneSmashBombs
extends Node3D
## Pooled road mines: a dark spiked core with red warning lamps, a ring of light on the deck
## under each and a slow menacing turn. The rules own contact and penalties, not render frames.
const COLOR := LaneSmashLook.DANGER
const CAPACITY := 12
var space: Node3D
var _mines: MultiMeshInstance3D
var _rings: MultiMeshInstance3D
var _pools: MultiMeshInstance3D
var _material: ShaderMaterial
var feedback_cursor := 0

func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://games/neon_vector/mine.gdshader")
	_material.set_shader_parameter("accent", COLOR)
	var ring_material := ShaderMaterial.new()
	ring_material.shader = preload("res://games/neon_vector/fx_ring.gdshader")
	_pools = space._instances(NeonSpace._floor_card(), CAPACITY, LaneSmashLook.emissive(true, 1.0))
	_rings = space._instances(NeonSpace._floor_card(), CAPACITY, ring_material)
	_mines = space._instances(mine_mesh(), CAPACITY, _material)

func update_view(rules: NeonRules) -> void:
	if rules._hazard_cursor < feedback_cursor: feedback_cursor = 0
	var hazards: Array = rules.course.get("hazards", [])
	var n := 0
	var now := rules.road_time_ms()
	var blink := 0.5 + 0.5 * sin(rules.elapsed_ms * 0.009)
	_material.set_shader_parameter("blink", blink)
	for i in range(maxi(0, rules._hazard_cursor - 1), hazards.size()):
		var hazard: Dictionary = hazards[i]
		if int(hazard.hitMs) > now + 16000: break
		if int(hazard.hitMs) < now - 1500 or bool(rules.hazard_states[i].hit): continue
		var anchor := int(hazard.hitMs) / 1000.0 * rules.road_speed_scale() + LaneSmashBike.FRONT_REACH + 0.72
		if anchor > space.portal_distance - 20 or n >= CAPACITY: break
		var alpha := rules.barrage.normal_alpha(rules.elapsed_ms) * smoothstep(-16.0, -2.0, anchor - space.distance) * (1.0 - smoothstep(space.portal_distance - 55, space.portal_distance - 20, anchor))
		var lateral := (int(hazard.laneIndex) - 2.5) * NeonSpace.LANE_WIDTH
		var pose: Transform3D = space.pose(anchor, lateral, 0.74)
		# A slow turn and a slight bob; the collision anchor itself never moves.
		pose.basis = pose.basis * Basis(Vector3.UP, rules.elapsed_ms * 0.0011 + i)
		pose.origin += pose.basis.y * sin(rules.elapsed_ms * 0.003 + i) * 0.05
		_mines.multimesh.set_instance_transform(n, pose)
		_mines.multimesh.set_instance_color(n, Color(1, 1, 1, alpha))
		var pulse := 1.0 + 0.12 * blink
		_rings.multimesh.set_instance_transform(n, space.pose(anchor, lateral, 0.05, Vector3(2.9 * pulse, 1.0, 2.9 * pulse)))
		_rings.multimesh.set_instance_color(n, Color(COLOR, alpha * (0.55 + 0.35 * blink)))
		_pools.multimesh.set_instance_transform(n, space.pose(anchor, lateral, 0.04, Vector3(4.2, 1.0, 4.2)))
		_pools.multimesh.set_instance_color(n, Color(COLOR, alpha * (0.22 + 0.16 * blink)))
		n += 1
	if n == 0 and space._warming:
		# Compile the mine's shaders behind the intro rather than at the first mine.
		_mines.multimesh.set_instance_transform(0, space.pose(space.distance + 9, -3.0, 0.2, Vector3.ONE * 0.03))
		_mines.multimesh.set_instance_color(0, Color(1, 1, 1, 0.01))
		for pool in [_rings, _pools]:
			pool.multimesh.set_instance_transform(0, space.pose(space.distance + 9, -3.0, 0.05, Vector3.ONE * 0.03))
			pool.multimesh.set_instance_color(0, Color(1, 1, 1, 0.01))
		n = 1
	_mines.multimesh.visible_instance_count = n
	_rings.multimesh.visible_instance_count = n
	_pools.multimesh.visible_instance_count = n

func take_feedback(rules: NeonRules) -> Dictionary:
	while feedback_cursor < rules._hazard_cursor:
		var index := feedback_cursor
		feedback_cursor += 1
		if not bool(rules.hazard_states[index].hit): continue
		var hazard: Dictionary = rules.course.hazards[index]
		var anchor := int(hazard.hitMs) / 1000.0 * rules.road_speed_scale() + LaneSmashBike.FRONT_REACH + 0.72
		var point: Vector3 = space.pose(anchor, (int(hazard.laneIndex) - 2.5) * NeonSpace.LANE_WIDTH, 0.8).origin
		space._explode(point, COLOR, 60, 2.5)
		space.fx.blast(point, space.road_basis(anchor), Color(1.0, 0.36, 0.16), 4.2, 0.6)
		space.shake(0.6)
		return {"points": int(rules.hazard_states[index].penaltyUnits) / NeonRules.UNIT, "anchor": point + space.road_basis(anchor).y * 2.0, "up": space.road_basis(anchor).y}
	return {}

## The mine, at its real radius (0.72 m): a dark faceted core, six spikes, a lit equator and lamps.
static func mine_mesh() -> ArrayMesh:
	var kit := MeshKit3D.new()
	kit.flags = true
	kit.outline = 0.0
	kit.glow = 0.0
	var hull := Color(0.085, 0.07, 0.085, 1.0)
	kit.add(MeshKit3D.sphere(0.52, 12, 6), Transform3D.IDENTITY, hull)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		kit.add(MeshKit3D.cylinder(0.0, 0.13, 1.0, 6), MeshKit3D.between(axis * 0.44, axis * 0.78), hull.lightened(0.18))
		kit.add(MeshKit3D.cylinder(0.17, 0.17, 0.06, 8), MeshKit3D.between(axis * 0.47, axis * 0.53), hull.lightened(0.30))
	kit.outline = 1.0
	kit.glow = 1.0
	kit.add(MeshKit3D.torus(0.50, 0.56, 24, 5), Transform3D.IDENTITY, Color.WHITE)
	kit.add(MeshKit3D.torus(0.50, 0.545, 24, 5), MeshKit3D.xf(Vector3.ZERO, Vector3(90, 0, 0)), Color.WHITE)
	for diagonal: Vector3 in [Vector3(1, 1, 1), Vector3(-1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1), Vector3(1, -1, -1), Vector3(-1, -1, -1)]:
		kit.add(MeshKit3D.sphere(0.075, 6, 3), MeshKit3D.xf(diagonal.normalized() * 0.52), Color.WHITE)
	return kit.commit()
