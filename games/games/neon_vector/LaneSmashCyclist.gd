class_name LaneSmashCyclist
extends Node3D
## Lightweight articulated cyclist. One crank revolution per measured cadence revolution.
const WHEEL_RADIUS := 0.67
const FRONT_REACH := 1.05 + WHEEL_RADIUS
var crank_phase := 0.0
var cadence := 0.0
var translucent := false
var wheels: Array[Node3D] = []
var legs: Array[MeshInstance3D] = []
var pedals: Array[MeshInstance3D] = []
var crank_arms: Array[MeshInstance3D] = []
var _alloy: StandardMaterial3D
var _suit: StandardMaterial3D
var _dark: StandardMaterial3D
var _armor: StandardMaterial3D
var _limb_mesh: CylinderMesh
var _body_limb: CapsuleMesh
var knees: Array[MeshInstance3D] = []

func _ready() -> void:
	_alloy = material(Color("8cbacb"), 0.08)
	_suit = material(Color("344653"), 0.0)
	_suit.metallic = 0.0
	_suit.roughness = 1.0
	_suit.metallic_specular = 0.0
	_armor = material(Color("263747"), 0.025)
	_dark = material(Color("1b2530"), 0.0)
	_limb_mesh = CylinderMesh.new()
	_limb_mesh.top_radius = 1
	_limb_mesh.bottom_radius = 1
	_limb_mesh.height = 1
	_limb_mesh.radial_segments = 16
	_body_limb = CapsuleMesh.new()
	_body_limb.radius = 1.0
	_body_limb.height = 4.0
	_body_limb.radial_segments = 20
	_body_limb.rings = 8
	for z in [-1.05, 1.05]:
		var wheel := Node3D.new()
		wheel.position = Vector3(0, 0.67, z)
		add_child(wheel)
		wheels.append(wheel)
		for ring_data in [[0.59, 0.67, _dark], [0.54, 0.58, _alloy]]:
			var ring := TorusMesh.new()
			ring.inner_radius = ring_data[0]
			ring.outer_radius = ring_data[1]
			ring.rings = 48
			ring.ring_segments = 10
			var rim := mesh(ring, ring_data[2], wheel)
			rim.rotation.z = PI / 2
		var disc := CylinderMesh.new()
		disc.top_radius = 0.49
		disc.bottom_radius = 0.49
		disc.height = 0.10
		disc.radial_segments = 32
		mesh(disc, _armor, wheel).rotation.z = PI / 2
		for angle in [0.0, PI / 3, 2 * PI / 3]:
			var spoke := limb(_alloy, wheel)
			var edge := Vector3(0, cos(angle), sin(angle)) * 0.55
			segment(spoke, -edge, edge, 0.018)
	var rear := Vector3(0, 0.67, 1.05)
	var front := Vector3(0, 0.67, -1.05)
	var crank := Vector3(0, 0.72, 0.1)
	var saddle := Vector3(0, 1.66, 0.42)
	var stem := Vector3(0, 1.6, -0.82)
	for pair in [[rear, crank], [crank, saddle], [saddle, rear], [saddle, stem], [stem, crank], [stem, front]]:
		segment(limb(_alloy), pair[0], pair[1], 0.055)
	var seat := BoxMesh.new()
	seat.size = Vector3(0.35, 0.12, 0.48)
	mesh(seat, _dark).position = saddle
	segment(limb(_dark), stem, Vector3(0, 1.82, -0.95), 0.045)
	segment(limb(_alloy), Vector3(-0.47, 1.82, -0.95), Vector3(0.47, 1.82, -0.95), 0.045)
	# Streamlined frame and fork; no rear fins, exhausts or glowing pods.
	fairing(Vector3(0, 1.36, -0.32), Vector3(0.40, 0.34, 1.68), _armor)
	fairing(Vector3(0, 1.56, -0.42), Vector3(0.12, 0.05, 1.45), _alloy)
	for side in [-1, 1]:
		fairing(Vector3(side * 0.17, 0.98, -0.91), Vector3(0.10, 0.7, 0.64), _armor)
	# Torso/helmet silhouette is intentionally human, with shoulders, bent arms and legs.
	# Smooth fitted riding suit, tapered torso and rounded shoulders/hips.
	var pelvis := ellipsoid(Vector3(0.30, 0.23, 0.28), _suit)
	pelvis.position = Vector3(0, 1.85, 0.34)
	var body := ellipsoid(Vector3(0.34, 0.52, 0.22), _suit)
	body.position = Vector3(0, 2.18, 0.02)
	body.rotation.x = -0.65
	var neck := ellipsoid(Vector3(0.10, 0.17, 0.10), _dark)
	neck.position = Vector3(0, 2.60, -0.31)
	var head := ellipsoid(Vector3(0.25, 0.25, 0.32), _armor)
	head.position = Vector3(0, 2.80, -0.47)
	var visor := ellipsoid(Vector3(0.22, 0.095, 0.13), _alloy)
	visor.position = Vector3(0, 2.79, -0.72)
	for side in [-1, 1]:
		var shoulder := Vector3(side * 0.32, 2.42, -0.25)
		var elbow := Vector3(side * 0.45, 2.03, -0.44)
		var hand := Vector3(side * 0.43, 1.82, -0.95)
		segment(mesh(_body_limb, _suit), shoulder, elbow, 0.13)
		segment(mesh(_body_limb, _suit), elbow, hand, 0.10)
		ellipsoid(Vector3.ONE * 0.13, _suit).position = shoulder
		ellipsoid(Vector3.ONE * 0.105, _suit).position = elbow
		ellipsoid(Vector3(0.09, 0.09, 0.14), _dark).position = hand
		legs.append(mesh(_body_limb, _suit))
		legs.append(mesh(_body_limb, _suit))
		knees.append(ellipsoid(Vector3.ONE * 0.11, _suit))
		crank_arms.append(limb(_alloy))
		var pedal := BoxMesh.new()
		pedal.size = Vector3(0.23, 0.12, 0.38)
		pedals.append(mesh(pedal, _dark))
	animate(0, 0)

func animate(rpm: float, delta: float) -> void:
	cadence = clampf(rpm, 0, 250)
	crank_phase = fposmod(crank_phase + cadence / 60.0 * TAU * delta, TAU)
	for wheel in wheels:
		wheel.rotation.x = -crank_phase * 2.6
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var phase := crank_phase + i * PI
		var ankle := Vector3(side * 0.23, 0.72 + sin(phase) * 0.32, 0.1 + cos(phase) * 0.32)
		var hip := Vector3(side * 0.22, 1.82, 0.38)
		var knee := Vector3(side * 0.28, 1.29 + sin(phase) * 0.22, -0.27 + cos(phase) * 0.16)
		segment(legs[i * 2], hip, knee, 0.14)
		segment(legs[i * 2 + 1], knee, ankle, 0.095)
		knees[i].position = knee
		segment(crank_arms[i], Vector3(side * 0.2, 0.72, 0.1), ankle, 0.035)
		pedals[i].position = ankle

func tint(accent: Color) -> void:
	if _alloy:
		_alloy.albedo_color = Color(accent, 0.28 if translucent else 1.0)
		_alloy.emission = accent

func material(color: Color, glow: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color, 0.24 if translucent else 1.0)
	result.metallic = 0.35
	result.roughness = 0.48
	result.emission_enabled = glow > 0
	result.emission = color
	result.emission_energy_multiplier = glow
	if translucent: result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return result

func mesh(shape: Mesh, surface: Material, parent: Node = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = surface
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func limb(surface: Material, parent: Node = self) -> MeshInstance3D:
	return mesh(_limb_mesh, surface, parent)

static func segment(node: MeshInstance3D, start: Vector3, finish: Vector3, radius: float) -> void:
	var direction := finish - start
	node.transform = Transform3D(Basis(Quaternion(Vector3.UP, direction.normalized())).scaled_local(Vector3(radius, direction.length() / (4.0 if node.mesh is CapsuleMesh else 1.0), radius)), (start + finish) * 0.5)


func set_opacity(alpha: float) -> void:
	if not translucent: return
	for surface in [_alloy, _suit, _dark, _armor]:
		if surface: surface.albedo_color.a = 0.28 * alpha


func fairing(at: Vector3, size: Vector3, surface_material: Material) -> void:
	var vertices := [Vector3(0, 0.05, -0.5), Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(-0.32, 0.5, 0.28), Vector3(0.32, 0.5, 0.28)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in [[0, 2, 1], [0, 1, 3], [0, 4, 2], [0, 3, 4], [1, 2, 4], [1, 4, 3]]:
		for index in triangle: surface.add_vertex(vertices[index] * size)
	surface.generate_normals()
	mesh(surface.commit(), surface_material).position = at


func ellipsoid(dimensions: Vector3, surface: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var node := mesh(sphere, surface)
	node.scale = dimensions
	return node
