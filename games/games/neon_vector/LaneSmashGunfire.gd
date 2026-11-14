class_name LaneSmashGunfire
extends Node3D
## Machine-gun fire over cadence sections. A raider paces the rider on a hover sled and rakes
## the road with two lines of fire: one ahead of the front wheel, one behind the tail. The gap
## between them is the section's cadence band made visible: pedal toward the top of the band
## and the leading line closes in, toward the bottom and the trailing line does. Outside the
## band a line reaches the bike and rounds land.
##
## Presentation only. The rules decide every hit (`NeonRules._apply_gunfire`); this reads
## `rules.gunfire()` and `rules.gun_hits` and never changes a score.
const TRACERS := 36
const METRES_PER_RPM := 1.3    ## world metres a fire line moves for each rpm of cadence
const SAFE_MARGIN := 1.2       ## clearance beyond the tyre when a line is at the band's edge
const GUNNER_AHEAD := 40.0     ## world metres ahead of the rider
const GUNNER_SIDE := 16.5
const GUNNER_UP := 7.5
const GUNNER_SCALE := 2.6
const ROUNDS_PER_SECOND := 22.0
const FADE_IN_RATE := 0.9    ## per second: the gunner takes a little over a second to fade in
const FADE_OUT_RATE := 1.0   ## and a second to fade out

var space: Node3D
var gunner: LaneSmashAttacker
var _tracers: Array[Dictionary] = []
var _tracer_pool: MultiMeshInstance3D
var _lines: MultiMeshInstance3D
var _muzzle: MultiMeshInstance3D
var _presence := 0.0
var _side := 1.0
var _event_id := ""
var _round := 0.0
var _serial := 0
var _hits_seen := 0
var _feedback: Array[Dictionary] = []
var _lead := 40.0
var _trail := 40.0
var _clock := 0.0
var _spent := false
var shots_fired := 0


func _ready() -> void:
	gunner = LaneSmashAttacker.new()
	add_child(gunner)
	gunner.visible = false
	_tracer_pool = space._instances(LaneSmashFx._card(), TRACERS, LaneSmashLook.emissive(true, 3.0))
	_lines = space._instances(NeonSpace._floor_card(), 2, LaneSmashLook.emissive(true, 1.5))
	_muzzle = space._instances(LaneSmashFx._card(), 1, LaneSmashLook.emissive(true, 3.2))
	for pool in [_tracer_pool, _lines, _muzzle]: pool.multimesh.visible_instance_count = 0


func update_view(rules: NeonRules, delta: float, rider_lane: float) -> void:
	_clock += delta
	if rules.gun_hits < _hits_seen: _hits_seen = 0  # a new ride
	var fire := rules.gunfire()
	var event := rules.current_event()
	var approaching := false
	if fire.is_empty() and rules.scoring_version >= 7 and not rules.barrage.active and event.get("type", "") == "hold":
		# The gunner fades in over the last stretch before the section begins.
		approaching = int(event.startMs) - rules.road_time_ms() < 2200
	var wanted := 1.0 if not fire.is_empty() or approaching else 0.0
	# About a second in and a second out. `_presence` is linear time; `_fade()` eases it.
	_presence = move_toward(_presence, wanted, delta * (FADE_IN_RATE if wanted > _presence else FADE_OUT_RATE))
	if not fire.is_empty() and str(fire.eventId) != _event_id:
		_event_id = str(fire.eventId)
		_side = 1.0 if (_event_id.hash() & 1) == 0 else -1.0
		_lead = 40.0
		_trail = 40.0
	elif fire.is_empty() and approaching and str(event.eventId) != _event_id:
		_event_id = str(event.eventId)
		_side = 1.0 if (_event_id.hash() & 1) == 0 else -1.0
	_track_hits(rules, rider_lane)
	if _presence <= 0.001 and _tracers.is_empty():
		gunner.visible = false
		for pool in [_tracer_pool, _lines, _muzzle]: pool.multimesh.visible_instance_count = 0
		if space._warming: _warmup()
		return
	var distance: float = space.distance
	var lateral := (rider_lane - 2.5) * NeonSpace.LANE_WIDTH
	var rider_at: Vector3 = space.pose(distance, lateral, 1.4).origin
	# The sled holds station ahead of the rider, outside the rail, turned back to face them.
	# It never moves into or out of place: it fades in where it stands and fades out there.
	var frame: Transform3D = space.coaster.at(distance + GUNNER_AHEAD / NeonSpace.STRETCH)
	var hover := sin(_clock * 1.7) * 0.5
	var origin := frame.origin + frame.basis.x * _side * GUNNER_SIDE + frame.basis.y * (GUNNER_UP + hover)
	gunner.transform = Transform3D(Basis.looking_at(rider_at - origin, frame.basis.y, true).scaled(Vector3.ONE * GUNNER_SCALE), origin)
	var firing := not fire.is_empty() and not bool(fire.spent) and _presence > 0.85
	gunner.animate(_fade(), _clock, fposmod(_round, 1.0) / ROUNDS_PER_SECOND if firing else -1.0, 0.8 if firing else 0.0)
	if not fire.is_empty():
		_aim(rules, fire, delta)
		_spent = bool(fire.spent)
	# The fire lines fade with the gunner, so nothing blinks off when a section ends.
	_draw_lines(distance, lateral)
	if firing: _fire(delta, distance, lateral, fire)
	else: _muzzle.multimesh.visible_instance_count = 0
	_draw_tracers(delta)


## The eased visibility of the gunner and the fire lines: slow at both ends of a fade.
func _fade() -> float:
	return smoothstep(0.0, 1.0, _presence)


## Where the two fire lines sit, in world metres clear of the bike. Zero or less means on it.
func _aim(rules: NeonRules, fire: Dictionary, delta: float) -> void:
	var rpm := float(rules.latest.get("cadence", 0))
	var grace := float(fire.graceLeftMs) / NeonRules.GUN_GRACE_MS
	# During the warning the lines land wide, then walk in to their true places.
	var lead := (float(fire.cadenceMax) - rpm) * METRES_PER_RPM + SAFE_MARGIN + grace * 40.0
	var trail := (rpm - float(fire.cadenceMin)) * METRES_PER_RPM + SAFE_MARGIN + grace * 40.0
	if grace <= 0.0:
		if rpm > float(fire.cadenceMax): lead = -1.2
		if rpm < float(fire.cadenceMin): trail = -1.2
	var blend := 1.0 - exp(-delta * 5.0)
	_lead = lerpf(_lead, clampf(lead, -1.2, 64.0), blend)
	_trail = lerpf(_trail, clampf(trail, -1.2, 64.0), blend)


## The road distances of the leading and trailing fire lines.
func _line_distances(distance: float) -> Array[float]:
	var front := LaneSmashBike.FRONT_REACH
	var rear := LaneSmashBike.DESIGN_REAR * LaneSmashBike.SCALE + LaneSmashBike.WHEEL_RADIUS
	return [distance + (front + _lead) / NeonSpace.STRETCH, distance - (rear + _trail) / NeonSpace.STRETCH]


func _draw_lines(distance: float, lateral: float) -> void:
	var at := _line_distances(distance)
	var flicker := 0.82 + 0.18 * sin(_clock * 23.0)
	for i in 2:
		var gap := _lead if i == 0 else _trail
		var danger := 1.0 - smoothstep(1.0, 10.0, gap)
		var tint := LaneSmashLook.PLASMA.lerp(LaneSmashLook.DANGER, danger)
		tint.a = _fade() * flicker * (0.30 + 0.45 * danger) * (0.35 if _spent else 1.0)
		_lines.multimesh.set_instance_transform(i, space.pose(at[i], lateral, 0.06, Vector3(8.5, 1.0, 2.6 + danger * 1.6)))
		_lines.multimesh.set_instance_color(i, tint)
	_lines.multimesh.visible_instance_count = 2


func _fire(delta: float, distance: float, lateral: float, _fire_state: Dictionary) -> void:
	_round += delta * ROUNDS_PER_SECOND
	var at := _line_distances(distance)
	var muzzle := gunner.muzzle.global_position
	while _round >= 1.0:
		_round -= 1.0
		_serial += 1
		shots_fired += 1
		var line := _serial & 1
		var seed_a := fposmod(sin(_serial * 12.9898) * 43758.5453, 1.0)
		var seed_b := fposmod(sin(_serial * 78.233) * 24634.6345, 1.0)
		var s: float = at[line] + (seed_a - 0.5) * 3.0 / NeonSpace.STRETCH
		var gap := _lead if line == 0 else _trail
		var on_bike := gap < 0.2
		var target: Vector3 = space.pose(s, lateral + (seed_b - 0.5) * (1.8 if on_bike else 6.5), 0.9 if on_bike else 0.05).origin
		if _tracers.size() >= TRACERS: _tracers.pop_front()
		_tracers.append({"from": muzzle, "to": target, "age": 0.0, "life": clampf(muzzle.distance_to(target) / 260.0, 0.07, 0.22), "landed": false,
			"basis": space.road_basis(s), "on_bike": on_bike})
	var flash := 0.6 + 0.9 * fposmod(_clock * ROUNDS_PER_SECOND, 1.0)
	_muzzle.multimesh.set_instance_transform(0, Transform3D(space.camera.global_basis.scaled_local(Vector3.ONE * flash * 2.0), muzzle))
	_muzzle.multimesh.set_instance_color(0, Color(LaneSmashLook.PLASMA.lerp(LaneSmashLook.HOT, 0.5), _fade()))
	_muzzle.multimesh.visible_instance_count = 1


func _draw_tracers(delta: float) -> void:
	var eye: Vector3 = space.camera.global_position
	for i in range(_tracers.size() - 1, -1, -1):
		var tracer: Dictionary = _tracers[i]
		tracer.age += delta
		if float(tracer.age) >= float(tracer.life):
			if not bool(tracer.landed):
				tracer.landed = true
				space.fx.burst(tracer.to, tracer.basis, LaneSmashLook.DANGER if bool(tracer.on_bike) else LaneSmashLook.PLASMA, 3, 0.55)
			_tracers.remove_at(i)
	for i in _tracers.size():
		var tracer: Dictionary = _tracers[i]
		var t := float(tracer.age) / float(tracer.life)
		var from: Vector3 = tracer.from
		var to: Vector3 = tracer.to
		var head := from.lerp(to, t)
		var along := (to - from).normalized()
		var side := along.cross(eye - head)
		side = side.normalized() if side.length_squared() > 0.000001 else Vector3.UP
		var length := minf(9.0, from.distance_to(head))
		_tracer_pool.multimesh.set_instance_transform(i, Transform3D(Basis(along * length, side * 0.22, side.cross(along)), head - along * length * 0.5))
		_tracer_pool.multimesh.set_instance_color(i, Color(LaneSmashLook.PLASMA.lerp(LaneSmashLook.HOT, 0.45), 0.9))
	_tracer_pool.multimesh.visible_instance_count = _tracers.size()
	if _tracers.is_empty() and _presence <= 0.001: _muzzle.multimesh.visible_instance_count = 0


## Each round the rules land on the rider becomes sparks, a knock and a red number.
func _track_hits(rules: NeonRules, rider_lane: float) -> void:
	while _hits_seen < rules.gun_hits:
		_hits_seen += 1
		var at: Vector3 = space.pose(space.distance, (rider_lane - 2.5) * NeonSpace.LANE_WIDTH, 1.5).origin
		var basis: Basis = space.road_basis(space.distance)
		space.fx.burst(at, basis, LaneSmashLook.DANGER, 16, 1.0)
		space.shake(0.22)
		_feedback.append({"points": NeonRules.GUN_HIT_POINTS, "anchor": at + basis.y * 2.6, "up": basis.y})


## The oldest unreported hit, or empty. NeonTrack turns it into a popup and a sound.
func take_feedback() -> Dictionary:
	return {} if _feedback.is_empty() else _feedback.pop_front()


func _warmup() -> void:
	# Compile the gunner's and tracers' shaders behind the intro, not on the first cadence section.
	gunner.transform = space.pose(space.distance + 12, 3.0, 0.2, Vector3.ONE * 0.03)
	gunner.animate(0.005, 0, -1)
	for pool in [_tracer_pool, _lines, _muzzle]:
		pool.multimesh.set_instance_transform(0, space.pose(space.distance + 12, 3.0, 0.1, Vector3.ONE * 0.04))
		pool.multimesh.set_instance_color(0, Color(1, 1, 1, 0.005))
		pool.multimesh.visible_instance_count = 1
