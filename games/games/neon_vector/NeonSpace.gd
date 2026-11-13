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
var rider: Node3D
var ghost: Node3D
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
var _trail: MultiMeshInstance3D
var _stars: MultiMeshInstance3D
var _asteroids: MultiMeshInstance3D
var _arches: Array[MeshInstance3D] = []
var _planet: MeshInstance3D
var _planet_ring: MeshInstance3D
var _hit_line: MeshInstance3D
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
var _decoration_material: StandardMaterial3D


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
	_trail = _instances(box, 20, _material(Color.WHITE, 1.0, true, true))
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.3
	star_mesh.height = 0.6
	star_mesh.radial_segments = 6
	star_mesh.rings = 3
	_stars = _instances(star_mesh, 240, _material(Color.WHITE, 1.6, true, true))
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1
	rock_mesh.height = 2
	rock_mesh.radial_segments = 5
	rock_mesh.rings = 3
	_asteroids = _instances(rock_mesh, 42, _material(Color.WHITE, 0.1, true, true))
	_decoration_material = _material(_second, 0.7)
	for i in 6:
		var arch := _mesh(_ring(12.65, 12.85), _decoration_material)
		_arches.append(arch)
	var planet_mesh := SphereMesh.new()
	planet_mesh.radius = 43
	planet_mesh.height = 86
	planet_mesh.radial_segments = 48
	planet_mesh.rings = 24
	_planet = _mesh(planet_mesh, _material(Color("343071"), 0.05))
	_planet_ring = _mesh(_ring(58, 62), _material(_second, 0.8))
	_hit_line = _mesh(box, _material(_accent, 1.2))
	_rider_material = _material(Color("132a48"), 0.08)
	_rim_material = _material(_accent, 1.25)
	_ghost_material = _material(Color(0.77, 0.70, 1, 0.3), 0.5, true)
	rider = _wheel(false)
	ghost = _wheel(true)
	ghost.visible = false
	set_world("city")
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
	_env.background_color = Color(world.sky).darkened(0.6)
	_env.fog_light_color = Color(world.sky).darkened(0.45)
	_decoration_material.albedo_color = _second.darkened(0.2)
	_decoration_material.emission = _second
	_rim_material.albedo_color = _accent
	_rim_material.emission = _accent
	(_planet.material_override as StandardMaterial3D).albedo_color = _second.darkened(0.53)
	(_planet_ring.material_override as StandardMaterial3D).albedo_color = _accent.darkened(0.3)
	(_planet_ring.material_override as StandardMaterial3D).emission = _accent
	(_hit_line.material_override as StandardMaterial3D).emission = _accent
	_road_index = -999999


func path(s: float) -> Vector3:
	return Vector3((18 * sin(s / 92.0) + 7 * sin(s / 41.0)) * _curve,
		(5 * sin(s / 63.0) + 2.5 * sin(s / 29.0)) * _curve, -s)


func road_basis(s: float) -> Basis:
	var forward := (path(s + 0.2) - path(s - 0.2)).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	var bank := (sin(s / 92.0) * 0.09 + sin(s / 41.0) * 0.045) * _curve
	return Basis(right, up, -forward).rotated(forward, bank)


func pose(s: float, lateral: float, height: float, size := Vector3.ONE) -> Transform3D:
	var basis := road_basis(s)
	return Transform3D(basis.scaled_local(size), path(s) + basis.x * lateral + basis.y * height)


func update_view(rules: NeonRules, delta: float, lane: float, ghost_lane: float, show_ghost: bool, trail_id: String) -> void:
	if camera == null:
		return
	distance = rules.elapsed_ms / 1000.0 * SPEED
	var desired_curve := 0.25 if reduced_motion else 1.0
	if absf(_curve - desired_curve) > 0.001:
		_curve = lerpf(_curve, desired_curve, 1.0 - exp(-delta * 2))
		_road_index = -999999
	var basis := road_basis(distance)
	# Follow the local tangent so hills/banking move the scenery while the crossing
	# line retains its padding above the fixed lane-number dock.
	camera.position = path(distance) + basis.z * 12 + basis.y * 6.0
	camera.look_at(path(distance) - basis.z * 34 + basis.y * 1.6, basis.y)
	var index := floori(distance / STEP)
	if index != _road_index:
		_road_index = index
		_road_geometry(index)
		_scenery(index)
	_hit_line.transform = pose(distance, 0, 0.06, Vector3(18, 0.035, 0.1))
	var target := pose(distance, (lane - 2.5) * LANE_WIDTH, 1.03)
	rider.transform = target
	rider.get_child(1).rotation.z = -distance / 0.8
	_pulse = maxf(0, _pulse - delta * 3)
	if rules.score_units > _last_score:
		_pulse = 1
	_last_score = rules.score_units
	_rim_material.emission_energy_multiplier = 1.1 + _pulse * 0.7
	ghost.visible = (show_ghost and ghost_lane >= 0) or _warming
	if ghost.visible:
		ghost.transform = pose(distance + 3.5, ((2.5 if _warming else ghost_lane) - 2.5) * LANE_WIDTH, 1.03)
	for i in 20:
		var color := _accent.lerp(_second, i / 20.0) if trail_id == "prism" else _accent
		color.a = (1.0 - i / 20.0) * (0.25 + _pulse * 0.12)
		var width := 0.65 + sin(i * 1.1 + distance) * 0.14 if trail_id == "comet" else 0.35
		_trail.multimesh.set_instance_transform(i, pose(distance - i * 0.42 - 0.6, (lane - 2.5) * LANE_WIDTH, 0.15, Vector3(width, 0.04, 0.65)))
		_trail.multimesh.set_instance_color(i, color)
	_planet.position = path(distance + 350) + Vector3(125, 75, 0)
	_planet.rotation.y = distance * 0.0005
	_planet_ring.position = _planet.position
	_planet_ring.rotation = Vector3(0.35, 0, -0.4)
	_events(rules)


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


func _scenery(_index: int) -> void:
	for i in 240:
		var anchor := fposmod(i * 47.731, 650)
		var s := anchor + ceilf((distance - 80 - anchor) / 650.0) * 650.0
		var x := sin(i * 43.13) * 420
		var y := sin(i * 18.7) * 160 + 85
		var scale := Vector3.ONE * (0.4 + fposmod(i * 0.17, 1.4))
		_stars.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(scale), Vector3(x, y, -s)))
		var tint := _accent.lerp(Color.WHITE, fposmod(i * 0.37, 1))
		tint.a = smoothstep(-80.0, -45.0, s - distance) * (1.0 - smoothstep(440.0, 570.0, s - distance))
		_stars.multimesh.set_instance_color(i, tint)
	for i in 42:
		var anchor := i * 9.7
		var s := anchor + ceilf((distance - 80 - anchor) / 410.0) * 410.0
		var side := -1 if i % 2 else 1
		var where := path(s) + Vector3(side * (25 + fposmod(i * 21.3, 100)), -12 + sin(i * 7.3) * 45, 0)
		var scale := Vector3(1.5, 1, 1.2) * (1.2 + fposmod(i * 1.71, 4.0))
		_asteroids.multimesh.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(i, i * 0.3, i * 0.7)).scaled(scale), where))
		var tint := _second.darkened(0.45)
		tint.a = smoothstep(-80.0, -45.0, s - distance) * (1.0 - smoothstep(230.0, 330.0, s - distance))
		_asteroids.multimesh.set_instance_color(i, tint)
	for i in _arches.size():
		var s := (floori(distance / 65) + i) * 65.0
		_arches[i].transform = pose(s, 0, 4.5)
		_arches[i].rotate_object_local(Vector3.RIGHT, PI / 2)


func _events(rules: NeonRules) -> void:
	var counts := {"cruise": 0, "hold": 0, "charge": 0}
	var ribbon_count := 0
	var now := rules.elapsed_ms
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
				var ahead := (at - now) / 1000.0 * SPEED
				if ahead > 250:
					break
				var fade := smoothstep(-16.0, -2.0, ahead) * (1.0 - smoothstep(205.0, 250.0, ahead))
				var tint := color
				tint.a = fade * (0.18 if muted else 1.0)
				var n: int = counts[bucket]
				var size := Vector3(2.25, 0.16, 0.32) if bucket == "cruise" else Vector3(1.15, 1.5, 1.15)
				var transform := pose(at / 1000.0 * SPEED, lateral, 0.65 + sin(now * 0.003 + tick) * 0.05, size)
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
					var mid := (at + finish) / 2000.0 * SPEED
					var tint := color
					tint.a = 0.12 * (0.25 if muted else 1.0) * smoothstep(-12.0, 0.0, mid - distance)
					_ribbons.multimesh.set_instance_transform(ribbon_count, pose(mid, lateral, 0.035, Vector3(2.55, 0.035, (finish - at) / 1000.0 * SPEED + 0.01)))
					_ribbons.multimesh.set_instance_color(ribbon_count, tint)
					ribbon_count += 1
					at = finish
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


func _wheel(translucent: bool) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var body := SphereMesh.new()
	body.radius = 0.67
	body.height = 1.34
	body.radial_segments = 24
	body.rings = 12
	_mesh(body, _ghost_material if translucent else _rider_material, root)
	var ring := _mesh(_ring(0.78, 0.9), _ghost_material if translucent else _rim_material, root)
	ring.rotation.x = PI / 2
	var inner := _mesh(_ring(0.55, 0.59), _ghost_material if translucent else _rim_material, root)
	inner.rotation.x = PI / 2
	inner.position.z = 0.65
	var fin := _mesh(_chevron(), _ghost_material if translucent else _rim_material, root)
	fin.scale = Vector3.ONE * 0.42
	fin.rotation.x = PI / 2
	fin.position.z = 0.72
	return root


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
