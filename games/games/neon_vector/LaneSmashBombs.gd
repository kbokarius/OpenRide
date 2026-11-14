class_name LaneSmashBombs
extends Node3D
## Pooled, clearly red hazards. The rules own contact and penalties, not render frames.
const COLOR := Color("ff5368")
const CAPACITY := 12
var space: Node3D
var _shells: MultiMeshInstance3D
var _bands: MultiMeshInstance3D
var _fuses: MultiMeshInstance3D
var feedback_cursor := 0

func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.72
	sphere.height = 1.44
	sphere.radial_segments = 20
	sphere.rings = 10
	_shells = space._instances(sphere, CAPACITY, NeonSpace._material(Color.WHITE, 0.12, true, true))
	var band := TorusMesh.new()
	band.inner_radius = 0.70
	band.outer_radius = 0.78
	band.rings = 32
	band.ring_segments = 6
	_bands = space._instances(band, CAPACITY * 2, NeonSpace._material(Color.WHITE, 1.8, true, true))
	var fuse := CylinderMesh.new()
	fuse.top_radius = 0.11
	fuse.bottom_radius = 0.18
	fuse.height = 0.4
	fuse.radial_segments = 8
	_fuses = space._instances(fuse, CAPACITY, NeonSpace._material(Color.WHITE, 1.5, true, true))

func update_view(rules: NeonRules) -> void:
	if rules._hazard_cursor < feedback_cursor: feedback_cursor = 0
	var hazards: Array = rules.course.get("hazards", [])
	var n := 0
	var now := rules.road_time_ms()
	for i in range(maxi(0, rules._hazard_cursor - 1), hazards.size()):
		var hazard: Dictionary = hazards[i]
		if int(hazard.hitMs) > now + 16000: break
		if int(hazard.hitMs) < now - 1500 or bool(rules.hazard_states[i].hit): continue
		var anchor := int(hazard.hitMs) / 1000.0 * rules.road_speed_scale() + LaneSmashCyclist.FRONT_REACH + 0.72
		if anchor > space.portal_distance - 20 or n >= CAPACITY: break
		var alpha := rules.barrage.normal_alpha(rules.elapsed_ms) * smoothstep(-16.0, -2.0, anchor - space.distance) * (1.0 - smoothstep(space.portal_distance - 55, space.portal_distance - 20, anchor))
		var pose: Transform3D = space.pose(anchor, (int(hazard.laneIndex) - 2.5) * NeonSpace.LANE_WIDTH, 0.74)
		_shells.multimesh.set_instance_transform(n, pose)
		_shells.multimesh.set_instance_color(n, Color(0.11, 0.025, 0.035, alpha))
		for ring in 2:
			var tr := pose
			tr.basis = tr.basis * Basis(Vector3.RIGHT if ring == 0 else Vector3.FORWARD, PI / 2) * Basis(Vector3.UP, rules.elapsed_ms * 0.001)
			_bands.multimesh.set_instance_transform(n * 2 + ring, tr)
			_bands.multimesh.set_instance_color(n * 2 + ring, Color(COLOR, alpha * (0.78 + 0.22 * sin(rules.elapsed_ms * 0.005))))
		var top := pose
		top.origin += pose.basis.y * 0.87
		_fuses.multimesh.set_instance_transform(n, top)
		_fuses.multimesh.set_instance_color(n, Color("ffe5ac", alpha))
		n += 1
	_shells.multimesh.visible_instance_count = n
	_bands.multimesh.visible_instance_count = n * 2
	_fuses.multimesh.visible_instance_count = n

func take_feedback(rules: NeonRules) -> Dictionary:
	while feedback_cursor < rules._hazard_cursor:
		var index := feedback_cursor
		feedback_cursor += 1
		if not bool(rules.hazard_states[index].hit): continue
		var hazard: Dictionary = rules.course.hazards[index]
		var anchor := int(hazard.hitMs) / 1000.0 * rules.road_speed_scale() + LaneSmashCyclist.FRONT_REACH + 0.72
		var point: Vector3 = space.pose(anchor, (int(hazard.laneIndex) - 2.5) * NeonSpace.LANE_WIDTH, 0.8).origin
		space._explode(point, COLOR, 60, 2.5)
		return {"points": int(rules.hazard_states[index].penaltyUnits) / NeonRules.UNIT, "anchor": point + space.road_basis(anchor).y * 2.0, "up": space.road_basis(anchor).y}
	return {}
