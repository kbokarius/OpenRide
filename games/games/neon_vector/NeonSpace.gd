class_name NeonSpace
extends Node3D
## Bounded 3D presentation. Every road object is anchored to an absolute course distance.
## The camera moves through that space; scoring never depends on camera/mesh positions.

const SPEED := 18.0
const LANE_WIDTH := 3.0
const ROAD_STEPS := 96
const STEP := 3.0
const MARKERS := 112
const GOLD := Color("ffd369")
const GREEN := Color("6fffd0")
const VIOLET := Color("c6a0ff")

var camera: Camera3D
var rider: LaneSmashCyclist
var ghost: LaneSmashCyclist
var world_id := ""
var reduced_motion := false
var distance := 0.0
var _curve := 1.0
var _road: MultiMeshInstance3D
var _rails: MultiMeshInstance3D
var _ties: MultiMeshInstance3D
var _posts: MultiMeshInstance3D
var _bars: MultiMeshInstance3D
var _arrows: MultiMeshInstance3D
var _crystals: MultiMeshInstance3D
var _ribbons: MultiMeshInstance3D
var _shards: MultiMeshInstance3D
var _impacts: Array[Dictionary] = []
var _collected := {}
var _previous_distance := -1.0
var _previous_ms := -1
var _terrain_id := ""
var _heights := PackedFloat32Array()
var _lanes := PackedFloat32Array()
var _terrain_step := 9.0
var _unit_speed := SPEED
var ghost_distance := -1.0
var ghost_cadence := 80.0
var _rim_light: DirectionalLight3D
var environment_id := ""
var _structures: LaneSmashEnvironment
var impact_count := 0
var _env: Environment
var _accent := Color("67d8ff")
var _second := Color("a481ff")
var _road_index := -999999
var _pulse := 0.0
var _last_score := 0
var _warming := true
var _rider_material: StandardMaterial3D
var _rim_material: StandardMaterial3D
var _ghost_material: StandardMaterial3D


func _ready() -> void:
	var environment := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color("030615")
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color("778bc4")
	_env.ambient_light_energy = 0.65
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_light_color = Color("05091d")
	_env.fog_density = 0.0025
	environment.environment = _env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -28, 0)
	sun.light_color = Color("bddeff")
	sun.light_energy = 1.5
	sun.shadow_enabled = false
	add_child(sun)
	var rim := DirectionalLight3D.new()
	_rim_light = rim
	rim.rotation_degrees = Vector3(22, 145, 0)
	rim.light_color = Color("c78bff")
	rim.light_energy = 0.75
	add_child(rim)
	camera = Camera3D.new()
	camera.fov = 68
	camera.near = 0.2
	camera.far = 1200
	add_child(camera)
	camera.make_current()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_road = _instances(box, ROAD_STEPS * 6, _material(Color.WHITE, 0.06, false, true))
	_rails = _instances(box, ROAD_STEPS * 7, _material(Color.WHITE, 1.3, false, true))
	_ties = _instances(box, ROAD_STEPS, _material(Color.WHITE, 0.15, false, true))
	_posts = _instances(box, ROAD_STEPS * 2, _material(Color.WHITE, 0.5, false, true))
	_bars = _instances(box, MARKERS, _material(Color.WHITE, 0.8, true, true))
	_arrows = _instances(_chevron(), MARKERS, _material(Color.WHITE, 0.6, true, true))
	var crystal := PrismMesh.new()
	crystal.size = Vector3(1, 1.3, 0.7)
	_crystals = _instances(crystal, MARKERS, _material(Color.WHITE, 1.0, true, true))
	_ribbons = _instances(box, 112, _material(Color.WHITE, 0.5, true, true))
	_shards = _instances(box, 192, _material(Color.WHITE, 1.2, true, true))
	_shards.multimesh.visible_instance_count = 0

	_rider_material = _material(Color("132a48"), 0.08)
	_rim_material = _material(_accent, 1.25)
	_ghost_material = _material(Color(0.77, 0.70, 1, 0.3), 0.5, true)
	rider = LaneSmashCyclist.new()
	add_child(rider)
	ghost = LaneSmashCyclist.new()
	ghost.translucent = true
	add_child(ghost)
	ghost.visible = false
	_structures = LaneSmashEnvironment.new()
	add_child(_structures)
	_structures.configure(_env)
	set_world("arctic")
	# Exercise every material during the host's three-second intro. Mobile GL can
	# otherwise compile the first ghost/arrow/crystal shader during scored gameplay.
	get_tree().create_timer(1.0).timeout.connect(func(): _warming = false)


func set_world(id: String) -> void:
	if world_id == id or _env == null:
		return
	world_id = id
	var world := NeonWorlds.world(id)
	_accent = Color(world.accent)
	_second = Color(world.second)
	_rim_light.light_color = _second.lerp(Color.WHITE, 0.65)
	_env.background_color = Color(world.sky).darkened(0.6)
	_env.fog_light_color = Color(world.sky).darkened(0.45)
	_rim_material.albedo_color = _accent
	_rim_material.emission = _accent
	if rider: rider.tint(_accent)
	if ghost: ghost.tint(_accent)
	_road_index = -999999


func prepare_terrain(course: Dictionary) -> void:
	var id := "%s:%s" % [course.get("courseId", ""), course.get("courseVersion", 0)]
	if id == _terrain_id: return
	_terrain_id = id
	_heights.clear()
	_lanes.clear()
	var height := 0.0
	var slope := 0.0
	var target_lane := 0.0
	var cursor := 0
	var events: Array = course.get("events", [])
	var count := int(course.get("durationMs", 0)) / 500 + 80
	for i in count:
		var time := i * 500
		while cursor + 1 < events.size() and int(events[cursor].endMs) < time: cursor += 1
		var target := float(events[cursor].laneIndex) if not events.is_empty() else 0.0
		target_lane = lerpf(target_lane, target, 0.16)
		# Higher scoring lanes form visibly steeper climbs. A gentle descent recovers height.
		var grade: float = [-0.12, -0.03, 0.07, 0.18, 0.31, 0.46][clampi(roundi(target), 0, 5)]
		slope = lerpf(slope, grade, 0.12)
		height += slope * _terrain_step
		_heights.append(height)
		_lanes.append(target_lane)
	_road_index = -999999

func path(s: float) -> Vector3:
	var h := 0.0
	var lane := 0.0
	if _heights.size() > 1:
		var f := clampf(s / _terrain_step, 0, _heights.size() - 1.001)
		var i := floori(f)
		h = _spline(_heights, i, f - i)
		lane = _spline(_lanes, i, f - i)
	return Vector3((18 * sin(s / 92.0) + 7 * sin(s / 41.0) + lane * 3.5) * _curve,
		(h + 2.0 * sin(s / 63.0)) * _curve, -s)


func road_basis(s: float) -> Basis:
	var forward := (path(s + 0.2) - path(s - 0.2)).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	var bank := (sin(s / 92.0) * 0.09 + sin(s / 41.0) * 0.045) * _curve
	return Basis(right, up, -forward).rotated(forward, bank)


func pose(s: float, lateral: float, height: float, size := Vector3.ONE) -> Transform3D:
	var basis := road_basis(s)
	return Transform3D(basis.scaled_local(size), path(s) + basis.x * lateral + basis.y * height)


func update_view(rules: NeonRules, delta: float, lane: float, ghost_lane: float, show_ghost: bool, _trail_id: String) -> void:
	if camera == null:
		return
	_unit_speed = rules.road_speed_scale()
	_terrain_step = _unit_speed * 0.5
	prepare_terrain(rules.course)
	distance = rules.road_distance()
	var resistance_fraction: float = (float(rules.latest.get("resistance", NeonRules.TIERS[rules.tier])) - NeonRules.TIERS[rules.tier]) / 41.0
	_structures.update_environment(str(rules.course.get("background", "orbital")), _accent, float(rules.latest.get("cadence", 0)), resistance_fraction, delta, reduced_motion)
	var desired_curve := 0.25 if reduced_motion else 1.0
	if absf(_curve - desired_curve) > 0.001:
		_curve = lerpf(_curve, desired_curve, 1.0 - exp(-delta * 2))
		_road_index = -999999
	var basis := road_basis(distance)
	# Follow the local tangent so hills/banking move the scenery while the rider
	# retains its padding above the fixed lane-number dock.
	camera.position = path(distance) + basis.z * 12 + basis.y * 6.0
	camera.look_at(path(distance) - basis.z * 34 + basis.y * 1.6, basis.y)
	_structures.material.set_shader_parameter("camera_basis", camera.basis)
	var index := floori(distance / STEP)
	if index != _road_index:
		_road_index = index
		_road_geometry(index)
	var target := pose(distance, (lane - 2.5) * LANE_WIDTH, 0.05)
	rider.transform = target
	rider.animate(float(rules.latest.get("cadence", 0)), delta)
	_pulse = maxf(0, _pulse - delta * 3)
	if rules.score_units > _last_score:
		_pulse = 1
	_last_score = rules.score_units
	_rim_material.emission_energy_multiplier = 1.1 + _pulse * 0.7
	var ghost_at := ghost_distance if ghost_distance >= 0 else distance + 3.5
	var ghost_gap := ghost_at - distance
	ghost.visible = (show_ghost and ghost_lane >= 0 and ghost_gap > -5 and ghost_gap < 85 and absf(ghost_gap) > 1.4) or _warming
	if ghost.visible:
		ghost.set_opacity(smoothstep(-5.0, -1.5, ghost_gap) * (1.0 - smoothstep(50.0, 85.0, ghost_gap)) * smoothstep(1.4, 4.5, absf(ghost_gap)))
		ghost.transform = pose(distance + 3.5 if _warming else ghost_at, ((2.5 if _warming else ghost_lane) - 2.5) * LANE_WIDTH, 0.05)
		ghost.animate(ghost_cadence, delta)
	_events(rules, lane)
	_animate_impacts(delta)


func _road_geometry(index: int) -> void:
	for i in ROAD_STEPS:
		var s := (index + i - 8) * STEP
		for lane in 6:
			var n := i * 6 + lane
			_road.multimesh.set_instance_transform(n, pose(s, (lane - 2.5) * LANE_WIDTH, -0.14, Vector3(2.98, 0.25, STEP + 0.06)))
			_road.multimesh.set_instance_color(n, Color("121a32").lerp(_accent, 0.035 if lane % 2 else 0.07))
		for edge in 7:
			var n := i * 7 + edge
			_rails.multimesh.set_instance_transform(n, pose(s, (edge - 3) * LANE_WIDTH, 0.04, Vector3(0.045 if edge in [0, 6] else 0.022, 0.035, STEP + 0.08)))
			_rails.multimesh.set_instance_color(n, _accent if edge in [0, 6] else _accent.darkened(0.65))
		_ties.multimesh.set_instance_transform(i, pose(s - STEP / 2, 0, -0.18, Vector3(18.2, 0.25, 0.09)))
		_ties.multimesh.set_instance_color(i, _second.darkened(0.6))
		for side in 2:
			_posts.multimesh.set_instance_transform(i * 2 + side, pose(s, -9.12 if side == 0 else 9.12, 0.25, Vector3(0.12, 0.65, 0.12)))
			_posts.multimesh.set_instance_color(i * 2 + side, _accent.darkened(0.25))


func _events(rules: NeonRules, visual_lane: float) -> void:
	var counts := {"cruise": 0, "hold": 0, "charge": 0}
	var ribbon_count := 0
	var now := rules.road_time_ms()
	if now < _previous_ms:
		_collected.clear()
		_previous_distance = -1.0
		_impacts.clear()
	for key in _collected.keys():
		if now - int(_collected[key]) > 2000: _collected.erase(key)
	for i in range(maxi(0, rules._event_cursor - 1), rules.course.events.size()):
		var event: Dictionary = rules.course.events[i]
		if int(event.startMs) > now + 14500:
			break
		if int(event.endMs) < now - 1000:
			continue
		var kind := str(event.type)
		var bucket := "cruise" if kind == "pickup" else ("charge" if kind == "burst" else kind)
		var pool := _bars if bucket == "cruise" else (_arrows if bucket == "hold" else _crystals)
		var color := GOLD if bucket == "cruise" else (GREEN if bucket == "hold" else VIOLET)
		var state: Dictionary = rules.event_states[i]
		var choices := NeonCourse.choices(event)
		for c in choices.size():
			var lane := int(choices[c].laneIndex)
			var lateral := (lane - 2.5) * LANE_WIDTH
			var muted := int(state.choice) >= 0 and int(state.choice) != c
			var start := int(event.get("hitMs", event.startMs)) if kind == "pickup" else int(event.startMs)
			var end := start + 1 if kind == "pickup" else int(event.endMs)
			# Anchors never depend on the visible near edge: arrows keep travelling after entry.
			var spacing := 600 if bucket != "charge" else 850
			var tick := maxi(0, ceili(float(now - 950 - start) / spacing))
			while start + tick * spacing < end and int(counts[bucket]) < MARKERS:
				var at := start + tick * spacing
				var key := "%s:%d:%d" % [event.eventId, c, tick]
				# Physical contact is independent of scoring eligibility: even an off-target
				# cadence arrow shatters, while the rules still award zero for that interval.
				var anchor := at / 1000.0 * _unit_speed
				var angle := now * 0.0018 + tick
				var back_extent := 0.16 if bucket == "cruise" else (0.6325 if bucket == "hold" else absf(sin(angle)) * 0.575 + absf(cos(angle)) * 0.4025)
				var front_extent := 0.92 if bucket == "hold" else back_extent
				var contact := anchor - LaneSmashCyclist.FRONT_REACH - back_extent
				if not _collected.has(key) and _previous_distance >= 0 and now - _previous_ms <= 250 and _previous_distance + 0.38 <= anchor + front_extent and distance >= contact and absf(visual_lane - lane) < 0.38:
					_collected[key] = at
					_explode(pose(anchor, lateral, 0.65).origin, color)
				if _collected.has(key):
					tick += 1
					continue
				var ahead := (at - now) / 1000.0 * _unit_speed
				if ahead > 250:
					break
				var fade := smoothstep(-16.0, -2.0, ahead) * (1.0 - smoothstep(205.0, 250.0, ahead))
				var tint := color
				tint.a = fade * (0.18 if muted else 1.0)
				var n: int = counts[bucket]
				var size := Vector3(2.25, 0.16, 0.32) if bucket == "cruise" else Vector3(1.15, 1.5, 1.15)
				var transform := pose(at / 1000.0 * _unit_speed, lateral, 0.65 + sin(now * 0.003 + tick) * 0.05, size)
				if bucket == "charge":
					transform.basis = transform.basis.rotated(transform.basis.y.normalized(), now * 0.0018 + tick)
					transform.origin += transform.basis.y * 0.35
				pool.multimesh.set_instance_transform(n, transform)
				pool.multimesh.set_instance_color(n, tint)
				counts[bucket] = n + 1
				tick += 1
			if kind != "pickup":
				var near := maxi(int(event.startMs), now - 700)
				var far := mini(int(event.endMs), now + 14000)
				var at := near
				while at < far and ribbon_count < 112:
					var finish := mini(far, at + 350)
					var mid := (at + finish) / 2000.0 * _unit_speed
					var tint := color
					tint.a = 0.12 * (0.25 if muted else 1.0) * smoothstep(0.0, 2.0, mid - distance - LaneSmashCyclist.FRONT_REACH)
					_ribbons.multimesh.set_instance_transform(ribbon_count, pose(mid, lateral, 0.035, Vector3(2.55, 0.035, (finish - at) / 1000.0 * _unit_speed + 0.01)))
					_ribbons.multimesh.set_instance_color(ribbon_count, tint)
					ribbon_count += 1
					at = finish
	_previous_ms = now
	_previous_distance = distance
	if _warming:
		for key in counts:
			if int(counts[key]) == 0:
				var pool := _bars if key == "cruise" else (_arrows if key == "hold" else _crystals)
				pool.multimesh.set_instance_transform(0, pose(distance + 8, 0, 0.1, Vector3.ONE * 0.05))
				pool.multimesh.set_instance_color(0, Color(1, 1, 1, 0.02))
				counts[key] = 1
	_bars.multimesh.visible_instance_count = counts.cruise
	_arrows.multimesh.visible_instance_count = counts.hold
	_crystals.multimesh.visible_instance_count = counts.charge
	_ribbons.multimesh.visible_instance_count = ribbon_count


func _explode(at: Vector3, color: Color) -> void:
	impact_count += 1
	for i in 12:
		if _impacts.size() >= 192: _impacts.pop_front()
		var angle := i * TAU / 12.0 + impact_count * 0.8
		_impacts.append({"origin": at, "velocity": Vector3(cos(angle) * 3.0, 1.5 + (i % 4) * 0.9, sin(angle) * 3.0), "age": 0.0, "color": color})

func _animate_impacts(delta: float) -> void:
	for i in range(_impacts.size() - 1, -1, -1):
		_impacts[i].age += delta
		if float(_impacts[i].age) > 0.65: _impacts.remove_at(i)
	for i in _impacts.size():
		var particle: Dictionary = _impacts[i]
		var age := float(particle.age)
		var pos: Vector3 = particle.origin + particle.velocity * age + Vector3.DOWN * age * age * 3.0
		var tint: Color = particle.color
		tint.a = pow(1.0 - age / 0.65, 1.4)
		var size := 0.18 * (1.0 - age / 0.8)
		_shards.multimesh.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(age * 8, i, age * 6)).scaled(Vector3.ONE * size), pos))
		_shards.multimesh.set_instance_color(i, tint)
	_shards.multimesh.visible_instance_count = _impacts.size()


static func _material(color: Color, emission: float, alpha := false, vertex_color := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.35
	material.roughness = 0.32
	material.emission_enabled = emission > 0
	material.emission = color
	material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	material.emission_energy_multiplier = emission
	material.vertex_color_use_as_albedo = vertex_color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _mesh(shape: Mesh, material: Material, parent: Node = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _instances(shape: Mesh, count: int, material: Material) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = shape
	multimesh.instance_count = count
	node.multimesh = multimesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


static func _ring(inner: float, outer: float) -> TorusMesh:
	var ring := TorusMesh.new()
	ring.inner_radius = inner
	ring.outer_radius = outer
	ring.rings = 48
	ring.ring_segments = 8
	return ring


static func _chevron() -> ArrayMesh:
	# Extruded, bevel-sided arrow. Top and side normals remain distinct in the light.
	var outline := PackedVector2Array([Vector2(-1.0, 0.55), Vector2(-1.0, 0.0), Vector2(0, -0.8), Vector2(1.0, 0.0), Vector2(1.0, 0.55), Vector2(0, -0.25)])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := Geometry2D.triangulate_polygon(outline)
	for index in triangles:
		var point := outline[index] * 0.88
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(point.x, 0.24, point.y))
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var points := [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(b.x * 0.88, 0.24, b.y * 0.88), Vector3(a.x * 0.88, 0.24, a.y * 0.88)]
		var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
		for n in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(normal)
			surface.add_vertex(points[n])
	return surface.commit()


static func _spline(values: PackedFloat32Array, i: int, t: float) -> float:
	var a := values[maxi(0, i - 1)]
	var b := values[i]
	var c := values[mini(values.size() - 1, i + 1)]
	var d := values[mini(values.size() - 1, i + 2)]
	return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t * t * t)
