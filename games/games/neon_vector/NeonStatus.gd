class_name NeonStatus
extends VBoxContainer
## The game's top-centre widget; shared HUD keeps metrics, score and End Ride.

var rules: NeonRules
var heading: Label
var target: Label
var power_row: HBoxContainer
var power_value: Label
var detail: Label
var meter: ProgressBar
var barrage_gauge: LaneSmashBarrageGauge
var _event_id := ""
var _last_refresh_second := -1
var _meter_target := 0.0
var _power_points := PointRollup.new()
var _power_event_id := ""
var _show_power_points := false
var _look: GameTheme = LaneSmashMenuTheme.shared()
var _backing: StyleBoxFlat


func _init() -> void:
	custom_minimum_size = Vector2(740, 176)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	# Top padding inside the backing (a container has none of its own).
	var inset := Control.new()
	inset.custom_minimum_size = Vector2(0, 6)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inset)
	heading = _look.label("TARGET LANE", 34, GameTheme.MUTED)
	target = _look.label("Turn resistance to steer", 44)
	var tabular := FontVariation.new()
	tabular.base_font = target.get_theme_font("font")
	tabular.opentype_features = {"tnum": 1}
	target.add_theme_font_override("font", tabular)
	detail = _look.label("Follow the marked lane.", 34, GameTheme.MUTED)
	for label in [heading, target, detail]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
	power_row = HBoxContainer.new()
	power_row.alignment = BoxContainer.ALIGNMENT_CENTER
	power_row.add_theme_constant_override("separation", 12)
	power_row.add_child(_look.label("PEDAL FASTER ·", 44))
	power_value = _look.label("0", 44)
	power_value.add_theme_font_override("font", tabular)
	power_value.custom_minimum_size.x = 155
	power_value.clip_text = true
	power_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_row.add_child(power_value)
	power_row.add_child(_look.label("points", 44))
	add_child(power_row)
	move_child(power_row, target.get_index() + 1)
	power_row.hide()
	meter = ProgressBar.new()
	meter.custom_minimum_size = Vector2(620, 12)
	meter.max_value = 200
	meter.step = 0
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("25304a")
	background.set_corner_radius_all(6)
	var fill := background.duplicate() as StyleBoxFlat
	fill.bg_color = NeonTrack.CHARGE
	meter.add_theme_stylebox_override("background", background)
	meter.add_theme_stylebox_override("fill", fill)
	add_child(meter)
	meter.visible = false
	barrage_gauge = LaneSmashBarrageGauge.new()
	add_child(barrage_gauge)
	barrage_gauge.visible = false


## A glass backing exactly the size of the block, so its edges line up with the ride and clock
## panels beside it and instructions stay readable over the brightest part of the sky.
func _draw() -> void:
	if _backing == null:
		_backing = LaneSmashMenuTheme.shared()._shape(Color(LaneSmashMenuTheme.SURFACE, 0.72), Color(LaneSmashMenuTheme.ACCENT, 0.28), 1)
	draw_style_box(_backing, Rect2(Vector2.ZERO, size))


## The backing's edge colour, which the ride pulses with the music.
func set_edge(color: Color) -> void:
	if _backing == null or _backing.border_color.is_equal_approx(color): return
	_backing.border_color = color
	queue_redraw()


func refresh() -> void:
	if rules == null:
		return
	if not rules.pause_reason.is_empty():
		_last_refresh_second = -1
		_show_power_points = false
		target.show()
		power_row.hide()
		detail.visible = true
		heading.text = "RIDE INTERRUPTED"
		target.text = {"sensor": "Waiting for fresh bike data", "pedalling": "Pedalling stopped", "stall": "Waiting for the display to recover"}.get(rules.pause_reason, "Ready when you are")
		detail.text = "Course time and points are frozen"
		return
	barrage_gauge.visible = rules.barrage.active and not rules.barrage.current_shot().is_empty() and not bool(rules.barrage.current_shot().get("resolved", false))
	if barrage_gauge.visible:
		barrage_gauge.offset = rules.barrage.projected_offset(rules)
		barrage_gauge.queue_redraw()
	if rules.barrage.active:
		_show_power_points = false
		target.show()
		power_row.hide()
		_refresh_barrage()
		return
	var event := rules.current_event()
	var event_id := str(event.get("eventId", ""))
	var second := rules.elapsed_ms / 1000
	if second == _last_refresh_second and event_id == _event_id: return
	_show_power_points = false
	target.show()
	power_row.hide()
	_event_id = event_id
	_last_refresh_second = second
	meter.visible = false
	var rpm := float(rules.latest.get("cadence", 0))
	var res := float(rules.latest.get("resistance", NeonRules.TIERS[rules.tier]))
	if rules.selected_lane < 0 and not rules.latest.is_empty():
		heading.text = "OUTSIDE THE COURSE RANGE"
		target.text = "Increase resistance to %d" % NeonRules.TIERS[rules.tier] if res < NeonRules.TIERS[rules.tier] else "Lower resistance to %d" % (NeonRules.TIERS[rules.tier] + 41)
		detail.text = "Points resume inside a lane"
		return
	if event.is_empty():
		heading.text = "FINISHING"
		target.text = "Easy pedals to the finish"
		detail.text = "Stay inside your resistance range"
		return
	var band := NeonRules.band(int(event.laneIndex), rules.tier)
	var ahead := maxi(0, int(event.startMs) - rules.road_time_ms())
	var state: Dictionary = rules.event_states[rules._event_cursor]
	var active := ahead == 0
	var prefix := "NOW" if active else ("IN %.0f ft" % (ahead / 1000.0 * rules.road_speed_scale() * 3.28084) if rules.distance_based else "IN %.1f s" % (ahead / 1000.0))
	var choices := NeonCourse.choices(event)
	var selected: int = int(state.choice)
	if choices.size() > 1 and selected < 0:
		var b := NeonRules.band(int(choices[1].laneIndex), rules.tier)
		heading.text = "%s · CHOOSE YOUR LINE" % prefix
		target.text = "%d–%d  or  %d–%d resistance" % [band.x, band.y, b.x, b.y]
		detail.text = "Flow lane  /  Surge lane +25% points"
		return
	if selected >= 0:
		band = NeonRules.band(int(choices[selected].laneIndex), rules.tier)
	var direction := "STAY IN THIS LANE" if rules.settled_lane == int(choices[maxi(0, selected)].laneIndex) else ("INCREASE RESISTANCE" if res < band.x else "LOWER RESISTANCE")
	heading.text = "%s · %s" % [prefix, {"cruise": "COLLECT", "hold": "PEDAL SPEED", "burst": "POWER BURST"}.get(event.type, str(event.type).to_upper())]
	if active and event.type == "hold":
		target.text = "%d–%d rpm · %s" % [event.cadenceMin, event.cadenceMax, "PEDAL FASTER" if rpm < event.cadenceMin else ("PEDAL SLOWER" if rpm > event.cadenceMax else "KEEP THIS SPEED")]
	elif active and event.type == "burst":
		var joules := int(state.energyMilliJoules) / 1000.0
		if _power_event_id != event_id:
			_power_event_id = event_id
			_power_points.reset()
		_power_points.aim(int(state.scoreUnits) / NeonRules.UNIT)
		_show_power_points = true
		target.hide()
		power_row.show()
		_update_power_text(_power_points.advance(0))
		meter.visible = true
		meter.max_value = 100
		_meter_target = minf(100, joules / (rules.reference_power * (int(event.endMs) - int(event.startMs)) / 1000.0) * 100)
	elif active and event.type == "charge":
		var percent := int(state.chargeIntegral) / float(int(event.endMs) - int(event.startMs)) / NeonRules.UNIT * 100
		target.text = "PEDAL SLOWER" if rpm > 120 else "CHARGE %d%% · %.0f / %.0f W" % [percent, rules.reference_power * 0.6, rules.reference_power]
		meter.visible = true
		meter.max_value = 200
		_meter_target = percent
	else:
		target.text = direction
	# Lane numbers/ranges are already shown in the dock; don't repeat them here.
	var fire := rules.gunfire()
	if active and event.type == "hold" and not fire.is_empty():
		# Cadence sections are strafed: say plainly whether the rider is in the gap or in the fire.
		detail.text = "Taking fire · −%d a hit" % NeonRules.GUN_HIT_POINTS if bool(fire.exposed) else "Under fire · hold this pace"
	else:
		detail.text = "Pedal to earn points" if rpm < 20 and active else ""
	detail.visible = not detail.text.is_empty()



func _process(delta: float) -> void:
	meter.value = lerpf(meter.value, _meter_target, 1.0 - exp(-delta * 9))
	if _show_power_points: _update_power_text(_power_points.advance(delta))

func _update_power_text(points: int) -> void:
	var text := str(points)
	if power_value.text != text: power_value.text = text

func show_notice(title: String, instruction: String, explanation: String) -> void:
	_show_power_points = false
	_last_refresh_second = -1
	power_row.hide()
	meter.hide()
	target.show()
	detail.show()
	heading.text = title
	target.text = instruction
	detail.text = explanation

func _refresh_barrage() -> void:
	var shot := rules.barrage.current_shot()
	var key := str(rules.barrage.section.barrageId) + str(shot.get("shotId", "")) + str(shot.get("resolved", false))
	var second := rules.elapsed_ms / 1000
	if key == _event_id and second == _last_refresh_second: return
	_event_id = key
	_last_refresh_second = second
	meter.visible = false
	heading.text = "INCOMING FIRE"
	detail.visible = true
	if shot.is_empty():
		target.text = "LOWER RESISTANCE" if rules.selected_lane > 0 else "GET READY TO CHANGE PACE"
		detail.text = "Use lane 1 for the attack"
		return
	if bool(shot.resolved):
		target.text = "KEEP PEDALLING"
		detail.text = "Next shot shortly" if rules.barrage._next_shot < 2 else "Returning to the track"
		return
	var left := ceili((int(shot.impactMs) - rules.elapsed_ms) / 1000.0)
	var safe := absf(rules.barrage.projected_offset(rules)) > LaneSmashBarrage.HALF_LENGTH + LaneSmashBarrage.RIDER_RADIUS + 2.0
	var prompt := "KEEP THIS PACE" if safe else ("PEDAL FASTER" if shot.direction == "faster" else "PEDAL SLOWER")
	target.text = prompt if safe else "%s · %d rpm" % [prompt, shot.targetRpm]
	detail.text = "%d s · %s" % [maxi(0, left), "Hold your pace to evade" if safe else ("Pass the red zone" if shot.direction == "faster" else "Stay behind the red zone")]
