class_name LaneSmashFx
extends Node3D
## Pooled light effects layered over the shards and shockwaves: streaking sparks, boiling energy
## blasts and tall beams of light. Every pool has a fixed capacity and recycles its oldest slot;
## nothing is spawned or freed during a ride.
const SPARKS := 192
const BLASTS := 8
const BEAMS := 8

var _sparks: Array[Dictionary] = []
var _blasts: Array[Dictionary] = []
var _beams: Array[Dictionary] = []
var _spark_pool: MultiMeshInstance3D
var _blast_pool: MultiMeshInstance3D
var _beam_pool: MultiMeshInstance3D
var _serial := 0


func _ready() -> void:
	_spark_pool = _pool(_card(), SPARKS, LaneSmashLook.emissive(true, 2.2), false)
	var fire := ShaderMaterial.new()
	fire.shader = preload("res://games/neon_vector/fx_fireball.gdshader")
	fire.set_shader_parameter("noise", MeshKit3D.noise_texture(9401))
	_blast_pool = _pool(MeshKit3D.sphere(1.0, 20, 10), BLASTS, fire, true)
	_beam_pool = _pool(_beam(), BEAMS, LaneSmashLook.emissive(true, 2.0), false)


func _pool(mesh: Mesh, count: int, material: Material, custom: bool) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = custom
	multimesh.mesh = mesh
	multimesh.instance_count = count
	multimesh.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	add_child(node)
	return node


## Sparks thrown out from `at` in the road's frame: fast, bright, short-lived.
func burst(at: Vector3, basis: Basis, color: Color, count: int, force: float) -> void:
	_serial += 1
	for i in count:
		if _sparks.size() >= SPARKS: _sparks.pop_front()
		var seed_a := fposmod(sin((i + 1) * 12.9898 + _serial * 3.31) * 43758.5453, 1.0)
		var seed_b := fposmod(sin((i + 1) * 78.233 + _serial * 1.17) * 24634.6345, 1.0)
		var seed_c := fposmod(sin((i + 1) * 39.425 + _serial * 5.03) * 13758.1173, 1.0)
		var angle := seed_a * TAU
		var lift := 0.15 + seed_b * 0.95
		var speed := (5.0 + seed_c * 11.0) * force
		var direction := basis * Vector3(cos(angle) * (1.0 - lift * 0.55), lift, sin(angle) * (1.0 - lift * 0.55)).normalized()
		_sparks.append({"origin": at, "velocity": direction * speed, "gravity": -basis.y * 13.0, "age": 0.0,
			"life": 0.30 + seed_b * 0.45, "color": color.lerp(LaneSmashLook.HOT, 0.25 + seed_c * 0.5), "width": 0.045 + seed_a * 0.05})


## A boiling ball of energy that swells to `radius` and breaks up over `life` seconds.
func blast(at: Vector3, basis: Basis, color: Color, radius: float, life: float) -> void:
	if _blasts.size() >= BLASTS: _blasts.pop_front()
	_blasts.append({"origin": at, "basis": basis, "color": color, "radius": radius, "life": life, "age": 0.0})


## A beam of light standing `height` metres along `up`, for a section's finish.
func beam(at: Vector3, basis: Basis, color: Color, height: float, life: float) -> void:
	if _beams.size() >= BEAMS: _beams.pop_front()
	_beams.append({"origin": at, "basis": basis, "color": color, "height": height, "life": life, "age": 0.0})


func clear() -> void:
	_sparks.clear()
	_blasts.clear()
	_beams.clear()


func active() -> int:
	return _sparks.size() + _blasts.size() + _beams.size()


func update_view(delta: float, eye: Vector3) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		_sparks[i].age += delta
		if float(_sparks[i].age) >= float(_sparks[i].life): _sparks.remove_at(i)
	for i in _sparks.size():
		var spark: Dictionary = _sparks[i]
		var age := float(spark.age)
		var velocity: Vector3 = spark.velocity + Vector3(spark.gravity) * age
		var pos: Vector3 = spark.origin + Vector3(spark.velocity) * age + Vector3(spark.gravity) * age * age * 0.5
		var along := velocity.normalized() if velocity.length_squared() > 0.0001 else Vector3.UP
		var side := along.cross(eye - pos)
		side = side.normalized() if side.length_squared() > 0.000001 else along.cross(Vector3.RIGHT).normalized()
		var left := 1.0 - age / float(spark.life)
		var length := clampf(velocity.length() * 0.055, 0.12, 1.4)
		_spark_pool.multimesh.set_instance_transform(i, Transform3D(Basis(along * length, side * float(spark.width) * (0.4 + left), side.cross(along)), pos))
		_spark_pool.multimesh.set_instance_color(i, Color(spark.color, left * left))
	_spark_pool.multimesh.visible_instance_count = _sparks.size()
	for i in range(_blasts.size() - 1, -1, -1):
		_blasts[i].age += delta
		if float(_blasts[i].age) >= float(_blasts[i].life): _blasts.remove_at(i)
	for i in _blasts.size():
		var blast: Dictionary = _blasts[i]
		var t := float(blast.age) / float(blast.life)
		var size := float(blast.radius) * (0.25 + 0.75 * (1.0 - pow(1.0 - t, 3.0)))
		_blast_pool.multimesh.set_instance_transform(i, Transform3D((blast.basis as Basis).scaled_local(Vector3(size, size * 0.82, size)), blast.origin))
		_blast_pool.multimesh.set_instance_color(i, blast.color)
		_blast_pool.multimesh.set_instance_custom_data(i, Color(t, 0, 0, 0))
	_blast_pool.multimesh.visible_instance_count = _blasts.size()
	for i in range(_beams.size() - 1, -1, -1):
		_beams[i].age += delta
		if float(_beams[i].age) >= float(_beams[i].life): _beams.remove_at(i)
	for i in _beams.size():
		var beam: Dictionary = _beams[i]
		var t := float(beam.age) / float(beam.life)
		var rise := 1.0 - pow(1.0 - minf(1.0, t * 3.0), 2.0)
		var width := 1.1 * (1.0 - t * 0.6)
		_beam_pool.multimesh.set_instance_transform(i, Transform3D((beam.basis as Basis).scaled_local(Vector3(width, float(beam.height) * rise, width)), beam.origin))
		_beam_pool.multimesh.set_instance_color(i, Color(beam.color, pow(1.0 - t, 1.5) * 0.85))
	_beam_pool.multimesh.visible_instance_count = _beams.size()


## A unit card on X (length) and Y (width), soft at the edges through its UVs.
static func _card() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [[Vector3(-0.5, -0.5, 0), Vector2(0, 0)], [Vector3(0.5, -0.5, 0), Vector2(1, 0)], [Vector3(0.5, 0.5, 0), Vector2(1, 1)], [Vector3(-0.5, 0.5, 0), Vector2(0, 1)]]
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_color(Color.WHITE)
		surface.set_uv(corners[index][1])
		surface.set_normal(Vector3.BACK)
		surface.add_vertex(corners[index][0])
	return surface.commit()


## Two crossed cards one metre tall on Y, standing on the origin.
static func _beam() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var half := axis * 0.5
		var corners := [[-half, Vector2(0, 0.5)], [half, Vector2(1, 0.5)], [half + Vector3.UP, Vector2(1, 1)], [-half + Vector3.UP, Vector2(0, 1)]]
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_color(Color.WHITE)
			surface.set_uv(corners[index][1])
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(corners[index][0])
	return surface.commit()
