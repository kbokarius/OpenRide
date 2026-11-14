class_name LaneSmashScenery
extends Node3D
## World-anchored set dressing: alloy gantries arching over the road and streaks of light in the
## space around it. Both are fixed at absolute course distances, so they pass at exactly the
## rider's speed and stop when the rider stops. Bounded pools; a slot is rewritten only when a
## new piece enters the window, so there is no per-frame transform work.
## Spacings and distances here are world metres; `gantry_distance` and the pool windows
## convert to road metres (the unit the route is sampled in) with NeonSpace.STRETCH.
const GANTRY_SPACING := 64.0
const GANTRY_OFFSET := 64.0   ## the first arch stands this far down the road
const GANTRY_SLOTS := 10
const MOTE_SPACING := 6.0
const MOTE_SLOTS := 112
## A piece is retired only once it is this far behind the rider. The chase camera sits about
## 17.5 m behind the rider, so everything flies past the edges of the screen before it goes.
const BEHIND := 40.0
## Half the arch, outward from the road centre: (lateral, height) in metres.
const ARCH := [Vector2(10.3, -0.9), Vector2(12.9, 3.0), Vector2(10.9, 9.8), Vector2(4.6, 13.2), Vector2(0.0, 13.6)]

var space: Node3D
var gantries: MultiMeshInstance3D
var motes: MultiMeshInstance3D
var _gantry_material: ShaderMaterial
var _mote_material: ShaderMaterial
var _gantry_from := -999999
var _mote_from := -999999
var _route_id := ""
var _accent := Color.WHITE


func _ready() -> void:
	_gantry_material = ShaderMaterial.new()
	_gantry_material.shader = preload("res://games/neon_vector/scenery_gantry.gdshader")
	_gantry_material.render_priority = -7
	gantries = _pool(_gantry_mesh(), GANTRY_SLOTS, _gantry_material)
	_mote_material = ShaderMaterial.new()
	_mote_material.shader = preload("res://games/neon_vector/scenery_mote.gdshader")
	_mote_material.render_priority = -6
	motes = _pool(_mote_mesh(), MOTE_SLOTS, _mote_material)


func _pool(mesh: Mesh, count: int, material: Material) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	for i in count:
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3(0, -9000, 0)))
		multimesh.set_instance_color(i, Color.WHITE)
		multimesh.set_instance_custom_data(i, Color(1000000.0, 0, 0, 0))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Pieces sit hundreds of metres from the pool's origin: never cull the pool as a whole.
	node.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	add_child(node)
	return node


func set_palette(accent: Color, second: Color) -> void:
	_accent = accent
	_gantry_material.set_shader_parameter("accent", accent)
	_gantry_material.set_shader_parameter("rim_color", second)
	_mote_from = -999999  # motes carry their tint per instance


func update_view(distance: float, road_end: float, fade_start: float, presence: float, pulse: float, lite: bool, music := Vector4.ZERO) -> void:
	if _route_id != space._terrain_id:
		_route_id = space._terrain_id
		_gantry_from = -999999
		_mote_from = -999999
	for material in [_gantry_material, _mote_material]:
		material.set_shader_parameter("road_end", road_end)
		material.set_shader_parameter("fade_start", fade_start)
		material.set_shader_parameter("presence", presence)
		material.set_shader_parameter("pulse", pulse)
		material.set_shader_parameter("music", music)
	var stretch := NeonSpace.STRETCH
	for material in [_gantry_material, _mote_material]: material.set_shader_parameter("rider_s", distance)
	# An arch joins the pool at the far end of its window; it fades in over the last stretch
	# of that window instead of appearing, and both fade behind the camera, not at the bike.
	var reach := ((GANTRY_SLOTS - 1) * GANTRY_SPACING - BEHIND) / stretch
	_gantry_material.set_shader_parameter("appear", Vector2(reach * 0.72, reach * 0.96))
	_mote_material.set_shader_parameter("behind", Vector2(-BEHIND / stretch, -18.0 / stretch))
	motes.visible = not lite
	var first := ceili((distance * stretch - BEHIND - GANTRY_OFFSET) / GANTRY_SPACING)
	if first != _gantry_from:
		for index in range(first, first + GANTRY_SLOTS):
			if index >= _gantry_from and index < _gantry_from + GANTRY_SLOTS: continue
			var s := gantry_distance(index)
			var slot := posmod(index, GANTRY_SLOTS)
			gantries.multimesh.set_instance_transform(slot, space.coaster.at(s) if index >= 0 else Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3(0, -9000, 0)))
			# Arches take turns with the spectrum: bass, mids, treble, bass… down the road.
			gantries.multimesh.set_instance_custom_data(slot, Color(s, float(posmod(index, 3)), 0, 0))
		_gantry_from = first
	if lite: return
	first = ceili((distance * stretch - BEHIND) / MOTE_SPACING)
	if first != _mote_from:
		for index in range(first, first + MOTE_SLOTS):
			if index >= _mote_from and index < _mote_from + MOTE_SLOTS: continue
			var s := index * MOTE_SPACING / stretch
			var seed_a := fposmod(sin(index * 12.9898) * 43758.5453, 1.0)
			var seed_b := fposmod(sin(index * 78.233 + 1.7) * 24634.6345, 1.0)
			var seed_c := fposmod(sin(index * 39.425 + 4.1) * 13758.1173, 1.0)
			var frame: Transform3D = space.coaster.at(s)
			var angle := seed_a * TAU
			var radius := 3.0 * NeonSpace.LANE_WIDTH + 4.5 + seed_b * 19.0
			var origin := frame.origin + frame.basis.x * cos(angle) * radius + frame.basis.y * (sin(angle) * radius * 0.72 + 4.0)
			var length := 2.5 + seed_c * 5.5
			var slot := posmod(index, MOTE_SLOTS)
			motes.multimesh.set_instance_transform(slot, Transform3D(Basis(frame.basis.x * 0.09, frame.basis.y * 0.09, frame.basis.z * length), origin))
			motes.multimesh.set_instance_color(slot, Color(_accent.lerp(Color.WHITE, 0.25 + seed_c * 0.5), 0.35 + seed_b * 0.45))
			motes.multimesh.set_instance_custom_data(slot, Color(s, 0, 0, 0))
		_mote_from = first


## The road distance (the route's unit) of arch `index`.
static func gantry_distance(index: int) -> float:
	return (index * GANTRY_SPACING + GANTRY_OFFSET) / NeonSpace.STRETCH


## One arch: faceted alloy legs and a crown, with a light strip along the inside edge.
static func _gantry_mesh() -> ArrayMesh:
	var kit := MeshKit3D.new()
	kit.flags = true
	kit.outline = 0.0
	kit.glow = 0.0
	var alloy := Color(0.07, 0.085, 0.125, 1.0)
	for side: float in [-1.0, 1.0]:
		for i in ARCH.size() - 1:
			var a := Vector3(side * ARCH[i].x * NeonSpace.LANE_WIDTH / 3.0, ARCH[i].y, 0)
			var b := Vector3(side * ARCH[i + 1].x * NeonSpace.LANE_WIDTH / 3.0, ARCH[i + 1].y, 0)
			kit.outline = 0.0
			kit.glow = 0.0
			kit.add(MeshKit3D.box(Vector3(0.42, 1.0, 0.9)), MeshKit3D.between(a, b), alloy.lightened(0.04 * i))
			# The strip sits just inside the arch, towards the road.
			var inward := (Vector3(0, 5.0, 0) - (a + b) * 0.5).normalized() * 0.26
			kit.outline = 1.0
			kit.glow = 1.0
			kit.add(MeshKit3D.box(Vector3(0.10, 0.97, 0.16)), MeshKit3D.between(a + inward, b + inward), Color.WHITE)
		# A foot ties the leg to the rail.
		kit.outline = 0.0
		kit.glow = 0.0
		kit.add(MeshKit3D.box(Vector3(0.30, 1.0, 0.7)), MeshKit3D.between(Vector3(side * (3.0 * NeonSpace.LANE_WIDTH + 0.55), -0.24, 0), Vector3(side * ARCH[0].x * NeonSpace.LANE_WIDTH / 3.0, ARCH[0].y, 0)), alloy)
	return kit.commit()


## Two crossed cards, one metre long on Z; scaled per instance.
static func _mote_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP]:
		var corners := [[-axis - Vector3(0, 0, 0.5), Vector2(0, 0)], [axis - Vector3(0, 0, 0.5), Vector2(1, 0)],
			[axis + Vector3(0, 0, 0.5), Vector2(1, 1)], [-axis + Vector3(0, 0, 0.5), Vector2(0, 1)]]
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_color(Color.WHITE)
			surface.set_uv(corners[index][1])
			surface.set_normal(Vector3.UP)
			surface.add_vertex(corners[index][0])
	return surface.commit()
