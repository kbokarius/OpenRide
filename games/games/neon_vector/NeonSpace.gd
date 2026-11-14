class_name NeonSpace
extends Node3D
signal target_hit(kind: String)
## Bounded 3D presentation. Every road object is anchored to an absolute course distance.
## The camera moves through that space; scoring never depends on camera/mesh positions.

const SPEED := 18.0
## World metres drawn per road metre. The rules measure the ride in road metres (60 km/h at
## 140 rpm); the picture spreads the road out threefold, so the bike covers three times the
## ground on screen: about 77 mph at 96 rpm and 112 mph flat out, still exactly proportional
## to cadence. Anything measured along the road in this file is in road metres unless it says
## world; sizes of things (the bike, a marker, a mine) are world metres and are divided by
## STRETCH where they are added to a road distance.
const STRETCH := 3.0
const LANE_WIDTH := 3.0
const ROAD_CHUNK_STEPS := 96
const ROAD_CHUNK_COUNT := 5
const STEP := 1.5
const MARKERS := 112
const TRAIL_POINTS := 22
const CAMERA_FOV := 68.0
const CAMERA_BACK := 12.5
const CAMERA_UP := 6.2
const CAMERA_AIM_AHEAD := 34.0
const CAMERA_AIM_UP := 0.5
const GOLD := LaneSmashLook.GOLD
const GREEN := LaneSmashLook.MINT
const VIOLET := LaneSmashLook.VIOLET
## The rail's cross-section beyond the deck edge: (metres outward, metres up), inner base first.
const RAIL_PROFILE := [Vector2(0.0, 0.0), Vector2(0.10, 0.42), Vector2(0.42, 0.42), Vector2(0.62, 0.10), Vector2(0.50, -0.30), Vector2(0.0, -0.22)]

var camera: Camera3D
var rider: LaneSmashBike
var ghost: LaneSmashBike
var world_id := ""
var reduced_motion := false
var distance := 0.0
var coaster := LaneSmashCoaster.new()
var _road_chunks: Array[Dictionary] = []
var road_mesh_builds := 0
var _terrain_course: Dictionary = {}
var _terrain_reduced := false
var _terrain_revision := 0
var _bars: MultiMeshInstance3D
var _arrows: MultiMeshInstance3D
var _crystals: MultiMeshInstance3D
var _shards: MultiMeshInstance3D
var _impacts: Array[Dictionary] = []
var _shockwaves: Array[Dictionary] = []
var _rings: MultiMeshInstance3D
var _flashes: MultiMeshInstance3D
var _collected := {}
var _previous_distance := -1.0
var _previous_ms := -1
var _terrain_id := ""
var _unit_speed := SPEED
var ghost_distance := -1.0
var ghost_cadence := 80.0
var scenery: LaneSmashScenery
var fx: LaneSmashFx
var _glows: MultiMeshInstance3D
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_material: ShaderMaterial
var _trail_points: Array[Vector2] = []
var _trauma := 0.0
var _shake_clock := 0.0
var lite := false  ## the performance tier: no streaks, glow cards or trail
var environment_id := ""
var _structures: LaneSmashEnvironment
var sections: LaneSmashSections
var bombs: LaneSmashBombs
var barrage_view: LaneSmashBarrageSpace
var gunfire_view: LaneSmashGunfire
var portal_distance := 250.0
var music_pulse := 0.0  ## 0..1 beat envelope from the jukebox; zero when music is silent
var music := Vector4.ZERO  ## eased bass, mids, treble and kick swell; zero when music is silent
var music_bands := PackedFloat32Array()  ## the jukebox's eight live bands, or empty
var music_beats := 0  ## the jukebox's kick counter: each new kick sends a pulse down the seams
## Pulses of light that run ahead along the lane seams. One launches from the bike on every
## kick of the music (a soft, steady rhythm stands in when nothing is playing).
const WAVES := 4           ## alive at once; the road's shaders loop over this many per pixel
const WAVE_SPEED := 190.0  ## world m/s ahead of the bike
const WAVE_LIFE := 1.8     ## seconds; by then a pulse is past the visible road
const WAVE_IDLE_EVERY := 0.9
var _wave_front := PackedFloat32Array()  ## world metres along the route
var _wave_gain := PackedFloat32Array()
var _wave_age := PackedFloat32Array()
var _wave_power := PackedFloat32Array()
var _wave_next := 0
var _wave_wait := 0.0
var _beats_seen := -1
var _seams := Vector4.ZERO  ## eased bass, low mids, high mids, treble: one per seam from the centre out
var _road_material: ShaderMaterial
var _line_material: ShaderMaterial
var _curtain_material: ShaderMaterial
var _flow := 0.0
var impact_count := 0
var _env: Environment
var palette_accent := Color("8db9c9")  ## the saved, muted track palette (sky and menus use it)
var _accent := Color("67d8ff")  ## its vivid emissive form for the 3D scene
var _second := Color("a481ff")
var _road_index := -999999
var _warming := true


func _ready() -> void:
	var environment := WorldEnvironment.new()
	_env = make_environment()
	environment.environment = _env
	add_child(environment)
	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.near = 0.2
	camera.far = 4000
	add_child(camera)
	camera.make_current()
	_road_material = ShaderMaterial.new()
	_road_material.shader = preload("res://games/neon_vector/coaster_road.gdshader")
	_line_material = ShaderMaterial.new()
	_line_material.shader = preload("res://games/neon_vector/coaster_rail.gdshader")
	_curtain_material = ShaderMaterial.new()
	_curtain_material.shader = preload("res://games/neon_vector/coaster_glow.gdshader")
	_road_material.render_priority = -10
	_line_material.render_priority = -9
	_curtain_material.render_priority = -8
	for i in ROAD_CHUNK_COUNT:
		_road_chunks.append({"index": -999999, "road": _mesh(ArrayMesh.new(), _road_material), "rails": _mesh(ArrayMesh.new(), _line_material),
			"glow": _mesh(ArrayMesh.new(), _curtain_material)})
	scenery = LaneSmashScenery.new()
	scenery.space = self
	add_child(scenery)
	# Pools of light under the markers, then the markers themselves: gold bars, mint arrows.
	_glows = _instances(_floor_card(), MARKERS * 2, LaneSmashLook.emissive(true, 1.0))
	_glows.multimesh.visible_instance_count = 0
	_bars = _instances(_bar(), MARKERS, _material(Color.WHITE, 2.1, true, true))
	_arrows = _instances(_chevron(), MARKERS, _material(Color.WHITE, 1.9, true, true))
	var crystal := PrismMesh.new()
	crystal.size = Vector3(1, 1.3, 0.7)
	_crystals = _instances(crystal, MARKERS, _material(Color.WHITE, 1.8, true, true))
	_shards = _instances(_shard(), 192, _material(Color.WHITE, 2.4, true, true))
	_shards.multimesh.visible_instance_count = 0
	var ring_material := ShaderMaterial.new()
	ring_material.shader = preload("res://games/neon_vector/fx_ring.gdshader")
	_rings = _instances(_floor_card(), 12, ring_material)
	_flashes = _instances(LaneSmashFx._card(), 12, LaneSmashLook.emissive(true, 2.6))
	_rings.multimesh.visible_instance_count = 0
	_flashes.multimesh.visible_instance_count = 0
	fx = LaneSmashFx.new()
	add_child(fx)
	_trail_mesh = ImmediateMesh.new()
	_trail_material = LaneSmashLook.emissive(true, 1.6)
	_trail_material.set_shader_parameter("soft", 0.0)
	_trail = _mesh(_trail_mesh, _trail_material)
	rider = LaneSmashBike.new()
	add_child(rider)
	ghost = LaneSmashBike.new()
	ghost.translucent = true
	add_child(ghost)
	ghost.visible = false
	_structures = LaneSmashEnvironment.new()
	add_child(_structures)
	_structures.configure(_env)
	sections = LaneSmashSections.new()
	sections.space = self
	add_child(sections)
	bombs = LaneSmashBombs.new()
	bombs.space = self
	add_child(bombs)
	barrage_view = LaneSmashBarrageSpace.new()
	barrage_view.space = self
	add_child(barrage_view)
	gunfire_view = LaneSmashGunfire.new()
	gunfire_view.space = self
	add_child(gunfire_view)
	set_world("arctic")
	# Exercise every material during the host's three-second intro. Mobile GL can
	# otherwise compile the first ghost/arrow/crystal shader during scored gameplay.
	get_tree().create_timer(1.0).timeout.connect(func(): _warming = false)


## The ride's grade, shared with the model viewer. Every surface lights itself (unshaded), so
## there is no engine light or fog here: only tonemapping and the bloom that carries the neon
## look. Emissive seams, markers and effects output values above the threshold and bleed out.
static func make_environment(bloom := true) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("030615")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("778bc4")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 5.0
	env.glow_enabled = bloom
	env.glow_intensity = 0.85
	env.glow_strength = 1.0
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.95
	env.glow_hdr_scale = 1.6
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = bloom
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 1.14
	return env


func set_world(id: String) -> void:
	if world_id == id or _env == null:
		return
	world_id = id
	var world := NeonWorlds.world(id)
	palette_accent = Color(world.accent)
	_accent = LaneSmashLook.vivid(palette_accent)
	_second = LaneSmashLook.companion(palette_accent)
	for material in [_road_material, _line_material, _curtain_material]:
		material.set_shader_parameter("accent", _accent)
		material.set_shader_parameter("second", _second)
	_env.background_color = Color(world.sky).darkened(0.6)
	scenery.set_palette(_accent, _second)
	_trail_material.set_shader_parameter("tint", _accent)
	if rider: rider.tint(_accent)
	if ghost: ghost.tint(_accent)
	_invalidate_road()


func prepare_terrain(course: Dictionary) -> void:
	# Rules replace their immutable course dictionary when a saved snapshot is loaded.
	# IDs alone are insufficient: saved presentation data may differ from the generator.
	if is_same(course, _terrain_course) and reduced_motion == _terrain_reduced: return
	_terrain_course = course
	_terrain_reduced = reduced_motion
	_terrain_revision += 1
	_terrain_id = str(_terrain_revision)
	coaster.stretch = STRETCH
	coaster.build(float(course.get("roadLengthMeters", int(course.get("durationMs", 0)) / 1000.0 * _unit_speed)), int(course.get("seed", 17)), reduced_motion, course.get("presentation", {}))
	_road_material.set_shader_parameter("opacity", coaster.route.opacity)
	_invalidate_road()

func _invalidate_road() -> void:
	_road_index = -999999
	for chunk in _road_chunks: chunk.index = -999999

## The chase camera for a rider at `s`: behind and above, aimed down the road. One definition
## for the live view and for anything placed in screen space (the attackers' slots).
func camera_pose(s: float) -> Transform3D:
	var road := coaster.at(s)
	var origin := road.origin + road.basis.z * CAMERA_BACK + road.basis.y * CAMERA_UP
	return Transform3D(Basis.IDENTITY, origin).looking_at(road.origin - road.basis.z * CAMERA_AIM_AHEAD + road.basis.y * CAMERA_AIM_UP, road.basis.y)


func path(s: float) -> Vector3:
	return coaster.at(s).origin

func road_basis(s: float) -> Basis:
	return coaster.at(s).basis


func pose(s: float, lateral: float, height: float, size := Vector3.ONE) -> Transform3D:
	var basis := road_basis(s)
	return Transform3D(basis.scaled_local(size), path(s) + basis.x * lateral + basis.y * height)


func update_view(rules: NeonRules, delta: float, lane: float, ghost_lane: float, show_ghost: bool, _trail_id: String) -> void:
	if camera == null:
		return
	_unit_speed = rules.road_speed_scale()
	prepare_terrain(rules.course)
	distance = rules.road_distance()
	var resistance_fraction: float = (float(rules.latest.get("resistance", NeonRules.TIERS[rules.tier])) - NeonRules.TIERS[rules.tier]) / 41.0
	# The sky streams past at the speed the road does on screen.
	_structures.update_environment(str(rules.course.get("background", "orbital")), palette_accent, distance * STRETCH, resistance_fraction, delta, reduced_motion)
	# Follow the full orientation, including upside-down loops and rolls; the rider
	# retains its padding above the fixed lane-number dock.
	camera.transform = camera_pose(distance)
	_apply_shake(delta)
	_flow += delta * (30.0 + rules.speed_kph / 3.6 * STRETCH * 0.4)
	_update_waves(delta, rules.speed_kph / 3.6 * STRETCH)
	_update_horizon(delta)
	scenery.update_view(distance, portal_distance, distance + (portal_distance - distance) * 0.62,
		0.25 + 0.75 * rules.barrage.normal_alpha(rules.elapsed_ms), music_pulse, lite, music)
	var index := floori((distance - 24.0) / (ROAD_CHUNK_STEPS * STEP))
	if index != _road_index:
		_road_index = index
		_road_geometry(index)
	var target := pose(distance, (lane - 2.5) * LANE_WIDTH, 0.05)
	rider.transform = target
	rider.steer(lane, delta)
	rider.animate(float(rules.latest.get("cadence", 0)), delta)
	_update_trail(lane, clampf(float(rules.latest.get("cadence", 0)) / NeonRules.MAX_CADENCE, 0.0, 1.0))
	var ghost_at := ghost_distance if ghost_distance >= 0 else distance + 3.5 / STRETCH
	var ghost_gap := ghost_at - distance
	ghost.visible = (show_ghost and ghost_lane >= 0 and ghost_gap > -5 and ghost_gap < minf(85.0, portal_distance - distance - 24.0) and absf(ghost_gap) > 1.4) or _warming
	if ghost.visible:
		ghost.set_opacity(smoothstep(-5.0, -1.5, ghost_gap) * (1.0 - smoothstep(50.0, 85.0, ghost_gap)) * smoothstep(1.4, 4.5, absf(ghost_gap)) * (1.0 - smoothstep(portal_distance - 48.0, portal_distance - 24.0, ghost_at)))
		ghost.transform = pose(distance + 3.5 / STRETCH if _warming else ghost_at, ((2.5 if _warming else ghost_lane) - 2.5) * LANE_WIDTH, 0.05)
		ghost.animate(ghost_cadence, delta)
	_events(rules, lane)
	sections.update_view(rules, delta, lane)
	bombs.update_view(rules)
	barrage_view.update_view(rules, delta)
	gunfire_view.update_view(rules, delta, lane)
	_animate_impacts(delta)
	fx.update_view(delta, camera.global_position)


## Moves the seam pulses and launches new ones. A kick launches a pulse from the bike's front
## wheel, as strong as the bass is; with no kicks arriving (silence, a breakdown, Reduced
## motion) a soft pulse leaves at a steady rhythm so the road never goes dead. Each seam's
## steady glow follows one part of the spectrum, eased so it swells instead of flickering.
func _update_waves(delta: float, speed: float) -> void:
	if _wave_front.size() != WAVES:
		for list: PackedFloat32Array in [_wave_front, _wave_gain, _wave_age, _wave_power]:
			list.resize(WAVES)
			list.fill(0.0)
		_wave_front.fill(-100000.0)
		_wave_age.fill(WAVE_LIFE)
	if delta <= 0.0: return
	var targets := Vector4.ZERO
	if music_bands.size() >= 8 and not reduced_motion:
		targets = Vector4(maxf(music_bands[0], music_bands[1]), (music_bands[2] + music_bands[3]) * 0.5,
			(music_bands[4] + music_bands[5]) * 0.5, (music_bands[6] + music_bands[7]) * 0.5)
	for i in 4:
		_seams[i] = lerpf(_seams[i], targets[i], 1.0 - exp(-delta * (7.0 if targets[i] > _seams[i] else 2.4)))
	_wave_wait += delta
	var power := 0.0
	if music_beats != _beats_seen:
		if _beats_seen >= 0 and not reduced_motion and _wave_wait > 0.16:
			power = 0.55 + 0.45 * clampf(music.x * 1.5, 0.0, 1.0)
		_beats_seen = music_beats
	if power == 0.0 and _wave_wait > WAVE_IDLE_EVERY:
		power = 0.32 + 0.3 * clampf(music.y + music.z, 0.0, 1.0)
	if power > 0.0:
		_wave_wait = 0.0
		_wave_front[_wave_next] = distance * STRETCH + 2.0
		_wave_age[_wave_next] = 0.0
		_wave_power[_wave_next] = power
		_wave_next = (_wave_next + 1) % WAVES
	for i in WAVES:
		_wave_age[i] += delta
		_wave_front[i] += delta * (WAVE_SPEED + speed)
		# A pulse brightens as it pulls away, so it never flashes right beside the bike.
		_wave_gain[i] = _wave_power[i] * smoothstep(0.0, 0.16, _wave_age[i]) * (1.0 - smoothstep(WAVE_LIFE * 0.55, WAVE_LIFE, _wave_age[i]))


## The off-screen sky's size: `scale` of the 3D view (0.5 is a quarter of its pixels).
func set_sky_size(view_size: Vector2i, scale: float) -> void:
	_structures.set_view_size(view_size, scale)


## The 3D view's optional cost. `bloom` is the glow pass and its grade; `lite_mode` drops the
## set dressing that only adds fill: light streaks, pools of light, rail curtains, the trail
## and the star field. Gameplay objects are never affected.
func set_quality(bloom: bool, lite_mode: bool, any_bloom := true) -> void:
	lite = lite_mode
	_env.glow_enabled = bloom
	_env.adjustment_enabled = bloom
	_structures.set_stars(0.0 if lite_mode else 1.0)
	for chunk in _road_chunks: chunk.glow.visible = not lite_mode
	# Without bloom the seams and markers supply their own halo, so lift them a little.
	_road_material.set_shader_parameter("glow", 1.0 if bloom or any_bloom else 1.35)


## A brief camera knock for hits and blasts. Reduced motion keeps the camera still.
func shake(amount: float) -> void:
	if not reduced_motion: _trauma = minf(1.0, _trauma + amount)


func _apply_shake(delta: float) -> void:
	if _trauma <= 0.0: return
	_trauma = maxf(0.0, _trauma - delta * 2.2)
	_shake_clock += delta
	var power := _trauma * _trauma
	camera.position += camera.basis.x * sin(_shake_clock * 71.0) * 0.30 * power + camera.basis.y * sin(_shake_clock * 93.0 + 1.3) * 0.24 * power
	camera.rotate_object_local(Vector3.FORWARD, sin(_shake_clock * 57.0 + 0.4) * 0.014 * power)


## A ribbon of light from the tail lamp, laid along the route the bike actually took. It is
## rebuilt from at most TRAIL_POINTS samples, shortens as the rider slows and vanishes at rest.
## Samples are 1.6 world metres apart, so the ribbon reaches about 35 m behind the bike.
func _update_trail(lane: float, effort: float) -> void:
	var lateral := (lane - 2.5) * LANE_WIDTH
	var spacing := 1.6 / STRETCH
	if _trail_points.is_empty() or distance < _trail_points[-1].x - 0.01:
		_trail_points.clear()
		_trail_points.append(Vector2(distance, lateral))
	elif distance - _trail_points[-1].x >= spacing:
		# A fast frame can cover more than one sample; never leave a gap in the ribbon.
		var steps := mini(TRAIL_POINTS, floori((distance - _trail_points[-1].x) / spacing))
		var from := _trail_points[-1]
		for step in steps:
			var t := (step + 1) / float(steps)
			_trail_points.append(Vector2(lerpf(from.x, distance, t), lerpf(from.y, lateral, t)))
		while _trail_points.size() > TRAIL_POINTS: _trail_points.pop_front()
	_trail_mesh.clear_surfaces()
	_trail.visible = not lite and not reduced_motion and effort > 0.05 and _trail_points.size() >= 2
	if not _trail.visible: return
	var tail := (LaneSmashBike.DESIGN_REAR * LaneSmashBike.SCALE + 1.0) / STRETCH
	var height := 1.80 * LaneSmashBike.SCALE
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _trail_points.size() + 1:
		var at := Vector2(distance, lateral) if i == _trail_points.size() else _trail_points[i]
		var s := at.x - tail
		var age := clampf((distance - at.x) / (TRAIL_POINTS * spacing), 0.0, 1.0)
		var frame := coaster.at(s)
		var centre := frame.origin + frame.basis.x * at.y + frame.basis.y * height
		var half := frame.basis.x * (0.26 * (1.0 - age * 0.7))
		var tint := Color(1, 1, 1, pow(1.0 - age, 1.6) * 0.5 * effort)
		_trail_mesh.surface_set_color(tint)
		_trail_mesh.surface_set_uv(Vector2(0.5, 0.5))
		_trail_mesh.surface_add_vertex(centre - half)
		_trail_mesh.surface_set_color(tint)
		_trail_mesh.surface_set_uv(Vector2(0.5, 0.5))
		_trail_mesh.surface_add_vertex(centre + half)
	_trail_mesh.surface_end()


func _road_geometry(first: int) -> void:
	# Five fixed sections cover at least 24 m behind and 552 m ahead. Recycle only
	# the section that leaves view, about once every 8.6 s at maximum speed.
	for index in range(first, first + ROAD_CHUNK_COUNT):
		var chunk: Dictionary = _road_chunks[posmod(index, ROAD_CHUNK_COUNT)]
		if int(chunk.index) == index: continue
		chunk.index = index
		var start := index * ROAD_CHUNK_STEPS * STEP
		var centers := PackedVector3Array()
		var bases: Array[Basis] = []
		for i in ROAD_CHUNK_STEPS + 1:
			var frame := coaster.at(start + i * STEP)
			centers.append(frame.origin)
			bases.append(frame.basis)
		var edge := 3.0 * LANE_WIDTH
		# One ribbon for the deck: the shader draws seams, ticks and packets from its UVs.
		var strips: Array = [[-edge, -0.015, edge, -0.015, Color.BLACK]]
		chunk.road.mesh = _continuous_mesh(centers, bases, strips, start, true)
		strips.clear()
		for side: float in [-1.0, 1.0]:
			for p in RAIL_PROFILE.size() - 1:
				var a: Vector2 = RAIL_PROFILE[p]
				var b: Vector2 = RAIL_PROFILE[p + 1]
				strips.append([side * (edge + a.x), a.y, side * (edge + b.x), b.y, Color(1.0 if p == 0 else 0.0, 1.0 if p == 1 else 0.0, 0.0)])
		chunk.rails.mesh = _continuous_mesh(centers, bases, strips, start, false)
		strips.clear()
		for side: float in [-1.0, 1.0]:
			strips.append([side * (edge + 0.26), 0.42, side * (edge + 0.26), 2.3, Color.WHITE])
		chunk.glow.mesh = _continuous_mesh(centers, bases, strips, start, false)
		road_mesh_builds += 1


func _update_horizon(_delta: float) -> void:
	# Visibility follows the actual fixed curve. Nothing changes a road vertex.
	# A continuous curvature budget fades the distant road before it turns behind us.
	var previous := coaster.at(distance).basis.z
	var cost := 0.0
	var ahead := 480.0
	for i in range(1, 121):
		var forward := coaster.at(distance + i * 4.0).basis.z
		var next_cost := cost + 4.0 / 480.0 + previous.angle_to(forward) / 1.3
		if next_cost >= 1.0:
			ahead = (i - 1) * 4.0 + 4.0 * (1.0 - cost) / (next_cost - cost)
			break
		cost = next_cost
		previous = forward
	portal_distance = distance + ahead
	for material in [_road_material, _line_material, _curtain_material]:
		# The road's shaders work in world metres along the route (their ticks and segments are
		# real sizes), so the horizon is handed over in the same unit.
		material.set_shader_parameter("road_end", portal_distance * STRETCH)
		material.set_shader_parameter("fade_start", (distance + ahead * 0.62) * STRETCH)
		material.set_shader_parameter("flow", _flow)
		material.set_shader_parameter("pulse", music_pulse)
		material.set_shader_parameter("music", music)
		material.set_shader_parameter("seams", _seams)
		material.set_shader_parameter("wave_front", _wave_front)
		material.set_shader_parameter("wave_gain", _wave_gain)
	var forward := (path(portal_distance) - camera.position).normalized()
	var raw_right := coaster.at(portal_distance).basis.x
	var right := (raw_right - forward * raw_right.dot(forward)).normalized()
	var portal_basis := Basis(right, right.cross(forward).normalized(), -forward)
	var view_size := Vector2(get_viewport().size) if is_inside_tree() else Vector2(16, 9)
	_structures.set_view(camera.global_basis if camera.is_inside_tree() else camera.basis, portal_basis, camera.fov, view_size.x / maxf(1.0, view_size.y))


## Ribbons along the fixed route. Each strip is [lateral_a, height_a, lateral_b, height_b, color]
## and contributes two vertices per route step, so neighbouring chunks share exact boundary
## vertices. `lateral_uv` stores the lateral metres in UV.y (the deck); otherwise UV.y runs 0..1
## across the ribbon (rails and light curtains).
static func _continuous_mesh(centers: PackedVector3Array, bases: Array[Basis], strips: Array, start: float, lateral_uv: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var tangents := PackedFloat32Array()
	var indices := PackedInt32Array()
	for strip: Array in strips:
		var offset := vertices.size()
		var across := Vector2(float(strip[2]) - float(strip[0]), float(strip[3]) - float(strip[1]))
		# The ribbon's own facing, so slanted rail faces catch the lights correctly.
		var facing := Vector2(-across.y, across.x).normalized() if across.length_squared() > 0.000001 else Vector2.DOWN
		if facing.y < 0.0 and absf(facing.y) > absf(facing.x): facing = -facing
		for i in centers.size():
			for side in 2:
				var lateral := float(strip[side * 2])
				vertices.append(centers[i] + bases[i].x * lateral + bases[i].y * float(strip[side * 2 + 1]))
				normals.append((bases[i].x * facing.x + bases[i].y * facing.y).normalized())
				colors.append(strip[4])
				uvs.append(Vector2((start + i * STEP) * STRETCH, lateral if lateral_uv else float(side)))
				var right := bases[i].x
				tangents.append_array(PackedFloat32Array([right.x, right.y, right.z, 1.0]))
			if i > 0:
				var a := offset + (i - 1) * 2
				indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


static func marker_height(kind: String) -> float:
	return 0.13 if kind == "cruise" else (0.05 if kind == "hold" else 0.65)


## How far ahead of the bike's origin the front tyre meets a marker of this kind, in world
## metres (divide by STRETCH before adding it to a road distance).
static func wheel_contact_reach(kind: String) -> float:
	# At ground height the curved tire reaches slightly less far than at its axle.
	var top := 0.21 if kind == "cruise" else (0.41 if kind == "hold" else LaneSmashBike.AXLE_HEIGHT)
	var below_axle := maxf(0, LaneSmashBike.AXLE_HEIGHT - top)
	return LaneSmashBike.FRONT_AXLE + sqrt(maxf(0, pow(LaneSmashBike.WHEEL_RADIUS, 2) - below_axle * below_axle))


func finish_distance(kind: String, end_ms: int) -> float:
	var extent := 0.6325 if kind == "hold" else (0.16 if kind == "cruise" else 0.05)
	return end_ms / 1000.0 * _unit_speed + (wheel_contact_reach(kind) + extent) / STRETCH


func section_completed(kind: String, lane: int, at_ms: int) -> Vector3:
	var color := GOLD if kind == "cruise" else (GREEN if kind == "hold" else VIOLET)
	var finish := finish_distance(kind, at_ms)
	var at := pose(finish, (lane - 2.5) * LANE_WIDTH, 0.8).origin
	_explode(at, color, 36, 1.8)
	fx.beam(pose(finish, (lane - 2.5) * LANE_WIDTH, 0.05).origin, road_basis(finish), color, 13.0 if kind == "burst" else 9.0, 0.75)
	return pose(finish, (lane - 2.5) * LANE_WIDTH, 2.2).origin


func _events(rules: NeonRules, visual_lane: float) -> void:
	var counts := {"cruise": 0, "hold": 0, "charge": 0}
	var glows := 0
	var beat := 1.0 + music_pulse * 0.35
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
		if kind == "burst": continue # a growing floor zone and finish gate replace crystal rows
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
			var total := ceili(float(end - start) / spacing)
			# The preceding section owns the shared boundary. Its finish target must
			# clear before this section's first target, rather than stacking both there.
			if kind != "pickup" and i > 0 and int(rules.course.events[i - 1].endMs) == start and int(rules.course.events[i - 1].laneIndex) == lane:
				tick = maxi(tick, mini(1, total - 1))
			while tick < total and int(counts[bucket]) < MARKERS:
				var final_item := tick == total - 1 and kind != "pickup"
				var at := end if final_item else start + tick * spacing
				var key := "%s:%d:%d" % [event.eventId, c, tick]
				# Physical contact is independent of scoring eligibility: even an off-target
				# cadence arrow shatters, while the rules still award zero for that interval.
				var anchor := at / 1000.0 * _unit_speed
				var angle := now * 0.0018 + tick
				var back_extent := 0.16 if bucket == "cruise" else (0.6325 if bucket == "hold" else absf(sin(angle)) * 0.575 + absf(cos(angle)) * 0.4025)
				if final_item: anchor = finish_distance(kind, at)
				if anchor > portal_distance - 18.0: break
				var front_extent := 0.92 if bucket == "hold" else back_extent
				var contact := anchor - (wheel_contact_reach(bucket) + back_extent) / STRETCH
				if not rules.barrage.active and not _collected.has(key) and _previous_distance >= 0 and now - _previous_ms <= 250 and _previous_distance + 0.38 / STRETCH <= anchor + front_extent / STRETCH and distance >= contact and absf(visual_lane - lane) < 0.38:
					_collected[key] = at
					_explode(pose(anchor, lateral, 0.65).origin, color)
					target_hit.emit(bucket)
				if _collected.has(key):
					tick += 1
					continue
				var ahead := anchor - distance
				if ahead > 250:
					break
				var fade := smoothstep(-16.0, -2.0, ahead) * (1.0 - smoothstep(portal_distance - 50.0, portal_distance - 18.0, anchor))
				var tint := color
				tint.a = fade * (0.18 if muted else 1.0) * rules.barrage.normal_alpha(rules.elapsed_ms)
				var n: int = counts[bucket]
				var size := Vector3(2.25, 0.16, 0.32) if bucket == "cruise" else Vector3(1.15, 1.5, 1.15)
				var transform := pose(anchor, lateral, marker_height(bucket), size)
				if bucket == "charge":
					transform.basis = transform.basis.rotated(transform.basis.y.normalized(), now * 0.0018 + tick)
					transform.origin += transform.basis.y * 0.35
				pool.multimesh.set_instance_transform(n, transform)
				pool.multimesh.set_instance_color(n, Color(tint.r * beat, tint.g * beat, tint.b * beat, tint.a))
				if not lite and bucket != "charge" and glows < MARKERS * 2:
					_glows.multimesh.set_instance_transform(glows, pose(anchor, lateral, 0.035, Vector3(3.3, 1.0, 2.6) if bucket == "cruise" else Vector3(2.6, 1.0, 3.2)))
					_glows.multimesh.set_instance_color(glows, Color(color, tint.a * 0.34))
					glows += 1
				counts[bucket] = n + 1
				tick += 1
	_previous_ms = now
	_previous_distance = distance
	if _warming:
		for key in counts:
			if int(counts[key]) == 0:
				var pool := _bars if key == "cruise" else (_arrows if key == "hold" else _crystals)
				pool.multimesh.set_instance_transform(0, pose(distance + 8, 0, 0.1, Vector3.ONE * 0.05))
				pool.multimesh.set_instance_color(0, Color(1, 1, 1, 0.02))
				counts[key] = 1
	_glows.multimesh.visible_instance_count = glows
	_bars.multimesh.visible_instance_count = counts.cruise
	_arrows.multimesh.visible_instance_count = counts.hold
	_crystals.multimesh.visible_instance_count = counts.charge


func _explode(at: Vector3, color: Color, count := 12, force := 1.0) -> void:
	impact_count += 1
	var basis := road_basis(distance)
	if _shockwaves.size() >= 12: _shockwaves.pop_front()
	_shockwaves.append({"origin": at, "basis": basis, "color": color, "age": 0.0, "force": force})
	if fx: fx.burst(at, basis, color, mini(48, count), force)
	for i in count:
		if _impacts.size() >= 192: _impacts.pop_front()
		var angle := i * TAU / float(count) + impact_count * 0.8 + sin(i * 4.13) * 0.3
		var spread := 2.0 + fposmod(sin(i * 12.9898 + impact_count) * 43758.5453, 1.0) * 3.0
		_impacts.append({"origin": at, "velocity": basis * Vector3(cos(angle) * spread, 1.5 + fposmod(sin(i * 17.13) * 3758.2, 1.0) * 3.6, sin(angle) * spread) * force, "gravity": -basis.y * 3.0, "age": 0.0, "color": color})

func _animate_impacts(delta: float) -> void:
	for i in range(_shockwaves.size() - 1, -1, -1):
		_shockwaves[i].age += delta
		if float(_shockwaves[i].age) > 0.6: _shockwaves.remove_at(i)
	for i in _shockwaves.size():
		var wave: Dictionary = _shockwaves[i]
		var age := float(wave.age)
		var scale := (0.3 + 6.5 * (1.0 - pow(1.0 - age / 0.6, 2))) * float(wave.force)
		var tint: Color = wave.color
		tint.a = pow(1.0 - age / 0.6, 2) * 0.8
		_rings.multimesh.set_instance_transform(i, Transform3D(wave.basis.scaled_local(Vector3(scale, 1.0, scale)), wave.origin - wave.basis.y * 0.55))
		_rings.multimesh.set_instance_color(i, tint)
		# The flash is a camera-facing bloom of light: large at the instant of contact, gone fast.
		var flash_size := maxf(0.001, (0.35 + age / 0.22) * float(wave.force) * 3.2)
		var facing := camera.global_basis if camera else Basis.IDENTITY
		_flashes.multimesh.set_instance_transform(i, Transform3D(facing.scaled_local(Vector3.ONE * flash_size), wave.origin))
		tint = tint.lerp(LaneSmashLook.HOT, 0.6)
		tint.a = pow(maxf(0.0, 1.0 - age / 0.22), 1.5) * 0.9
		_flashes.multimesh.set_instance_color(i, tint)
	_rings.multimesh.visible_instance_count = _shockwaves.size()
	_flashes.multimesh.visible_instance_count = _shockwaves.size()
	if _warming and _shockwaves.is_empty() and _impacts.is_empty() and camera != null:
		_warm_effects()
		return
	for i in range(_impacts.size() - 1, -1, -1):
		_impacts[i].age += delta
		if float(_impacts[i].age) > 0.65: _impacts.remove_at(i)
	for i in _impacts.size():
		var particle: Dictionary = _impacts[i]
		var age := float(particle.age)
		var pos: Vector3 = particle.origin + particle.velocity * age + Vector3(particle.gravity) * age * age
		var tint: Color = particle.color
		tint.a = pow(1.0 - age / 0.65, 1.4)
		var size := 0.34 * (1.0 - age / 0.8)
		_shards.multimesh.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(age * 9, i, age * 7)).scaled(Vector3.ONE * size), pos))
		_shards.multimesh.set_instance_color(i, tint)
	_shards.multimesh.visible_instance_count = _impacts.size()


## A self-lit, instance-coloured material for pooled markers and effects; `energy` above one
## pushes it into the bloom. (The unused flags keep older call sites readable.)
static func _material(_color: Color, energy: float, _alpha := false, _vertex_color := false) -> ShaderMaterial:
	return LaneSmashLook.emissive(false, energy)


## Draws one tiny, nearly invisible instance of every effect pool behind the intro card, so
## their shaders compile before scored riding instead of at the first contact or blast.
func _warm_effects() -> void:
	var spot := pose(distance + 9.0, 0.0, 0.1, Vector3.ONE * 0.03)
	for pool: MultiMeshInstance3D in [_rings, _flashes, _shards, _glows]:
		pool.multimesh.set_instance_transform(0, spot)
		pool.multimesh.set_instance_color(0, Color(1, 1, 1, 0.01))
		pool.multimesh.visible_instance_count = 1
	if fx.active() == 0:
		fx.burst(spot.origin, spot.basis, Color(1, 1, 1, 0.01), 1, 0.01)
		fx.blast(spot.origin, spot.basis, Color(1, 1, 1, 0.01), 0.03, 0.5)
		fx.beam(spot.origin, spot.basis, Color(1, 1, 1, 0.01), 0.03, 0.5)


## A unit card lying on the road (X by Z), for pools of light and shockwaves.
static func _floor_card() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [[Vector3(-0.5, 0, -0.5), Vector2(0, 0)], [Vector3(0.5, 0, -0.5), Vector2(1, 0)], [Vector3(0.5, 0, 0.5), Vector2(1, 1)], [Vector3(-0.5, 0, 0.5), Vector2(0, 1)]]
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_color(Color.WHITE)
		surface.set_uv(corners[index][1])
		surface.set_normal(Vector3.UP)
		surface.add_vertex(corners[index][0])
	return surface.commit()


## The collect bar: a unit-sized ingot with chamfered edges and tapered ends. Scaled per
## instance, so its footprint (and the tyre contact computed from it) is unchanged.
static func _bar() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The base sits exactly where the old slab did; the crown rises above it, so the bar reads
	# from the chase camera without moving the surface the tyre meets.
	var outline := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(0.24, 1.5), Vector2(-0.24, 1.5), Vector2(-0.5, 0.5)]  # (z, y)
	var stations := [[-0.5, 0.35], [-0.44, 1.0], [0.44, 1.0], [0.5, 0.35]]  # x, section scale
	for i in stations.size() - 1:
		for p in outline.size():
			var q := (p + 1) % outline.size()
			var a := Vector3(stations[i][0], outline[p].y * stations[i][1], outline[p].x * stations[i][1])
			var b := Vector3(stations[i][0], outline[q].y * stations[i][1], outline[q].x * stations[i][1])
			var c := Vector3(stations[i + 1][0], outline[q].y * stations[i + 1][1], outline[q].x * stations[i + 1][1])
			var d := Vector3(stations[i + 1][0], outline[p].y * stations[i + 1][1], outline[p].x * stations[i + 1][1])
			var normal := (b - a).cross(d - a).normalized()
			if normal.dot(Vector3(0, (a.y + b.y) * 0.5, (a.z + b.z) * 0.5)) < 0.0: normal = -normal
			for point: Vector3 in [a, b, c, a, c, d]:
				surface.set_normal(normal)
				surface.add_vertex(point)
	for end: Array in [stations[0], stations[-1]]:
		for p in range(1, outline.size() - 1):
			for point: Vector2 in [outline[0], outline[p], outline[p + 1]]:
				surface.set_normal(Vector3(signf(end[0]), 0, 0))
				surface.add_vertex(Vector3(end[0], point.y * end[1], point.x * end[1]))
	return surface.commit()


## A splinter of light for shatter effects.
static func _shard() -> ArrayMesh:
	var points := [Vector3(0, 0.5, 0), Vector3(-0.32, -0.3, 0.22), Vector3(0.34, -0.3, 0.16), Vector3(0.0, -0.22, -0.4)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: Array in [[0, 1, 2], [0, 2, 3], [0, 3, 1], [1, 3, 2]]:
		var normal: Vector3 = (points[face[1]] - points[face[0]]).cross(points[face[2]] - points[face[0]]).normalized()
		for index: int in face:
			surface.set_normal(normal)
			surface.add_vertex(points[index])
	return surface.commit()


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
