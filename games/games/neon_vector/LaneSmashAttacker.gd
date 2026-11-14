class_name LaneSmashAttacker
extends Node3D
## Original armored marksman: merged beveled plates, articulated upper body and energy rifle.
const ARMOR := Color("617365")
const EDGE := Color("93a391")
const DARK := Color("142330")
const GOLD := Color("edc274")
const LIGHT := Color("8afce1")
const SHADER := preload("res://games/neon_vector/barrage_armor.gdshader")
var upper: Node3D
var muzzle: Marker3D
var _materials: Array[ShaderMaterial] = []
var _solid := SurfaceTool.new()
var _glow := SurfaceTool.new()
var _upper_solid := SurfaceTool.new()
var _upper_glow := SurfaceTool.new()

func _ready() -> void:
	for surface in [_solid, _glow, _upper_solid, _upper_glow]: surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	upper = Node3D.new()
	upper.position.y = 2.2
	add_child(upper)
	# Boots, greaves and thighs: a relaxed braced firing stance, rounded under the plates.
	for side in [-1.0, 1.0]:
		var hip := Vector3(side * 0.31, 1.79, 0)
		var knee := Vector3(side * 0.43, 1.02, 0.12)
		var ankle := Vector3(side * 0.49, 0.34, 0.05)
		_limb(_solid, hip, knee, 0.23, DARK)
		_limb(_solid, knee, ankle, 0.19, DARK)
		_ellipsoid(_solid, knee, Vector3(0.24, 0.21, 0.23), DARK)
		_plate(_solid, (hip + knee) * 0.5 + Vector3(0, 0, 0.15), Vector3(0.43, 0.65, 0.30), ARMOR, Vector3(0.08, side * 0.1, side * 0.07))
		_plate(_solid, knee + Vector3(0, 0, 0.21), Vector3(0.47, 0.35, 0.24), EDGE)
		_plate(_solid, (knee + ankle) * 0.5 + Vector3(0, 0, 0.18), Vector3(0.36, 0.56, 0.30), ARMOR)
		_plate(_solid, ankle + Vector3(0, -0.16, 0.19), Vector3(0.51, 0.30, 0.82), DARK)
		_plate(_solid, ankle + Vector3(0, -0.10, 0.37), Vector3(0.46, 0.22, 0.45), ARMOR)
		_plate(_glow, knee + Vector3(side * 0.15, 0, 0.345), Vector3(0.045, 0.18, 0.02), LIGHT)
	_plate(_solid, Vector3(0, 1.84, 0), Vector3(0.92, 0.39, 0.59), DARK)
	_plate(_solid, Vector3(0, 1.78, 0.30), Vector3(0.40, 0.42, 0.16), ARMOR)
	# Overlapping torso plates over a flexible undersuit, with a separate upper-body rig.
	_ellipsoid(_upper_solid, Vector3(0, 0.20, 0), Vector3(0.56, 0.65, 0.31), DARK)
	_plate(_upper_solid, Vector3(0, 0.56, 0.16), Vector3(1.16, 0.59, 0.51), ARMOR, Vector3(-0.10, 0, 0))
	for side in [-1.0, 1.0]:
		_plate(_upper_solid, Vector3(side * 0.29, 0.57, 0.42), Vector3(0.47, 0.30, 0.12), EDGE, Vector3(0, 0, -side * 0.12))
		_plate(_upper_solid, Vector3(side * 0.37, 0.24, 0.27), Vector3(0.29, 0.27, 0.16), ARMOR)
		for vent in 3:
			_plate(_upper_solid, Vector3(side * 0.35, 0.63 - vent * 0.064, 0.492), Vector3(0.25, 0.025, 0.025), DARK)
		_plate(_upper_glow, Vector3(side * 0.13, 0.72, 0.465), Vector3(0.06, 0.055, 0.025), LIGHT)
		_plate(_upper_solid, Vector3(side * 0.39, 0.40, -0.36), Vector3(0.28, 0.72, 0.30), ARMOR)
	for rib in 3:
		_plate(_upper_solid, Vector3(0, 0.08 - rib * 0.15, 0.28), Vector3(0.65 - rib * 0.06, 0.13, 0.17), ARMOR.darkened(0.15))
	_limb(_upper_solid, Vector3(0, 0.78, 0), Vector3(0, 1.04, 0), 0.21, DARK)
	# Helmet: sculpted shell, brow, cheek guards and a wrapped metallic visor.
	_ellipsoid(_upper_solid, Vector3(0, 1.22, 0.015), Vector3(0.38, 0.41, 0.36), ARMOR)
	_plate(_upper_solid, Vector3(0, 1.43, 0.24), Vector3(0.71, 0.16, 0.28), EDGE, Vector3(-0.12, 0, 0))
	_plate(_upper_solid, Vector3(0, 1.08, 0.28), Vector3(0.49, 0.19, 0.27), DARK)
	_plate(_upper_solid, Vector3(0, 1.01, 0.30), Vector3(0.43, 0.15, 0.18), ARMOR)
	for side in [-1.0, 1.0]:
		_plate(_upper_solid, Vector3(side * 0.32, 1.18, 0.18), Vector3(0.16, 0.36, 0.27), ARMOR)
		_plate(_upper_solid, Vector3(side * 0.37, 1.25, -0.02), Vector3(0.12, 0.27, 0.28), DARK)
		_plate(_upper_glow, Vector3(side * 0.32, 1.33, 0.33), Vector3(0.06, 0.04, 0.04), LIGHT)
	for segment in 16:
		var a := lerpf(-1.0, 1.0, segment / 16.0)
		var b := lerpf(-1.0, 1.0, (segment + 1) / 16.0)
		var p := [Vector3(a * 0.31, 1.38 - 0.04 * absf(a), 0.32 + 0.10 * (1 - a * a)), Vector3(b * 0.31, 1.38 - 0.04 * absf(b), 0.32 + 0.10 * (1 - b * b)), Vector3(a * 0.31, 1.19 + 0.035 * absf(a), 0.31 + 0.10 * (1 - a * a)), Vector3(b * 0.31, 1.19 + 0.035 * absf(b), 0.31 + 0.10 * (1 - b * b))]
		_quad(_upper_glow, p[0], p[1], p[2], p[3], GOLD)
	# Shoulder pauldrons and bent arms hold the rifle with both hands.
	for side in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.73, 0.57, 0)
		var elbow := Vector3(side * 0.81, -0.01, 0.28)
		var hand := Vector3(0.40 if side > 0 else 0.08, -0.19, 0.76 if side > 0 else 1.16)
		_limb(_upper_solid, shoulder, elbow, 0.19, DARK)
		_limb(_upper_solid, elbow, hand, 0.18, ARMOR)
		_ellipsoid(_upper_solid, shoulder, Vector3(0.29, 0.29, 0.30), DARK)
		_plate(_upper_solid, shoulder + Vector3(0, 0.10, 0.05), Vector3(0.58, 0.48, 0.60), ARMOR, Vector3(0.12, 0, side * 0.15))
		_plate(_upper_solid, shoulder + Vector3(0, 0.16, 0.30), Vector3(0.40, 0.20, 0.12), EDGE)
		_ellipsoid(_upper_solid, hand, Vector3(0.16, 0.16, 0.22), DARK)
	# Compact launcher with faceted housing, heat fins, bright chamber and split muzzle.
	_plate(_upper_solid, Vector3(0.36, -0.03, 0.95), Vector3(0.43, 0.32, 1.17), DARK)
	_plate(_upper_solid, Vector3(0.36, 0.12, 0.79), Vector3(0.37, 0.18, 0.84), EDGE.darkened(0.18))
	_plate(_upper_solid, Vector3(0.36, -0.26, 0.65), Vector3(0.18, 0.38, 0.24), DARK, Vector3(-0.23, 0, 0))
	_plate(_upper_solid, Vector3(0.36, -0.03, 0.33), Vector3(0.30, 0.25, 0.45), ARMOR)
	for fin in 4:
		_plate(_upper_solid, Vector3(0.36, 0.26, 0.64 + fin * 0.14), Vector3(0.30, 0.08, 0.055), DARK)
	_limb(_upper_glow, Vector3(0.36, -0.01, 1.28), Vector3(0.36, -0.01, 1.97), 0.11, LIGHT)
	for side in [-1.0, 1.0]:
		_plate(_upper_solid, Vector3(0.36 + side * 0.16, -0.01, 1.72), Vector3(0.13, 0.27, 0.70), ARMOR)
		_plate(_upper_glow, Vector3(0.36 + side * 0.232, 0.02, 1.36), Vector3(0.018, 0.085, 0.46), LIGHT)
	muzzle = Marker3D.new()
	muzzle.position = Vector3(0.36, -0.01, 2.10)
	upper.add_child(muzzle)
	_finish(_solid, self, false)
	_finish(_glow, self, true)
	_finish(_upper_solid, upper, false)
	_finish(_upper_glow, upper, true)
	# The ArrayMeshes retain the finished geometry; discard construction buffers.
	_solid = null
	_glow = null
	_upper_solid = null
	_upper_glow = null

func animate(alpha: float, time: float, since_fire: float) -> void:
	visible = alpha > 0.001
	for material in _materials:
		material.set_shader_parameter("visibility", alpha)
		material.set_shader_parameter("phase", time)
	var recoil := exp(-maxf(0, since_fire) * 12.0) if since_fire >= 0 and since_fire < 0.7 else 0.0
	upper.rotation.x = -0.10 + sin(time * 1.8) * 0.015 - recoil * 0.12
	upper.position.z = -recoil * 0.13

func _finish(surface: SurfaceTool, parent: Node3D, glow: bool) -> void:
	surface.index()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("luminous", 0.65 if glow else 0.0)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	_materials.append(material)

func _ellipsoid(surface: SurfaceTool, at: Vector3, size: Vector3, color: Color) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 16
	sphere.rings = 8
	_append(surface, sphere, Transform3D(Basis.IDENTITY.scaled(size), at), color)

func _limb(surface: SurfaceTool, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = a.distance_to(b) + radius
	shape.radial_segments = 12
	shape.rings = 4
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	if x.length_squared() < 0.1: x = Vector3.RIGHT
	_append(surface, shape, Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5), color)

func _append(surface: SurfaceTool, mesh: Mesh, transform: Transform3D, color: Color) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := transform.basis.inverse().transposed()
	for index in indices:
		surface.set_color(color)
		surface.set_normal((normal_basis * normals[index]).normalized())
		surface.add_vertex(transform * vertices[index])

func _plate(surface: SurfaceTool, at: Vector3, size: Vector3, color: Color, rotation := Vector3.ZERO) -> void:
	var transform := Transform3D(Basis.from_euler(rotation), at)
	var outline := [Vector2(-0.36, -0.5), Vector2(0.36, -0.5), Vector2(0.5, -0.34), Vector2(0.5, 0.34), Vector2(0.36, 0.5), Vector2(-0.36, 0.5), Vector2(-0.5, 0.34), Vector2(-0.5, -0.34)]
	for i in 8:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % 8]
		var front_a := transform * Vector3(a.x * size.x * 0.84, a.y * size.y * 0.84, size.z * 0.5)
		var front_b := transform * Vector3(b.x * size.x * 0.84, b.y * size.y * 0.84, size.z * 0.5)
		var edge_a := transform * Vector3(a.x * size.x, a.y * size.y, size.z * 0.26)
		var edge_b := transform * Vector3(b.x * size.x, b.y * size.y, size.z * 0.26)
		_triangle(surface, transform * Vector3(0, 0, size.z * 0.5), front_a, front_b, color)
		_quad(surface, front_a, front_b, edge_a, edge_b, color.lightened(0.08))
		_quad(surface, edge_a, edge_b, transform * Vector3(a.x * size.x, a.y * size.y, -size.z * 0.5), transform * Vector3(b.x * size.x, b.y * size.y, -size.z * 0.5), color.darkened(0.16))
		_triangle(surface, transform * Vector3(0, 0, -size.z * 0.5), transform * Vector3(b.x * size.x, b.y * size.y, -size.z * 0.5), transform * Vector3(a.x * size.x, a.y * size.y, -size.z * 0.5), color)

func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_triangle(surface, a, c, b, color)
	_triangle(surface, b, c, d, color)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for vertex: Vector3 in [a, b, c]:
		surface.set_normal(normal)
		surface.set_color(color)
		surface.add_vertex(vertex)
