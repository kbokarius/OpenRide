class_name NeonStatus
extends VBoxContainer
## The game's top-centre widget; shared HUD keeps metrics, score, Pause and End.

var rules: NeonRules
var heading: Label
var target: Label
var detail: Label
var meter: ProgressBar
var _look := GameTheme.new(Color("67d8ff"), Color("0b132b"))


func _init() -> void:
	custom_minimum_size = Vector2(740, 190)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	heading = _look.label("FIND YOUR LINE", 34, GameTheme.MUTED)
	target = _look.label("Turn resistance to steer", 44)
	detail = _look.label("Six lanes. Your own rhythm.", 34, GameTheme.MUTED)
	for label in [heading, target, detail]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
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


func refresh() -> void:
	if rules == null:
		return
	meter.visible = false
	if not rules.pause_reason.is_empty():
		heading.text = "RIDE PAUSED"
		target.text = {"sensor": "Waiting for fresh bike data", "pedalling": "Pedalling stopped", "stall": "Display paused to keep scoring fair"}.get(rules.pause_reason, "Ready when you are")
		detail.text = "Course time and points are frozen"
		return
	var event := rules.current_event()
	var rpm := float(rules.latest.get("cadence", 0))
	var res := float(rules.latest.get("resistance", NeonRules.TIERS[rules.tier]))
	if rules.selected_lane < 0 and not rules.latest.is_empty():
		heading.text = "OUTSIDE THE COURSE RANGE"
		target.text = "Increase resistance to %d" % NeonRules.TIERS[rules.tier] if res < NeonRules.TIERS[rules.tier] else "Lower resistance to %d" % (NeonRules.TIERS[rules.tier] + 41)
		detail.text = "Points resume inside a lane"
		return
	if event.is_empty():
		heading.text = "FINISHING THE SIGNAL"
		target.text = "Easy pedals to the finish"
		detail.text = "Stay inside your resistance range"
		return
	var band := NeonRules.band(int(event.laneIndex), rules.tier)
	var ahead := maxi(0, int(event.startMs) - rules.elapsed_ms)
	var state: Dictionary = rules.event_states[rules._event_cursor]
	var active := ahead == 0
	var prefix := "NOW" if active else "IN %.1f s" % (ahead / 1000.0)
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
	var direction := "HOLD" if rules.settled_lane == int(choices[maxi(0, selected)].laneIndex) else ("TURN RIGHT" if res < band.x else "TURN LEFT")
	heading.text = "%s · %s" % [prefix, str(event.type).to_upper()]
	if active and event.type == "hold":
		target.text = "%d–%d rpm · %s" % [event.cadenceMin, event.cadenceMax, "PEDAL UP" if rpm < event.cadenceMin else ("EASE CADENCE" if rpm > event.cadenceMax else "ON TARGET")]
	elif active and event.type == "charge":
		var percent := int(state.chargeIntegral) / float(int(event.endMs) - int(event.startMs)) / NeonRules.UNIT * 100
		target.text = "EASE CADENCE" if rpm > 120 else "CHARGE %d%% · %.0f / %.0f W" % [percent, rules.reference_power * 0.6, rules.reference_power]
		meter.visible = true
		meter.value = percent
	else:
		target.text = "%s · %d–%d resistance" % [direction, band.x, band.y]
	if rpm < 20 and active:
		detail.text = "Pedal to score · auto-pause after 3 s"
	elif rules.settled_lane < 0 and rules.selected_lane >= 0:
		detail.text = "Settling into lane %d…" % (rules.selected_lane + 1)
	else:
		detail.text = "Lane %d · %d–%d resistance" % [int(choices[maxi(0, selected)].laneIndex) + 1, band.x, band.y]
