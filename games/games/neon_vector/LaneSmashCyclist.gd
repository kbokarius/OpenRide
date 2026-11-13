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
var _engine: StandardMaterial3D
var _limb_mesh: CylinderMesh

func _ready() -> void:
	_alloy = material(Color("8cbacb"), 0.25)
	_suit = material(Color("6f8294"), 0.03)
	_armor = material(Color("263747"), 0.025)
	_engine = material(Color("9ee9ff"), 1.2)
	_dark = material(Color("1b2530"), 0.0)
	_limb_mesh = CylinderMesh.new()
	_limb_mesh.top_radius = 1
	_limb_mesh.bottom_radius = 1
	_limb_mesh.height = 1
	_limb_mesh.radial_segments = 8
	for z in [-1.05, 1.05]:
		var wheel := Node3D.new()
		wheel.position = Vector3(0, 0.67, z)
		add_child(wheel)
		wheels.append(wheel)
		for ring_data in [[0.59, 0.67, _dark], [0.54, 0.58, _alloy]]:
			var ring := TorusMesh.new()
			ring.inner_radius = ring_data[0]
			ring.outer_radius = ring_data[1]
			ring.rings = 28
			ring.ring_segments = 6
			var rim := mesh(ring, ring_data[2], wheel)
			rim.rotation.z = PI / 2
		var disc := CylinderMesh.new()
		disc.top_radius = 0.49
		disc.bottom_radius = 0.49
		disc.height = 0.10
		disc.radial_segments = 12
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
	# Angular monocoque, swept fork panels, rear fins and twin light pods.
	# The front tire remains the foremost collision point; the crank/legs stay exposed.
	fairing(Vector3(0, 1.36, -0.32), Vector3(0.48, 0.38, 1.88), _armor)
	fairing(Vector3(0, 1.56, -0.42), Vector3(0.18, 0.08, 1.64), _alloy)
	for side in [-1, 1]:
		fairing(Vector3(side * 0.17, 0.98, -0.91), Vector3(0.12, 0.7, 0.64), _armor)
		fairing(Vector3(side * 0.32, 1.35, 0.83), Vector3(0.20, 0.28, 1.20), _armor)
		fairing(Vector3(side * 0.39, 1.65, 0.98), Vector3(0.07, 0.52, 0.56), _alloy)
		var pod := CylinderMesh.new()
		pod.top_radius = 0.11
		pod.bottom_radius = 0.14
		pod.height = 0.18
		pod.radial_segments = 10
		var light := mesh(pod, _engine)
		light.position = Vector3(side * 0.32, 1.35, 1.45)
		light.rotation.x = PI / 2
	# Torso/helmet silhouette is intentionally human, with shoulders, bent arms and legs.
	var torso := CapsuleMesh.new()
	torso.radius = 0.29
	torso.height = 0.98
	torso.radial_segments = 12
	torso.rings = 5
	var body := mesh(torso, _suit)
	body.position = Vector3(0, 2.12, 0.02)
	body.rotation.x = -0.65
	body.scale.x = 1.22
	var helmet := SphereMesh.new()
	helmet.radius = 0.27
	helmet.height = 0.5
	helmet.radial_segments = 16
	helmet.rings = 8
	var head := mesh(helmet, _suit)
	head.position = Vector3(0, 2.78, -0.48)
	head.scale.z = 1.25
	var visor := BoxMesh.new()
	visor.size = Vector3(0.43, 0.15, 0.1)
	mesh(visor, _alloy).position = Vector3(0, 2.77, -0.79)
	for side in [-1, 1]:
		var shoulder := Vector3(side * 0.32, 2.42, -0.25)
		var elbow := Vector3(side * 0.45, 2.03, -0.44)
		var hand := Vector3(side * 0.43, 1.82, -0.95)
		segment(limb(_suit), shoulder, elbow, 0.12)
		segment(limb(_dark), elbow, hand, 0.085)
		legs.append(limb(_dark))
		legs.append(limb(_suit))
		crank_arms.append(limb(_alloy))
		var pedal := BoxMesh.new()
		pedal.size = Vector3(0.23, 0.12, 0.38)
		pedals.append(mesh(pedal, _dark))
	animate(0, 0)

func animate(rpm: float, delta: float) -> void:
	cadence = clampf(rpm, 0, 250)
	crank_phase = fposmod(crank_phase + cadence / 60.0 * TAU * delta, TAU)
	if _engine: _engine.emission_energy_multiplier = 0.6 + cadence / 140.0
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
	node.transform = Transform3D(Basis(Quaternion(Vector3.UP, direction.normalized())).scaled_local(Vector3(radius, direction.length(), radius)), (start + finish) * 0.5)


func set_opacity(alpha: float) -> void:
	if not translucent: return
	for surface in [_alloy, _suit, _dark, _armor, _engine]:
		if surface: surface.albedo_color.a = 0.28 * alpha


func fairing(at: Vector3, size: Vector3, surface_material: Material) -> void:
	var vertices := [Vector3(0, 0.05, -0.5), Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(-0.32, 0.5, 0.28), Vector3(0.32, 0.5, 0.28)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in [[0, 2, 1], [0, 1, 3], [0, 4, 2], [0, 3, 4], [1, 2, 4], [1, 4, 3]]:
		for index in triangle: surface.add_vertex(vertices[index] * size)
	surface.generate_normals()
	mesh(surface.commit(), surface_material).position = at
