extends GdUnitTestSuite
## Revision 13: the cadence sweet spot (scoring version 8), the gauge that shows it, the
## power-burst celebration, the graphics governor and the quality tiers.

const TRACK := "ls_10_01"


func _rules(course_version := 9) -> NeonRules:
	var course: Dictionary = preload("res://tests/fixtures/catalog_v7.gd").load_track(TRACK)
	course.courseVersion = course_version
	var rules := NeonRules.new()
	assert_array(rules.configure(course, "challenging", 150)).is_empty()
	return rules


func _first(rules: NeonRules, kind: String) -> Dictionary:
	for event: Dictionary in rules.course.events:
		if event.type == kind: return event
	return {}


## Rides to `until_ms` at `cadence.call(rules)`, in the target lane, advancing every `step` ms.
func _ride(rules: NeonRules, until_ms: int, cadence: Callable, step := 50) -> void:
	var t := rules.elapsed_ms
	var next := rules.elapsed_ms + step
	while t < until_ms:
		var lane := int(rules.current_event().get("laneIndex", 0))
		rules.push_sample({"t": t, "seq": t + 1, "cadence": float(cadence.call(rules)), "power": 150, "resistance": NeonRules.band_center(lane, rules.tier)})
		t += 50
		while next <= mini(t, until_ms):
			rules.advance(next)
			next += step


## Rides the first cadence section at `rpm` from its start to past its end; returns its state.
func _hold_at(rules: NeonRules, rpm: float, step := 50) -> Dictionary:
	var hold := _first(rules, "hold")
	var index: int = rules.course.events.find(hold)
	var middle := (float(hold.cadenceMin) + float(hold.cadenceMax)) * 0.5
	# Everything before the section is ridden the same way whatever is being tested; the rider
	# is already at the tested cadence when the section begins.
	# (Each call rides at least one advance step, or a 100 ms step would never move the ride.)
	var chunk := maxi(100, step)
	while rules.road_time_ms() < int(hold.startMs) - 500: _ride(rules, rules.elapsed_ms + chunk, func(_r): return middle, step)
	while rules.road_time_ms() < int(hold.endMs) + 200: _ride(rules, rules.elapsed_ms + chunk, func(_r): return rpm, step)
	return rules.event_states[index]


func test_the_middle_of_the_band_earns_a_fifth_more_and_the_rest_of_it_does_not() -> void:
	var hold := _first(_rules(), "hold")
	var middle := (float(hold.cadenceMin) + float(hold.cadenceMax)) * 0.5
	var sweet := NeonRules.sweet_spot(hold)
	assert_vector(sweet).is_equal(Vector2(middle - 3.0, middle + 3.0))
	# Dead centre for the whole section: the section's points and a fifth again.
	var centred := _rules()
	var state := _hold_at(centred, middle)
	assert_int(int(state.baseUnits)).is_greater(0)
	assert_int(int(state.bonusUnits)).is_between(int(state.baseUnits) * 19 / 100, int(state.baseUnits) * 20 / 100)
	assert_int(int(state.scoreUnits)).is_equal(int(state.baseUnits) + int(state.bonusUnits))
	assert_int(centred.sweet_bonus_units).is_equal(int(state.bonusUnits))
	assert_int(int(centred.result("pending").sweetSpot.bonusUnits)).is_equal(int(state.bonusUnits))
	# Both edges of the sweet spot count; one rpm outside it earns the section's points only.
	for rpm: float in [sweet.x, sweet.y]:
		assert_int(int(_hold_at(_rules(), rpm).bonusUnits)).override_failure_message("edge %.0f" % rpm).is_greater(0)
	for rpm: float in [sweet.x - 1.0, sweet.y + 1.0, float(hold.cadenceMin), float(hold.cadenceMax)]:
		var plain := _hold_at(_rules(), rpm)
		assert_int(int(plain.bonusUnits)).override_failure_message("rpm %.0f" % rpm).is_zero()
		assert_int(int(plain.scoreUnits)).is_equal(int(plain.baseUnits))
		assert_int(int(plain.baseUnits)).is_greater(0)


func test_the_bonus_never_counts_toward_stars_or_older_rides() -> void:
	var hold := _first(_rules(), "hold")
	var middle := (float(hold.cadenceMin) + float(hold.cadenceMax)) * 0.5
	# Stars rate the base credit, which is the same in or out of the sweet spot.
	var centred := _rules()
	var edge := _rules()
	_hold_at(centred, middle)
	_hold_at(edge, float(hold.cadenceMin))
	# (Two rides at different cadences cross a section's ends on different ticks, so their
	# credit can differ by a fraction of a point; the bonus is some four hundred.)
	assert_int(absi(centred.base_units - edge.base_units)).is_less(2 * NeonRules.UNIT)
	assert_int(absi(centred.max_base_units - edge.max_base_units)).is_less(2 * NeonRules.UNIT)
	assert_int(centred.score_units - edge.score_units).is_greater(centred.sweet_bonus_units - 2 * NeonRules.UNIT)
	assert_int(centred.sweet_bonus_units).is_greater(200 * NeonRules.UNIT)
	assert_int(edge.sweet_bonus_units).is_zero()
	# A ride saved under scoring 7 (course 8) has no sweet spot: same ride, no bonus, no state.
	var older := _rules(8)
	assert_int(older.scoring_version).is_equal(7)
	var state := _hold_at(older, middle)
	assert_bool(state.has("bonusUnits")).is_false()
	assert_int(int(state.scoreUnits)).is_equal(int(state.baseUnits))
	assert_int(older.sweet_bonus_units).is_zero()
	assert_bool(bool(older.cadence_target().get("bonus", false))).is_false()


func test_the_bonus_is_the_same_at_any_frame_rate() -> void:
	var hold := _first(_rules(), "hold")
	var middle := (float(hold.cadenceMin) + float(hold.cadenceMax)) * 0.5
	var outcomes: Array = []
	for step in [10, 30, 50, 100]:
		var rules := _rules()
		# In and out of the sweet spot through the section.
		var state := _hold_at(rules, middle, step)
		outcomes.append([int(state.bonusUnits), int(state.scoreUnits), rules.score_units])
	for outcome: Array in outcomes: assert_array(outcome).is_equal(outcomes[0])


func test_the_gauge_is_told_about_a_cadence_section_before_it_starts() -> void:
	var rules := _rules()
	var hold := _first(rules, "hold")
	var middle := (float(hold.cadenceMin) + float(hold.cadenceMax)) * 0.5
	assert_dict(rules.cadence_target()).is_empty()
	# A little under 1.2 active seconds before the section it appears, not yet active.
	while rules.road_time_ms() < int(hold.startMs) - 500: _ride(rules, rules.elapsed_ms + 50, func(_r): return middle)
	var ahead := rules.cadence_target()
	assert_str(str(ahead.eventId)).is_equal(str(hold.eventId))
	assert_bool(bool(ahead.active)).is_false()
	assert_int(int(ahead.startsInMs)).is_between(1, 500)
	assert_int(int(ahead.cadenceMin)).is_equal(int(hold.cadenceMin))
	assert_float(float(ahead.sweetMin)).is_equal(middle - NeonRules.SWEET_HALF_RPM)
	# Inside it: active, and it reports where the rider is.
	while rules.road_time_ms() < int(hold.startMs) + 1000: _ride(rules, rules.elapsed_ms + 50, func(_r): return middle)
	var now := rules.cadence_target()
	assert_bool(bool(now.active)).is_true()
	assert_bool(bool(now.inBand)).is_true()
	assert_bool(bool(now.inSweet)).is_true()
	_ride(rules, rules.elapsed_ms + 300, func(_r): return float(hold.cadenceMax) + 9.0)
	assert_bool(bool(rules.cadence_target().inBand)).is_false()
	assert_bool(bool(rules.cadence_target().inSweet)).is_false()
	# Gone once the section is behind the rider.
	while rules.road_time_ms() < int(hold.endMs) + 100: _ride(rules, rules.elapsed_ms + 50, func(_r): return middle)
	var after := rules.cadence_target()
	assert_bool(after.is_empty() or str(after.eventId) != str(hold.eventId)).is_true()


func test_the_gauge_maps_cadence_to_the_track_and_names_what_to_do() -> void:
	assert_float(LaneSmashCadenceGauge.level(80.0, 80.0, 100.0)).is_equal(0.0)
	assert_float(LaneSmashCadenceGauge.level(90.0, 80.0, 100.0)).is_equal(0.5)
	assert_float(LaneSmashCadenceGauge.level(100.0, 80.0, 100.0)).is_equal(1.0)
	# Out of range the marker stops a little past the end instead of leaving the panel.
	assert_float(LaneSmashCadenceGauge.level(40.0, 80.0, 100.0)).is_equal(-LaneSmashCadenceGauge.OVERSHOOT)
	assert_float(LaneSmashCadenceGauge.level(160.0, 80.0, 100.0)).is_equal(1.0 + LaneSmashCadenceGauge.OVERSHOOT)
	var gauge := LaneSmashCadenceGauge.new()
	var bounds := Rect2(48, 316, 1824, 584)
	var live := {"eventId": "a", "laneIndex": 0, "cadenceMin": 80, "cadenceMax": 100, "sweetMin": 87.0, "sweetMax": 93.0, "active": false, "rpm": 90.0, "inBand": true, "inSweet": true, "bonus": true, "startsInMs": 1500}
	assert_str(gauge.state()).is_empty()
	gauge.update(0.0, live, Vector2(480, 700), bounds)
	assert_float(gauge.alpha).is_equal(1.0)
	assert_str(gauge.state()).is_equal("ahead")
	# With the bike on the left it sits to the bike's left; on the right, to its right; always
	# inside the play area.
	assert_float(gauge.centre.x).is_less(480.0)
	live.active = true
	for case: Array in [[90.0, "sweet"], [82.0, "in"], [99.0, "in"], [70.0, "slow"], [112.0, "fast"]]:
		live.rpm = case[0]
		gauge.update(0.0, live, Vector2(480, 700), bounds)
		assert_str(gauge.state()).override_failure_message("rpm %.0f" % case[0]).is_equal(case[1])
	gauge.update(0.0, live, Vector2(1440, 700), bounds)
	gauge.update(10.0, live, Vector2(1440, 700), bounds)
	assert_float(gauge.centre.x).is_greater(1440.0)
	# At the viewport edges the panel must sit inward, not on top of the motorcycle.
	gauge.update(0.0, live, Vector2(300, 700), bounds)
	assert_float(gauge.centre.x - LaneSmashCadenceGauge.SIZE.x * 0.5 - 300).is_greater(120.0)
	gauge.update(0.0, live, Vector2(1620, 700), bounds)
	assert_float(1620 - gauge.centre.x - LaneSmashCadenceGauge.SIZE.x * 0.5).is_greater(120.0)
	for bike: Vector2 in [Vector2(60, 320), Vector2(1900, 900), Vector2(960, 600)]:
		gauge.update(0.0, live, bike, bounds)
		assert_bool(bounds.encloses(Rect2(gauge.centre - LaneSmashCadenceGauge.SIZE * 0.5, LaneSmashCadenceGauge.SIZE))).override_failure_message(str(bike)).is_true()
	# It fades out, rather than vanishing, when the section ends.
	gauge.update(0.05, {}, Vector2(400, 700), bounds)
	assert_float(gauge.alpha).is_between(0.5, 0.99)
	gauge.update(1.0, {}, Vector2(400, 700), bounds)
	assert_float(gauge.alpha).is_equal(0.0)
	# Without the bonus (an older ride) the middle is just "in".
	live.bonus = false
	live.rpm = 90.0
	gauge.update(0.0, live, Vector2(400, 700), bounds)
	assert_str(gauge.state()).is_equal("in")


func test_a_finished_burst_is_celebrated_quickly_and_then_gone() -> void:
	var show := LaneSmashCelebration.new()
	assert_bool(show.active()).is_false()
	show.start(6354, 1.55)
	assert_bool(show.active()).is_true()
	assert_int(show.points).is_equal(6354)
	assert_str(show.title).is_equal("SUPERCHARGED")
	assert_str(LaneSmashCelebration.rank(0.6)).is_equal("POWER BURST")
	assert_str(LaneSmashCelebration.rank(1.0)).is_equal("FULL POWER")
	assert_str(LaneSmashCelebration.rank(2.3)).is_equal("OVERCHARGED")
	# In within a tenth of a second, fully there by then, and out by the end.
	assert_float(LaneSmashCelebration.opacity(0.0)).is_equal(0.0)
	assert_float(LaneSmashCelebration.opacity(0.1)).is_equal(1.0)
	assert_float(LaneSmashCelebration.opacity(0.6)).is_equal(1.0)
	assert_float(LaneSmashCelebration.opacity(LaneSmashCelebration.LIFE)).is_equal(0.0)
	assert_float(LaneSmashCelebration.LIFE).is_less_equal(1.5)
	# The number punches in past full size and settles at it.
	var peak := 0.0
	for i in 40: peak = maxf(peak, LaneSmashCelebration.scale(i * 0.01))
	assert_float(peak).is_between(1.1, 1.35)
	assert_float(LaneSmashCelebration.scale(1.0)).is_equal_approx(1.0, 0.001)
	show.update(LaneSmashCelebration.LIFE + 0.1)
	assert_bool(show.active()).is_false()


func test_a_power_burst_gets_the_celebration_instead_of_the_small_number() -> void:
	var rules := _rules()
	rules.barrage.schedule = []  # isolate the section celebration from timed attacks
	var track := NeonTrack.new()
	track.rules = rules
	add_child(track)
	for i in 3: track.update_view(0)
	var burst := _first(rules, "burst")
	var finished: Array = []
	track.section_finished.connect(func(kind: String): finished.append(kind))
	while rules.road_time_ms() < int(burst.endMs) + 100:
		_ride(rules, rules.elapsed_ms + 50, func(r: NeonRules): return 120.0 if r.current_event().get("type", "") == "burst" else 96.0)
		track.update_view(0.05)
	assert_array(finished).contains(["burst"])
	assert_bool(track.celebration.active()).is_true()
	assert_int(track.celebration.points).is_equal(int(rules.event_states[rules.course.events.find(burst)].scoreUnits) / NeonRules.UNIT)
	assert_float(track._completion_age).is_greater_equal(1.4)  # the small floating number stays away
	track.free()


func test_one_hitch_does_not_cost_the_ride_its_resolution() -> void:
	var governor := LaneSmashGovernor.new()
	# A steady 60 fps never steps down.
	for i in 60 * 30: assert_bool(governor.observe(1.0 / 60)).is_false()
	# One frame of most of a second in otherwise smooth riding: still no step down.
	governor.reset()
	var stepped := false
	for i in 60 * 20:
		if governor.observe(0.9 if i == 400 else 1.0 / 60): stepped = true
	assert_bool(stepped).is_false()
	# One slow window between good ones: no step down.
	governor.reset()
	stepped = false
	for i in 30 * 8:
		if governor.observe(1.0 / 60 if i < 60 * 3 or i > 60 * 3 + 30 * 4 else 1.0 / 30): stepped = true
	# A frame rate that stays under the floor does step down, after two windows.
	governor.reset()
	var seconds := 0.0
	while not governor.observe(1.0 / 40):
		seconds += 1.0 / 40
		assert_float(seconds).is_less(20.0)
	assert_float(seconds).is_between(LaneSmashGovernor.SETTLE_SEC + LaneSmashGovernor.WINDOW_SEC * 1.9, LaneSmashGovernor.SETTLE_SEC + LaneSmashGovernor.WINDOW_SEC * 2.2)
	assert_float(governor.last_fps).is_equal_approx(40.0, 0.5)


func test_each_tier_sets_the_view_the_sky_the_bloom_and_the_smoothing() -> void:
	var rules := _rules()
	var track := NeonTrack.new()
	track.rules = rules
	add_child(track)
	var sizes := {}
	for tier: String in NeonTrack.TIERS:
		track.apply_quality(tier)
		var view := Vector2(track.view.size)
		sizes[tier] = view.x
		# The sky is drawn off screen at its tier's share of the view.
		var sky := Vector2(track.space._structures.pass_view.size)
		assert_float(sky.x / view.x).override_failure_message(tier).is_equal_approx(float(NeonTrack.SKY_SCALE[tier]), 0.01)
		# Edges are smoothed on every tier.
		assert_float(float(track._lens.get_shader_parameter("smoothing"))).is_equal(1.0)
		var lens_bloom: bool = NeonTrack.BLOOM[tier] == "lens"
		assert_float(float(track._lens.get_shader_parameter("bloom"))).override_failure_message(tier).is_equal(NeonTrack.LENS_BLOOM_STRENGTH if lens_bloom else 0.0)
		for pass_view: SubViewport in track._bloom_views:
			assert_int(pass_view.render_target_update_mode).is_equal(SubViewport.UPDATE_ALWAYS if lens_bloom else SubViewport.UPDATE_DISABLED)
			assert_int(pass_view.size.x).is_equal(maxi(80, track.view.size.x / 4))
		# The engine's bloom and grade are only on where the tier asks for them.
		assert_bool(track.space._env.glow_enabled).override_failure_message(tier).is_equal(NeonTrack.BLOOM[tier] == "engine")
		assert_vector(track._lens.get_shader_parameter("grade")).is_equal(Vector2.ONE if NeonTrack.BLOOM[tier] == "engine" else NeonTrack.GRADE)
	# Each tier down is a smaller view; the bike's tier is larger than it was (0.72 of the screen).
	assert_float(sizes["high"]).is_greater(sizes["balanced"])
	assert_float(sizes["balanced"]).is_greater(sizes["performance"])
	assert_float(float(NeonTrack.VIEW_SCALE.balanced)).is_greater(0.72)
	track.free()


func test_the_off_screen_sky_looks_where_the_camera_looks() -> void:
	var sky := LaneSmashEnvironment.new()
	add_child(sky)
	sky.configure(Environment.new())
	# Looking straight down the tunnel: view space and the tunnel's frame coincide.
	var portal := Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, -0.3)
	sky.set_view(portal, portal, 60.0, 16.0 / 9.0)
	var view_to_tunnel: Basis = sky.material.get_shader_parameter("view_to_tunnel")
	assert_bool(view_to_tunnel.is_equal_approx(Basis.IDENTITY)).is_true()
	var half: Vector2 = sky.material.get_shader_parameter("half_extent")
	assert_float(half.y).is_equal_approx(tan(deg_to_rad(30.0)), 0.0001)
	assert_float(half.x).is_equal_approx(half.y * 16.0 / 9.0, 0.0001)
	# Turn the camera a quarter turn to the left: the tunnel's mouth is now off to the right.
	sky.set_view(portal * Basis(Vector3.UP, PI / 2), portal, 60.0, 16.0 / 9.0)
	view_to_tunnel = sky.material.get_shader_parameter("view_to_tunnel")
	assert_vector(view_to_tunnel * Vector3(1, 0, 0)).is_equal_approx(Vector3(0, 0, -1), Vector3.ONE * 0.0001)
	# The sky image follows the view's size.
	sky.set_view_size(Vector2i(1536, 864), 0.5)
	assert_vector(Vector2(sky.pass_view.size)).is_equal(Vector2(768, 432))
	assert_vector(sky.backdrop.get_shader_parameter("inv_view")).is_equal_approx(Vector2(1.0 / 1536, 1.0 / 864), Vector2.ONE * 0.0000001)
	sky.queue_free()
