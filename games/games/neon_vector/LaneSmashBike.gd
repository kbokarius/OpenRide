class_name LaneSmashBike
extends Node3D
## The rider's machine: a long, low hyperbike with a faceted hull, glowing hub rings, twin drive
## rotors and thrusters, and an armoured pilot tucked behind the cowl.
##
## Cadence is still the only thing that drives it: the rotors turn once per measured pedal
## revolution (`crank_phase`), the wheels roll at the game speed that cadence gives, and the
## thrusters lengthen with effort. The bike leans into lane changes on its own pivot, so the
## transform the space gives it stays exactly on the road.
##
## The front wheel keeps the contact geometry every marker, mine and section is placed against
## (`WHEEL_RADIUS`, `FRONT_REACH`).

## The model is authored at design size and shown at SCALE; the contact constants are the
## shown (world) sizes, so markers meet the tyre the player actually sees.
const SCALE := 1.3
const DESIGN_RADIUS := 0.67
const DESIGN_FRONT := 1.05
const DESIGN_REAR := 1.50
const WHEEL_RADIUS := DESIGN_RADIUS * SCALE
const FRONT_AXLE := DESIGN_FRONT * SCALE
const AXLE_HEIGHT := WHEEL_RADIUS + 0.05
const FRONT_REACH := FRONT_AXLE + WHEEL_RADIUS
const MAX_CADENCE := 140.0
const MAX_SPEED := 60.0 / 3.6

const HULL := Color(0.12, 0.14, 0.20, 0.95)
const PANEL := Color(0.30, 0.34, 0.43, 0.8)
const TYRE := Color(0.035, 0.04, 0.055, 0.2)
const SUIT := Color(0.11, 0.13, 0.18, 0.3)
const ARMOR := Color(0.34, 0.39, 0.49, 0.9)
const LAMP := Color(1.0, 0.95, 0.86, 1.0)

## Hull cross-sections from nose to tail: z, half-width, top, widest height, bottom.
## Forward is -Z. The bottom line clears both wheels.
const STATIONS := [
	[-1.66, 0.04, 1.40, 1.37, 1.34],
	[-1.14, 0.36, 1.70, 1.52, 1.40],
	[-0.62, 0.58, 1.88, 1.58, 1.30],
	[-0.16, 0.62, 1.76, 1.32, 0.58],
	[0.38, 0.58, 1.50, 1.02, 0.34],
	[0.86, 0.44, 1.34, 1.06, 0.66],
	[1.22, 0.40, 1.56, 1.46, 1.36],
	[1.74, 0.32, 1.76, 1.64, 1.50],
	[2.30, 0.05, 1.90, 1.87, 1.84],
]
const ROTOR_AT := Vector3(0.60, 0.80, 0.36)
const NOZZLE_AT := Vector3(0.15, 1.60, 2.10)

static var _cache := {}

var crank_phase := 0.0
var cadence := 0.0
var wheel_phase := 0.0
var lean := 0.0
var translucent := false
var pivot: Node3D
var wheels: Array[Node3D] = []
var rotors: Array[Node3D] = []
var flames: MeshInstance3D
var underglow: MeshInstance3D
var _materials: Array[ShaderMaterial] = []
var _flame_material: ShaderMaterial
var _glow_material: ShaderMaterial
var _accent := Color("67d8ff")
var _lane := NAN
var _clock := 0.0
var _thrust := 0.0
var _opacity := 1.0


func _ready() -> void:
	_build_meshes()
	pivot = Node3D.new()
	pivot.name = "Pivot"
	pivot.scale = Vector3.ONE * SCALE
	add_child(pivot)
	_part(_cache.body, pivot)
	for z: float in [-DESIGN_FRONT, DESIGN_REAR]:
		var wheel := Node3D.new()
		wheel.position = Vector3(0, DESIGN_RADIUS, z)
		pivot.add_child(wheel)
		_part(_cache.wheel, wheel)
		wheels.append(wheel)
	for side: float in [-1.0, 1.0]:
		var rotor := Node3D.new()
		rotor.position = Vector3(side * ROTOR_AT.x, ROTOR_AT.y, ROTOR_AT.z)
		pivot.add_child(rotor)
		_part(_cache.rotor, rotor)
		rotors.append(rotor)
	if not translucent:
		_flame_material = LaneSmashLook.emissive(true, 1.0)
		flames = MeshInstance3D.new()
		flames.mesh = _cache.flames
		flames.material_override = _flame_material
		flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(flames)
		_glow_material = LaneSmashLook.emissive(true, 1.0)
		underglow = MeshInstance3D.new()
		underglow.mesh = _cache.underglow
		underglow.material_override = _glow_material
		underglow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(underglow)  # stays flat on the road while the bike leans
	tint(_accent)
	animate(0, 0)


func _part(mesh: Mesh, parent: Node3D) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = preload("res://games/neon_vector/ls_hologram.gdshader") if translucent else preload("res://games/neon_vector/ls_hull.gdshader")
	_materials.append(material)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


## One drive revolution per measured pedal revolution; wheels roll at the capped game speed.
func animate(rpm: float, delta: float) -> void:
	cadence = clampf(rpm, 0, 250)
	crank_phase = fposmod(crank_phase + cadence / 60.0 * TAU * delta, TAU)
	# The speed the road passes under the tyres on screen (the world is drawn STRETCH to one).
	var speed := minf(cadence, MAX_CADENCE) / MAX_CADENCE * MAX_SPEED * NeonSpace.STRETCH
	wheel_phase = fposmod(wheel_phase + speed / WHEEL_RADIUS * delta, TAU)  # true rolling contact
	_clock += delta
	if pivot == null: return
	for wheel in wheels: wheel.rotation.x = -wheel_phase
	for i in rotors.size(): rotors[i].rotation.x = -crank_phase * (1.0 if i == 0 else -1.0)
	var effort := clampf(cadence / MAX_CADENCE, 0.0, 1.0)
	_thrust = lerpf(_thrust, effort, 1.0 - exp(-delta * 5.0)) if delta > 0 else effort
	# A light idle float and a road hum that rises with speed; never enough to leave the lane.
	pivot.position.y = 0.012 * sin(_clock * 2.1) * (1.0 - _thrust) + 0.006 * sin(_clock * 31.0) * _thrust
	pivot.rotation.z = lean
	pivot.rotation.x = -0.035 * _thrust
	var beat := 0.5 + 0.5 * sin(crank_phase * 2.0)
	for material in _materials:
		if translucent: material.set_shader_parameter("phase", _clock)
		else: material.set_shader_parameter("pulse", 0.25 * beat * _thrust + 0.12 * _thrust)
	if flames:
		flames.visible = _thrust > 0.03
		flames.scale = Vector3(1.0, 1.0, 0.25 + _thrust * (1.0 + 0.12 * sin(_clock * 47.0)))
		_flame_material.set_shader_parameter("energy", 1.2 + _thrust * 2.4)
		_glow_material.set_shader_parameter("energy", 0.30 + _thrust * 0.35 + beat * 0.06)


## Leans into lane changes, including travel inside the two outside lanes.
func steer(lane: float, delta: float) -> void:
	if not is_finite(_lane) or delta <= 0.0:
		_lane = lane
		lean = 0.0 if delta <= 0.0 else lean
		return
	var rate := (lane - _lane) / delta  # lanes per second; positive moves right (+X)
	_lane = lane
	lean = lerpf(lean, clampf(-rate * 0.16, -0.42, 0.42), 1.0 - exp(-delta * 9.0))


func tint(accent: Color) -> void:
	_accent = accent
	for material in _materials:
		if translucent:
			material.set_shader_parameter("tint", accent.lerp(Color(0.72, 0.8, 1.0), 0.45))
		else:
			material.set_shader_parameter("accent", accent)
			material.set_shader_parameter("rim_color", LaneSmashLook.companion(accent))
	if _flame_material: _flame_material.set_shader_parameter("tint", accent.lerp(Color.WHITE, 0.3))
	if _glow_material: _glow_material.set_shader_parameter("tint", accent)


func set_opacity(alpha: float) -> void:
	_opacity = alpha
	if not translucent: return
	for material in _materials: material.set_shader_parameter("visibility", alpha)


# --- Model ---

static func _build_meshes() -> void:
	if not _cache.is_empty(): return
	_cache["body"] = _body_mesh()
	_cache["wheel"] = _wheel_mesh()
	_cache["rotor"] = _rotor_mesh()
	_cache["flames"] = _flame_mesh()
	_cache["underglow"] = _underglow_mesh()


static func _kit() -> MeshKit3D:
	var kit := MeshKit3D.new()
	kit.flags = true
	kit.outline = 0.0  # UV.x: accent share
	kit.glow = 0.0     # UV.y: self-lit share
	return kit


static func _ring(station: Array) -> PackedVector3Array:
	var z: float = station[0]
	var w: float = station[1]
	var top: float = station[2]
	var mid: float = station[3]
	var bottom: float = station[4]
	var shoulder := lerpf(top, mid, 0.28)
	var chine := lerpf(bottom, mid, 0.30)
	return PackedVector3Array([
		Vector3(0, top, z), Vector3(w * 0.58, shoulder, z), Vector3(w, mid, z), Vector3(w * 0.62, chine, z),
		Vector3(0, bottom, z), Vector3(-w * 0.62, chine, z), Vector3(-w, mid, z), Vector3(-w * 0.58, shoulder, z)])


## A quad wound so its flat normal faces away from `inside`.
static func _skin(kit: MeshKit3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, color: Color) -> void:
	var normal := (c - a).cross(b - a)
	if normal.dot((a + b + c + d) * 0.25 - inside) < 0.0: kit.quad(a, d, c, b, color)
	else: kit.quad(a, b, c, d, color)


static func _body_mesh() -> ArrayMesh:
	var kit := _kit()
	# Faceted hull: upper panels a shade lighter than the belly, so the form reads at a glance.
	for i in STATIONS.size() - 1:
		var near := _ring(STATIONS[i])
		var far := _ring(STATIONS[i + 1])
		var inside := Vector3(0, (float(STATIONS[i][3]) + float(STATIONS[i + 1][3])) * 0.5, (float(STATIONS[i][0]) + float(STATIONS[i + 1][0])) * 0.5)
		for p in 8:
			var q := (p + 1) % 8
			var upper := p in [0, 7]
			var side := p in [1, 6]
			_skin(kit, near[p], near[q], far[q], far[p], inside, PANEL if upper else (HULL.lightened(0.05) if side else HULL))
	# Accent light lines along the widest edge of the hull, nose to tail on both sides.
	kit.outline = 1.0
	kit.glow = 1.0
	for i in range(1, STATIONS.size() - 2):
		for side: float in [-1.0, 1.0]:
			var a := Vector3(side * (float(STATIONS[i][1]) + 0.012), float(STATIONS[i][3]), float(STATIONS[i][0]))
			var b := Vector3(side * (float(STATIONS[i + 1][1]) + 0.012), float(STATIONS[i + 1][3]), float(STATIONS[i + 1][0]))
			kit.add(MeshKit3D.box(Vector3(0.022, 1.0, 0.05)), MeshKit3D.between(a, b), Color.WHITE)
	# Tail light bar and a spine strip down the tail cowl.
	kit.add(MeshKit3D.box(Vector3(0.42, 0.06, 0.07)), MeshKit3D.xf(Vector3(0, 1.80, 2.02)), Color.WHITE)
	for side: float in [-1.0, 1.0]:
		kit.add(MeshKit3D.box(Vector3(0.04, 1.0, 0.045)), MeshKit3D.between(Vector3(side * 0.13, 1.575, 1.24), Vector3(side * 0.10, 1.775, 1.76)), Color.WHITE)
	# Drive housings: a lit ring on each flank around the spinning rotor.
	for side: float in [-1.0, 1.0]:
		kit.add(MeshKit3D.torus(0.19, 0.225, 20, 5), MeshKit3D.xf(Vector3(side * (ROTOR_AT.x - 0.02), ROTOR_AT.y, ROTOR_AT.z), Vector3(0, 0, 90)), Color.WHITE)
	# Headlight.
	kit.outline = 0.0
	kit.add(MeshKit3D.box(Vector3(0.22, 0.05, 0.12)), MeshKit3D.xf(Vector3(0, 1.42, -1.56)), LAMP)
	for side: float in [-1.0, 1.0]:
		kit.add(MeshKit3D.box(Vector3(0.12, 0.04, 0.20)), MeshKit3D.xf(Vector3(side * 0.24, 1.545, -1.24), Vector3(0, side * -24.0, 0)), LAMP)
	kit.glow = 0.0
	# Fork blades, swingarms, drive housings, nozzles, pegs and bars.
	for side: float in [-1.0, 1.0]:
		kit.add(MeshKit3D.box(Vector3(0.07, 1.0, 0.13)), MeshKit3D.between(Vector3(side * 0.22, DESIGN_RADIUS, -DESIGN_FRONT), Vector3(side * 0.30, 1.44, -0.70)), PANEL.darkened(0.2))
		kit.add(MeshKit3D.box(Vector3(0.07, 1.0, 0.15)), MeshKit3D.between(Vector3(side * 0.22, DESIGN_RADIUS, DESIGN_REAR), Vector3(side * 0.32, 0.82, 0.52)), PANEL.darkened(0.2))
		kit.add(MeshKit3D.cylinder(0.185, 0.185, 0.10, 16), MeshKit3D.xf(Vector3(side * (ROTOR_AT.x - 0.05), ROTOR_AT.y, ROTOR_AT.z), Vector3(0, 0, 90)), Color(0.03, 0.035, 0.05, 0.6))
		kit.add(MeshKit3D.cylinder(0.075, 0.105, 0.34, 10), MeshKit3D.xf(Vector3(side * NOZZLE_AT.x, NOZZLE_AT.y, NOZZLE_AT.z - 0.12), Vector3(90, 0, 0)), PANEL)
		kit.add(MeshKit3D.box(Vector3(0.20, 0.05, 0.12)), MeshKit3D.xf(Vector3(side * 0.58, 0.80, 0.90)), PANEL.darkened(0.2))
		# Swept winglets at the cowl give the nose its width from behind.
		kit.quad(Vector3(side * 0.56, 1.60, -0.74), Vector3(side * 0.98, 1.52, -0.42), Vector3(side * 0.94, 1.50, -0.22), Vector3(side * 0.60, 1.54, -0.34), PANEL)
		kit.quad(Vector3(side * 0.60, 1.54, -0.34), Vector3(side * 0.94, 1.50, -0.22), Vector3(side * 0.98, 1.52, -0.42), Vector3(side * 0.56, 1.60, -0.74), PANEL.darkened(0.3))
	kit.add(MeshKit3D.cylinder(0.028, 0.028, 0.92, 8), MeshKit3D.xf(Vector3(0, 1.78, -0.62), Vector3(0, 0, 90)), PANEL.darkened(0.2))
	# Winglet edge lights.
	kit.outline = 1.0
	kit.glow = 1.0
	for side: float in [-1.0, 1.0]:
		kit.add(MeshKit3D.box(Vector3(0.03, 1.0, 0.03)), MeshKit3D.between(Vector3(side * 0.985, 1.525, -0.43), Vector3(side * 0.945, 1.505, -0.21)), Color.WHITE)
	kit.outline = 0.0
	kit.glow = 0.0
	_pilot(kit)
	return kit.commit()


## The pilot: tucked low behind the cowl, armour over a matte suit. The back is what the chase
## camera sees all ride, so it carries the lights: a spine, a chevron and helmet markers.
static func _pilot(kit: MeshKit3D) -> void:
	kit.outline = 0.0
	kit.glow = 0.0
	kit.add(MeshKit3D.blob(Vector3(0.23, 0.18, 0.25), 1.0, 1.0, 10, 6), MeshKit3D.xf(Vector3(0, 1.50, 0.84)), SUIT)
	kit.add(MeshKit3D.tube(PackedVector3Array([Vector3(0, 1.52, 0.78), Vector3(0, 1.80, 0.36), Vector3(0, 1.94, 0.0), Vector3(0, 1.99, -0.14)]),
		PackedFloat32Array([0.19, 0.22, 0.215, 0.12]), 8), Transform3D.IDENTITY, SUIT)
	var back := MeshKit3D.xf(Vector3(0, 2.075, 0.235), Vector3(-36, 0, 0))
	kit.add(MeshKit3D.blob(Vector3(0.245, 0.07, 0.35), 0.45, 0.55, 10, 5), back, ARMOR)
	kit.add(MeshKit3D.blob(Vector3(0.25, 0.10, 0.20), 0.5, 0.6, 10, 5), MeshKit3D.xf(Vector3(0, 1.60, 0.82), Vector3(-20, 0, 0)), ARMOR.darkened(0.35))
	for side: float in [-1.0, 1.0]:
		kit.add(MeshKit3D.blob(Vector3(0.155, 0.075, 0.18), 0.6, 0.7, 8, 5), MeshKit3D.xf(Vector3(side * 0.31, 1.985, 0.0), Vector3(-20, 0, side * -22.0)), ARMOR)
		kit.add(MeshKit3D.tube(PackedVector3Array([Vector3(side * 0.30, 1.93, -0.04), Vector3(side * 0.46, 1.74, -0.30), Vector3(side * 0.44, 1.79, -0.60)]),
			PackedFloat32Array([0.085, 0.075, 0.06]), 6), Transform3D.IDENTITY, SUIT)
		kit.add(MeshKit3D.blob(Vector3(0.07, 0.065, 0.10), 0.6, 0.8, 6, 4), MeshKit3D.xf(Vector3(side * 0.44, 1.80, -0.62)), ARMOR)
		kit.add(MeshKit3D.tube(PackedVector3Array([Vector3(side * 0.20, 1.47, 0.80), Vector3(side * 0.62, 1.28, 0.22), Vector3(side * 0.60, 0.92, 0.80), Vector3(side * 0.60, 0.86, 0.98)]),
			PackedFloat32Array([0.13, 0.11, 0.08, 0.07]), 7), Transform3D.IDENTITY, SUIT)
		kit.add(MeshKit3D.blob(Vector3(0.115, 0.10, 0.155), 0.55, 0.7, 7, 4), MeshKit3D.xf(Vector3(side * 0.645, 1.29, 0.19)), ARMOR)
		kit.add(MeshKit3D.blob(Vector3(0.085, 0.16, 0.10), 0.5, 0.7, 6, 4), MeshKit3D.xf(Vector3(side * 0.66, 1.08, 0.52), Vector3(-58, 0, 0)), ARMOR)
		kit.add(MeshKit3D.box(Vector3(0.13, 0.10, 0.32)), MeshKit3D.xf(Vector3(side * 0.60, 0.86, 0.90)), ARMOR.darkened(0.3))
	# Helmet: a long aero shell with a crest and a wrap-around visor.
	var tilt := Vector3(-14, 0, 0)
	kit.add(MeshKit3D.blob(Vector3(0.20, 0.20, 0.30), 0.85, 0.9, 12, 7), MeshKit3D.xf(Vector3(0, 2.10, -0.34), tilt), ARMOR)
	kit.add(MeshKit3D.box(Vector3(0.045, 0.06, 0.44)), MeshKit3D.xf(Vector3(0, 2.285, -0.20), tilt), ARMOR.lightened(0.12))
	kit.outline = 1.0
	kit.glow = 1.0
	kit.add(MeshKit3D.blob(Vector3(0.18, 0.06, 0.15), 0.6, 0.8, 10, 4), MeshKit3D.xf(Vector3(0, 2.065, -0.515), tilt), Color.WHITE)
	# Rear markers: helmet lights, a spine and a chevron across the back plate.
	for side: float in [-1.0, 1.0]:
		kit.add(MeshKit3D.box(Vector3(0.05, 0.035, 0.03)), MeshKit3D.xf(Vector3(side * 0.085, 2.115, -0.045)), Color.WHITE)
		kit.add(MeshKit3D.box(Vector3(0.03, 0.03, 1.0)), back * MeshKit3D.between(Vector3(side * 0.02, 0.082, 0.20), Vector3(side * 0.17, 0.070, -0.10)).rotated_local(Vector3.RIGHT, PI / 2), Color.WHITE)
	kit.add(MeshKit3D.box(Vector3(0.034, 0.03, 0.50)), back * Transform3D(Basis.IDENTITY, Vector3(0, 0.082, 0.03)), Color.WHITE)
	kit.outline = 0.0
	kit.glow = 0.0


## Tyre, a dished cover, two rim rings of light and a dashed light line round the tread, so the
## wheel reads as spinning from behind as well as from the side.
static func _wheel_mesh() -> ArrayMesh:
	var kit := _kit()
	var sideways := Vector3(0, 0, 90)
	kit.add(MeshKit3D.torus(0.51, DESIGN_RADIUS, 28, 8), MeshKit3D.xf(Vector3.ZERO, sideways), TYRE)
	kit.add(MeshKit3D.cylinder(0.52, 0.52, 0.11, 22), MeshKit3D.xf(Vector3.ZERO, sideways), Color(0.085, 0.10, 0.145, 0.85))
	kit.add(MeshKit3D.cylinder(0.10, 0.10, 0.30, 10), MeshKit3D.xf(Vector3.ZERO, sideways), PANEL)
	kit.outline = 1.0
	kit.glow = 1.0
	for face: float in [-1.0, 1.0]:
		kit.add(MeshKit3D.torus(0.465, 0.51, 28, 5), MeshKit3D.xf(Vector3(face * 0.06, 0, 0), sideways), Color.WHITE)
		for spoke in 3:
			var angle := spoke * TAU / 3.0
			var radial := Vector3(0, cos(angle), sin(angle))
			var tangent := Vector3(0, -sin(angle), cos(angle))
			var along := (radial + tangent * 0.6).normalized()
			var basis := Basis(Vector3.RIGHT * 0.02, along * 0.34, Vector3.RIGHT.cross(along).normalized() * 0.07)
			kit.add(MeshKit3D.box(Vector3.ONE), Transform3D(basis, Vector3(face * 0.062, 0, 0) + radial * 0.26), Color.WHITE)
	for dash in 14:
		var angle := dash * TAU / 14.0
		var radial := Vector3(0, cos(angle), sin(angle))
		var tangent := Vector3(0, -sin(angle), cos(angle))
		kit.add(MeshKit3D.box(Vector3.ONE), Transform3D(Basis(Vector3.RIGHT * 0.075, radial * 0.03, tangent * 0.15), radial * (DESIGN_RADIUS - 0.004)), Color.WHITE)
	return kit.commit()


static func _rotor_mesh() -> ArrayMesh:
	var kit := _kit()
	kit.outline = 1.0
	kit.glow = 1.0
	for blade in 4:
		var angle := blade * TAU / 4.0
		var radial := Vector3(0, cos(angle), sin(angle))
		kit.add(MeshKit3D.box(Vector3(0.03, 0.15, 0.045)), Transform3D(Basis(Vector3.RIGHT, radial, Vector3.RIGHT.cross(radial)), radial * 0.085), Color.WHITE)
	kit.add(MeshKit3D.cylinder(0.04, 0.04, 0.05, 8), MeshKit3D.xf(Vector3.ZERO, Vector3(0, 0, 90)), Color.WHITE)
	return kit.commit()


## Two crossed additive cards per nozzle; scaled along +Z with effort.
static func _flame_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var root := Vector3(side * NOZZLE_AT.x, NOZZLE_AT.y, NOZZLE_AT.z)
		for axis: Vector3 in [Vector3.RIGHT, Vector3.UP]:
			var half := axis * 0.15
			var corners := [[root - half - Vector3(0, 0, 0.25), Vector2(0, 0)], [root + half - Vector3(0, 0, 0.25), Vector2(1, 0)],
				[root + half + Vector3(0, 0, 1.25), Vector2(1, 1)], [root - half + Vector3(0, 0, 1.25), Vector2(0, 1)]]
			for index in [0, 1, 2, 0, 2, 3]:
				surface.set_color(Color.WHITE)
				surface.set_uv(corners[index][1])
				surface.set_normal(Vector3.UP)
				surface.add_vertex(corners[index][0])
	return surface.commit()


static func _underglow_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [[Vector3(-1.45, 0.03, -2.9), Vector2(0, 0)], [Vector3(1.45, 0.03, -2.9), Vector2(1, 0)],
		[Vector3(1.45, 0.03, 3.3), Vector2(1, 1)], [Vector3(-1.45, 0.03, 3.3), Vector2(0, 1)]]
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_color(Color(1, 1, 1, 0.42))
		surface.set_uv(corners[index][1])
		surface.set_normal(Vector3.UP)
		surface.add_vertex(corners[index][0])
	return surface.commit()
