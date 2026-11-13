class_name LaneSmashSections
extends Node3D
## Bounded, world-anchored cadence beds and output-reactive power zones.
const SHADER := preload("res://games/neon_vector/lane_section.gdshader")
var space: Node3D
var zones := {}
var flow := 0.0
var _route_id := ""

func update_view(rules: NeonRules, delta: float, rider_lane: float) -> void:
	if _route_id != space._terrain_id:
		for zone: Dictionary in zones.values(): zone.root.queue_free()
		zones.clear()
		_route_id = space._terrain_id
	flow += delta * (0.25 + float(rules.latest.get("cadence", 0)) / 70.0)
	var now := rules.road_time_ms()
	var needed := {}
	for i in range(maxi(0, rules._event_cursor - 1), rules.course.events.size()):
		var event: Dictionary = rules.course.events[i]
		if int(event.startMs) > now + 16000: break
		if event.type not in ["hold", "burst"] or int(event.endMs) < now - 1800: continue
		var key := str(event.eventId)
		needed[key] = true
		if not zones.has(key): zones[key] = _make_zone(event)
		var zone: Dictionary = zones[key]
		var state: Dictionary = rules.event_states[i]
		var active := now >= int(event.startMs) and now < int(event.endMs)
		var eligible := active and absf(rider_lane - int(event.laneIndex)) < 0.38
		var watts := float(rules.latest.get("power", 0)) if eligible else 0.0
		var intensity := clampf(watts / rules.reference_power, 0, 2.5)
		var target_joules := rules.reference_power * (int(event.endMs) - int(event.startMs)) / 1000.0
		var energy_ratio := float(state.energyMilliJoules) / maxf(1.0, target_joules * 1000.0)
		zone.charge = lerpf(float(zone.charge), clampf(energy_ratio, 0, 1), 1.0 - exp(-delta * 8.0))
		zone.intensity = lerpf(float(zone.intensity), intensity, 1.0 - exp(-delta * 6.0))
		zone.material.set_shader_parameter("charge", zone.charge)
		zone.material.set_shader_parameter("intensity", zone.intensity)
		zone.material.set_shader_parameter("flow", flow)
		zone.material.set_shader_parameter("road_end", space.portal_distance - 21.0)
		zone.material.set_shader_parameter("visible_alpha", 1.0 - smoothstep(float(event.endMs), float(event.endMs) + 1400.0, now))
		if event.type == "burst":
			var gate: MultiMeshInstance3D = zone.gate
			gate.visible = not bool(zone.hit) and float(zone.finish) < space.portal_distance - 22.0
			for ring in 5:
				var size := (0.26 + float(zone.charge) * 0.74) * (1.0 - ring * 0.14)
				var tr: Transform3D = space.pose(float(zone.finish), (int(event.laneIndex) - 2.5) * NeonSpace.LANE_WIDTH, 0.05)
				tr.basis = tr.basis.scaled_local(Vector3(size, size, 1.0))
				gate.multimesh.set_instance_transform(ring, tr)
				var color := NeonSpace.VIOLET.lerp(Color("d2faff"), clampf(float(zone.intensity) * 0.25 + float(zone.charge) * 0.25, 0, 0.85))
				color.a = (0.5 + float(zone.charge) * 0.5) * (0.75 + 0.25 * sin(flow * 3.0 - ring)) * (1.0 - smoothstep(space.portal_distance - 48.0, space.portal_distance - 22.0, float(zone.finish)))
				gate.multimesh.set_instance_color(ring, color)
			if not bool(zone.hit) and now >= int(event.endMs) and absf(rider_lane - int(event.laneIndex)) < 0.38:
				zone.hit = true
				gate.visible = false
				if int(state.scoreUnits) <= 0: space._explode(space.pose(float(zone.finish), (int(event.laneIndex) - 2.5) * NeonSpace.LANE_WIDTH, 1.2).origin, NeonSpace.VIOLET)
	for key in zones.keys():
		if not needed.has(key):
			zones[key].root.queue_free()
			zones.erase(key)

func _make_zone(event: Dictionary) -> Dictionary:
	var holder := Node3D.new()
	add_child(holder)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", NeonSpace.GREEN if event.type == "hold" else NeonSpace.VIOLET)
	material.set_shader_parameter("power_zone", 1.0 if event.type == "burst" else 0.0)
	var start: float = int(event.startMs) / 1000.0 * space._unit_speed + LaneSmashCyclist.FRONT_REACH + 1.0
	var finish: float = space.finish_distance(str(event.type), int(event.endMs))
	var floor_finish: float = finish + (1.0 if event.type == "hold" else 0.1)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := ceili((floor_finish - start) / 1.5)
	var lane_x := (int(event.laneIndex) - 2.5) * NeonSpace.LANE_WIDTH
	for i in steps:
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var v := (i + corner.y) / float(steps)
			var s := lerpf(start, floor_finish, v)
			surface.set_uv(Vector2(corner.x, v))
			surface.set_uv2(Vector2(s, 0))
			surface.set_normal(space.road_basis(s).y)
			surface.add_vertex(space.pose(s, lane_x + (corner.x - 0.5) * 2.72, 0.045).origin)
	var bed := MeshInstance3D.new()
	bed.mesh = surface.commit()
	bed.material_override = material
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(bed)
	var result := {"root": holder, "material": material, "finish": finish, "hit": false, "charge": 0.0, "intensity": 0.0}
	if event.type == "burst":
		var gate := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = _triangle()
		multi.instance_count = 5
		gate.multimesh = multi
		gate.material_override = NeonSpace._material(Color.WHITE, 1.1, true, true)
		gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(gate)
		result.gate = gate
	return result

static func _triangle() -> ArrayMesh:
	var outer := [Vector3(-1.27, 0, 0), Vector3(1.27, 0, 0), Vector3(0, 2.9, 0)]
	var center := Vector3(0, 0.97, 0)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var a: Vector3 = outer[i]
		var b: Vector3 = outer[(i + 1) % 3]
		var c := center + (b - center) * 0.95
		var d := center + (a - center) * 0.95
		for point: Vector3 in [a, b, c, a, c, d]:
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(point)
	return surface.commit()
