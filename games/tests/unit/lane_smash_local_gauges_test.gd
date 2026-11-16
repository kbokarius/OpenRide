extends GdUnitTestSuite

func _rules() -> NeonRules:
	var course := NeonCourse.load_course("ls_10_01")
	var rules := NeonRules.new()
	assert_array(rules.configure(course, "challenging", 150)).is_empty()
	return rules

func test_bomb_meter_uses_authoritative_projection_and_distinguishes_results() -> void:
	var rules := _rules()
	assert_dict(LaneSmashBarrageGauge.read(rules)).is_empty()
	rules.barrage.active = true
	rules.barrage.section = {"barrageId": "test", "startMs": 10000, "laneIndex": 3}
	assert_str(LaneSmashBarrageGauge.read(rules).state).is_equal("prepare")
	var shot := {"shotId": "shot", "sectionId": "test", "direction": "faster", "targetRpm": 120,
		"targetMeters": 100.0, "impactMs": 10000, "impactRiderMeters": 0.0, "resolved": false, "points": 0}
	rules.barrage.shots.append(shot)
	rules.speed_kph = 36
	var snapshot := LaneSmashBarrageGauge.read(rules)
	assert_float(float(snapshot.offset)).is_equal(0.0)
	assert_str(snapshot.prompt).is_equal("PEDAL FASTER")
	rules.speed_kph = 60
	assert_float(float(LaneSmashBarrageGauge.read(rules).offset)).is_greater(60)
	assert_str(LaneSmashBarrageGauge.read(rules).prompt).is_equal("KEEP THIS PACE")
	shot.rapid = true
	assert_str(LaneSmashBarrageGauge.read(rules).prompt).is_equal("WRONG LANE")
	shot.resolved = true
	for row in [["passed", 1800, "PASSED", "+1800 points"], ["held_back", 0, "AVOIDED", "No points"], ["hit", -1800, "BOMB HIT", "−1800 points"]]:
		shot.outcome = row[0]
		shot.points = row[1]
		snapshot = LaneSmashBarrageGauge.read(rules)
		assert_str(snapshot.prompt).is_equal(row[2])
		assert_str(snapshot.detail).is_equal(row[3])
	rules.pause_reason = "sensor"
	assert_dict(LaneSmashBarrageGauge.read(rules)).is_empty()

func test_bomb_meter_tracks_without_overlapping_bike_or_leaving_play_area() -> void:
	var gauge := LaneSmashBarrageGauge.new()
	var bounds := Rect2(48, 340, 1824, 560)
	var live := {"id": "shot", "state": "live", "offset": 0.0, "seconds": 8, "prompt": "PEDAL FASTER", "detail": "120 rpm target"}
	for bike in [Vector2(300,700), Vector2(480,700), Vector2(960,700), Vector2(1440,700), Vector2(1620,700)]:
		gauge.update(0, live, bike, bounds)
		assert_bool(bounds.encloses(Rect2(gauge.centre - gauge.SIZE * 0.5, gauge.SIZE))).is_true()
		assert_float(absf(gauge.centre.x - bike.x) - gauge.SIZE.x * 0.5).is_greater_equal(132)
	live.offset = 60.0
	gauge.update(0.05, live, Vector2(960,700), bounds)
	assert_float(gauge.shown_offset).is_between(1,59)
	gauge.update(0.05, {}, Vector2(960,700), bounds)
	assert_float(gauge.alpha).is_between(0.5,0.99)
	gauge.update(1, {}, Vector2(960,700), bounds)
	assert_float(gauge.alpha).is_zero()
	assert_float(gauge.level(-100)).is_equal(0.0)
	assert_float(gauge.level(0)).is_equal(0.5)
	assert_float(gauge.level(100)).is_equal(1.0)

func test_cadence_preview_uses_seconds_at_all_speeds_and_only_the_current_section() -> void:
	for rpm in [45, 65, 90, 140]:
		var rules := _rules()
		rules.events = [{"eventId":"hold", "type":"hold", "startMs":10000, "endMs":20000, "laneIndex":5, "cadenceMin":55, "cadenceMax":75}]
		rules.latest = {"cadence":rpm}
		rules.speed_kph = rpm / 140.0 * 60
		for ahead in [2000, 1300, 1100, 500]:
			var road_left: float = ahead * rpm / 140.0
			rules.distance_units = roundi((10000 - road_left) * NeonRules.MAX_SPEED_MPS * 1000)
			var preview := rules.cadence_target()
			assert_bool(preview.is_empty()).override_failure_message("rpm=%d ahead=%d" % [rpm,ahead]).is_equal(ahead > 1200)
			if not preview.is_empty(): assert_bool(preview.active).is_false()
		# A previous Collect must finish before another cadence preview is announced.
		rules.events.push_front({"eventId":"collect", "type":"cruise", "startMs":0, "endMs":9900, "laneIndex":5})
		assert_dict(rules.cadence_target()).is_empty()

func test_cadence_starts_with_a_visible_zone_meter_and_firing_gunner_in_every_lane() -> void:
	var space: NeonSpace = auto_free(NeonSpace.new())
	add_child(space)
	space._warming = false
	for lane in 6:
		var course := NeonCourse.load_course("ls_10_01")
		course.events = [{"eventId":"hold-%d" % lane, "type":"hold", "startMs":2000, "endMs":12000, "laneIndex":lane, "cadenceMin":55, "cadenceMax":75}]
		course.hazards = []
		course.barrages = []
		var rules := NeonRules.new()
		assert_array(rules.configure(course,"challenging",150)).is_empty()
		while rules.road_time_ms() < 2020:
			var time := rules.elapsed_ms
			rules.push_sample({"t":time,"seq":time+1,"cadence":65,"power":150,"resistance":NeonRules.band_center(lane,rules.tier)})
			rules.advance(time+50)
		var before := space.gunfire_view.shots_fired
		space.update_view(rules, 0.05, lane, -1, false, "")
		assert_bool(rules.cadence_target().active).is_true()
		assert_str(rules.gunfire().eventId).is_equal(rules.current_event().eventId)
		assert_bool(space.gunfire_view.gunner.visible).is_true()
		var screen := space.camera.unproject_position(space.gunfire_view.gunner.global_position)
		assert_bool(space.camera.get_viewport().get_visible_rect().has_point(screen)).override_failure_message("Gunner offscreen in lane %d" % (lane+1)).is_true()
		assert_int(space.gunfire_view.shots_fired).is_greater(before)
		assert_bool(space.sections.zones.has(rules.current_event().eventId)).is_true()
		var zone: Dictionary = space.sections.zones[rules.current_event().eventId]
		assert_bool(zone.root.visible).is_true()
		assert_float(float(zone.material.get_shader_parameter("visible_alpha"))).is_greater(0.9)

func test_top_prompt_switches_from_up_next_to_now_without_waiting_for_a_second() -> void:
	var rules := _rules()
	rules.events = [{"eventId":"hold", "type":"hold", "startMs":10000, "endMs":20000, "laneIndex":5, "cadenceMin":55, "cadenceMax":75}]
	rules.latest = {"cadence":65,"resistance":68}
	rules.selected_lane = 5
	rules.settled_lane = 5
	var status: NeonStatus = auto_free(NeonStatus.new())
	status.rules = rules
	add_child(status)
	status.set_process(false)
	rules.distance_units = roundi(9990 * NeonRules.MAX_SPEED_MPS * 1000)
	status.refresh()
	assert_str(status.heading.text).is_equal("UP NEXT · PEDAL SPEED")
	rules.distance_units = roundi(10001 * NeonRules.MAX_SPEED_MPS * 1000)
	status.refresh()
	assert_str(status.heading.text).is_equal("NOW · PEDAL SPEED")
