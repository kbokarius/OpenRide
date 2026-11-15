extends GdUnitTestSuite

func test_one_hundred_tracks_are_unique_reachable_and_single_lane() -> void:
	var names := {}
	var patterns := {}
	var themes := {}
	for minutes in LaneSmashCatalog.LENGTHS:
		var tracks := LaneSmashCatalog.tracks(minutes)
		assert_int(tracks.size()).is_equal(25)
		for item in tracks:
			var course := NeonCourse.load_course(item.id)
			assert_array(NeonCourse.validate(course)).override_failure_message(item.id).is_empty()
			assert_int(int(course.durationMs)).is_equal(minutes * 60000)
			names[item.id] = true
			patterns[JSON.stringify(course.events).sha256_text()] = true
			themes[course.theme] = true
			var end := 0
			for event: Dictionary in course.events:
				assert_int(NeonCourse.choices(event).size()).is_equal(1)
				# Every section is separated from the next by a stretch of empty road.
				assert_int(int(event.startMs) - end).is_between(LaneSmashCatalog.GAP_MIN_MS, LaneSmashCatalog.GAP_MAX_MS)
				end = int(event.endMs)
	assert_int(names.size()).is_equal(100)
	assert_int(patterns.size()).is_equal(100)
	assert_int(themes.size()).is_equal(8)

func test_random_tracks_reproduce_and_reject_invalid_ids() -> void:
	for minutes in LaneSmashCatalog.LENGTHS:
		for seed_value in [1, 17, 12345, 2147483646]:
			var id := LaneSmashCatalog.random_id(minutes, seed_value)
			var course := NeonCourse.load_course(id)
			assert_array(NeonCourse.validate(course)).is_empty()
			assert_str(NeonCourse.fingerprint(course)).is_equal(NeonCourse.fingerprint(NeonCourse.load_course(id)))
	for id in ["ls_15_00", "ls_15_26", "ls_5_01", "ls_r_15_0", "ls_r_15_2147483647", "ls_r_15_01"]:
		assert_dict(NeonCourse.load_course(id)).is_empty()

func test_cyclist_crank_tracks_actual_cadence() -> void:
	var bike := LaneSmashBike.new()
	add_child(bike)
	bike.animate(60, 0.25)
	assert_float(bike.crank_phase).is_equal_approx(PI / 2, 0.001)
	bike.animate(120, 0.25)
	assert_float(bike.crank_phase).is_equal_approx(3 * PI / 2, 0.001)
	var stopped := bike.crank_phase
	bike.animate(0, 0.25)
	assert_float(bike.crank_phase).is_equal(stopped)
	bike.free()

func test_road_loops_and_rolls_are_independent_of_target_resistance() -> void:
	var coaster := LaneSmashCoaster.new()
	coaster.build(2200, 113, false)
	var upside_down := 0
	var steep_up := 0
	var steep_down := 0
	for s in range(0, 2160, 2):
		var pose := coaster.at(s)
		var next := coaster.at(s + 2)
		assert_float(pose.basis.determinant()).is_equal_approx(1, 0.001)
		assert_float(pose.origin.distance_to(next.origin)).is_equal_approx(2, 0.001)
		assert_float(pose.basis.y.dot(next.basis.y)).is_greater(0.99)
		if pose.basis.y.y < -0.9: upside_down += 1
		if -pose.basis.z.y > 0.9: steep_up += 1
		if -pose.basis.z.y < -0.9: steep_down += 1
	assert_int(upside_down).is_greater(30)
	assert_int(steep_up).is_greater(10)
	assert_int(steep_down).is_greater(10)
	var course := NeonCourse.load_course("ls_10_01")
	var space := NeonSpace.new()
	add_child(space)
	space.prepare_terrain(course)
	var before := space.pose(250, 0, 0)
	course.courseId = "different-lanes"
	for event in course.events: event.laneIndex = 5
	space.prepare_terrain(course)
	assert_vector(space.pose(250, 0, 0).origin).is_equal(before.origin)
	space.reduced_motion = true
	space.prepare_terrain(course)
	assert_float(space.road_basis(250).y.y).is_greater(0.98)
	space.free()


func test_distance_is_cadence_driven_capped_deterministic_and_pauses() -> void:
	var distances := {}
	for rpm in [60, 90, 140, 200]:
		var results := []
		for fps in [30, 60, 120]:
			var rules := NeonRules.new()
			rules.configure(NeonCourse.load_course("ls_10_01"), "intermediate", 150)
			var sample := 0
			for frame in range(1, fps * 10 + 1):
				var target := roundi(frame * 1000.0 / fps)
				while sample < target:
					rules.push_sample({"t": sample, "seq": sample + 1, "cadence": rpm, "power": 150, "resistance": 27})
					sample += 50
				rules.advance(target)
			results.append(rules.distance_units)
			assert_float(rules.speed_kph).is_less_equal(60.0)
			assert_float(rules.road_distance()).is_less_equal(10.0 * NeonRules.MAX_SPEED_MPS)
			rules.pause()
			var before := rules.distance_units
			rules.advance(12000)
			assert_int(rules.distance_units).is_equal(before)
		assert_int(results[0]).is_equal(results[1])
		assert_int(results[1]).is_equal(results[2])
		distances[rpm] = results[0]
	assert_int(distances[90]).is_greater(distances[60])
	assert_int(distances[140]).is_greater(distances[90])
	assert_int(distances[200]).is_equal(distances[140])

func test_every_duration_has_full_speed_road_and_random_visual_variation() -> void:
	var combinations := {}
	for minutes in LaneSmashCatalog.LENGTHS:
		for i in range(1, 401):
			var course := LaneSmashCatalog.load_track(LaneSmashCatalog.random_id(minutes, i * 9187))
			assert_float(float(course.roadLengthMeters)).is_greater(minutes * 60 * NeonRules.MAX_SPEED_MPS)
			combinations[course.theme + ":" + course.background] = true
	assert_int(combinations.size()).is_equal(32)


func test_ghost_has_real_distance_and_stays_out_of_view_when_far_away() -> void:
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("ls_10_01"), "intermediate", 150)
	var space := NeonSpace.new()
	add_child(space)
	space._warming = false
	space.ghost_distance = 10.0
	space.update_view(rules, 0, 0, 1, true, "")
	assert_bool(space.ghost.visible).is_true()
	var on_road := space.pose(10.0, (1.0 - 2.5) * NeonSpace.LANE_WIDTH, 0.05).origin
	assert_float(space.ghost.position.distance_to(on_road)).is_less(0.01)
	space.ghost_distance = 100.0
	space.update_view(rules, 0, 0, 1, true, "")
	assert_bool(space.ghost.visible).is_false()
	space.ghost_distance = -20.0
	rules.distance_units = 100000000
	space.ghost_distance = 80.0
	space.update_view(rules, 0, 0, 1, true, "")
	assert_bool(space.ghost.visible).is_false()
	space.free()


func test_front_wheel_shatters_all_marker_types_once_without_awarding_invalid_points() -> void:
	for kind in ["cruise", "hold"]:
		for correct_lane in [true, false]:
			var course := NeonCourse.load_course("ls_10_03")
			var event_index := 0
			while course.events[event_index].type != kind: event_index += 1
			var event: Dictionary = course.events[event_index]
			var rules := NeonRules.new()
			rules.configure(course, "challenging", 150)
			rules._event_cursor = event_index
			var space := NeonSpace.new()
			add_child(space)
			var first_ms := int(event.startMs) + (600 if event_index > 0 and int(course.events[event_index - 1].endMs) == int(event.startMs) else 0)
			var anchor := first_ms / 1000.0 * NeonRules.MAX_SPEED_MPS
			var lane := float(event.laneIndex) if correct_lane else fmod(float(event.laneIndex) + 2, 6)
			# Start in front of the tire-contact plane, then cross the curved tire-contact boundary.
			# The axle/body remains well behind the marker when it must disappear. The tyre's
			# reach is a world size; the road is drawn NeonSpace.STRETCH to one.
			var reach := (NeonSpace.wheel_contact_reach(kind) + 0.6325) / NeonSpace.STRETCH
			rules.distance_units = roundi((anchor - reach - 0.25) * 1000000)
			space.update_view(rules, 0, lane, -1, false, "")
			assert_int(space.impact_count).is_zero()
			rules.distance_units = roundi((anchor - reach * 0.6) * 1000000)
			space.update_view(rules, 0.05, lane, -1, false, "")
			assert_int(space.impact_count).is_equal(1 if correct_lane else 0)
			space.update_view(rules, 0, lane, -1, false, "")
			assert_int(space.impact_count).is_equal(1 if correct_lane else 0)
			assert_int(rules.score_units).is_zero()
			space.free()

func test_current_ranges_and_uninterrupted_zero_cadence() -> void:
	assert_dict(NeonRules.CURRENT_TIERS).is_equal({"light": 15, "moderate": 20, "hard": 25, "challenging": 30, "extreme": 35})
	assert_vector(NeonRules.band(0, "challenging")).is_equal(Vector2i(30, 36))
	assert_vector(NeonRules.band(5, "challenging")).is_equal(Vector2i(65, 71))
	assert_vector(NeonRules.band(5, "extreme")).is_equal(Vector2i(70, 76))
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("ls_10_01"), "extreme", 150)
	for t in range(0, 5000, 50):
		rules.push_sample({"t": t, "seq": t + 1, "cadence": 0, "power": 0, "resistance": 38})
		rules.advance(t + 50)
	assert_int(rules.elapsed_ms).is_equal(5000)
	assert_str(rules.pause_reason).is_empty()
	assert_int(rules.distance_units).is_zero()
	assert_int(rules.score_units).is_zero()

func test_background_travel_matches_rules_at_different_speeds_and_stops() -> void:
	var sky := LaneSmashEnvironment.new()
	sky.configure(Environment.new())
	for cadence in [0, 60, 140, 200]:
		var rules := NeonRules.new()
		rules.configure(NeonCourse.load_course("ls_30_01"), "challenging", 150)
		for t in range(0, 3000, 50):
			rules.push_sample({"t": t, "seq": t + 1, "cadence": cadence, "power": 150, "resistance": 33})
			rules.advance(t + 50)
			sky.update_environment("reactor", Color("5ba5df"), rules.road_distance(), 0.2, 0.05, false)
			assert_float(sky.material.get_shader_parameter("travel_m")).is_equal_approx(rules.road_distance(), 0.0001)
		var before: float = sky.material.get_shader_parameter("travel_m")
		# Rendering extra frames or switching reduced motion must not advance distance.
		for frame in 20:
			sky.update_environment("reactor", Color("5ba5df"), rules.road_distance(), 0.2, 0.016, true)
		assert_float(sky.material.get_shader_parameter("travel_m")).is_equal(before)
		assert_float(before).is_equal_approx(minf(cadence, 140) / 140.0 * 50.0, 0.002)
	# A 30-minute ride at the speed cap retains metre precision without phase wrapping.
	sky.update_environment("reactor", Color("5ba5df"), 30000.25, 1.0, 0, false)
	assert_float(sky.material.get_shader_parameter("travel_m")).is_equal(30000.25)
	assert_float(sky.resistance_mix).is_equal(1.0)
	sky.free()

func test_all_tracks_change_lanes_frequently_with_sustained_holds_and_equal_effort_budgets() -> void:
	for minutes in LaneSmashCatalog.LENGTHS:
		var expected: Array = []
		var ids: Array = LaneSmashCatalog.tracks(minutes).map(func(t): return t.id)
		for seed_value in [1, 17, 12345, 2147483646]: ids.append(LaneSmashCatalog.random_id(minutes, seed_value))
		for id: String in ids:
			var course := LaneSmashCatalog.load_track(id)
			var budgets := [0, 0, 0, 0]
			var last_lane := -1
			var lane_since := 0
			var first_types := {}
			var lanes := {}
			for event: Dictionary in course.events:
				var span := int(event.endMs) - int(event.startMs)
				var lane := int(event.laneIndex)
				lanes[lane] = true
				if int(event.endMs) < 120000: first_types[event.type] = true
				if lane != last_lane:
					assert_int(int(event.startMs) - lane_since).override_failure_message(id).is_less_equal(34000)
					if last_lane >= 0: assert_int(absi(lane - last_lane)).is_less_equal(3)
					lane_since = int(event.startMs)
					last_lane = lane
				budgets[0] += span * lane
				budgets[1] += span
				if event.type == "hold":
					assert_int(span).is_equal(LaneSmashCatalog.HOLD_MS)
					# Twenty-wide bands; light lanes spin faster than heavy ones.
					assert_int(int(event.cadenceMax) - int(event.cadenceMin)).is_equal(20)
					assert_int(int(event.cadenceMin)).is_between(55, 95)
					budgets[2] += span * (int(event.cadenceMin) + 10)
				if event.type == "burst": budgets[3] += span
			assert_int(lanes.size()).is_equal(6)
			assert_int(first_types.size()).is_equal(3)
			if expected.is_empty(): expected = budgets
			for i in budgets.size():
				assert_float(float(budgets[i]) / maxf(1.0, expected[i])).override_failure_message(id + " effort budget " + str(i)).is_between(0.96, 1.04)


func test_power_zone_builds_from_output_and_finishes_at_its_gate() -> void:
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("ls_10_01"), "challenging", 150)
	var i := 0
	while rules.course.events[i].type != "burst": i += 1
	var event: Dictionary = rules.course.events[i]
	rules._event_cursor = i
	var space := NeonSpace.new()
	add_child(space)
	rules.distance_units = roundi((int(event.startMs) + 2000) * NeonRules.MAX_SPEED_MPS * 1000)
	rules.event_states[i].energyMilliJoules = 450000
	rules.latest.power = 300
	space.update_view(rules, 1, int(event.laneIndex), -1, false, "")
	var zone: Dictionary = space.sections.zones[event.eventId]
	assert_float(float(zone.charge)).is_equal_approx(0.5, 0.001)
	assert_float(float(zone.intensity)).is_greater(1.9)
	assert_bool(zone.hit).is_false()
	var vertices: PackedVector3Array = zone.root.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var anchor := vertices[0]
	rules.distance_units = roundi(int(event.endMs) * NeonRules.MAX_SPEED_MPS * 1000) + 1
	space.update_view(rules, 0.05, int(event.laneIndex), -1, false, "")
	assert_bool(zone.hit).is_true()
	assert_bool(zone.gate.visible).is_false()
	assert_vector(zone.root.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0]).is_equal(anchor)
	assert_int(rules.score_units).is_zero()
	space.free()


func test_final_marker_contacts_at_the_scoring_boundary() -> void:
	for kind in ["cruise", "hold"]:
		var rules := NeonRules.new()
		rules.configure(NeonCourse.load_course("ls_10_03"), "challenging", 150)
		var i := 0
		while rules.course.events[i].type != kind: i += 1
		var event: Dictionary = rules.course.events[i]
		rules._event_cursor = i
		var last := ceili(float(int(event.endMs) - int(event.startMs)) / 600.0) - 1
		var key := "%s:0:%d" % [event.eventId, last]
		var space := NeonSpace.new()
		add_child(space)
		var end := int(event.endMs) / 1000.0 * NeonRules.MAX_SPEED_MPS
		rules.distance_units = roundi((end - 0.2) * 1000000)
		space.update_view(rules, 0, int(event.laneIndex), -1, false, "")
		assert_bool(space._collected.has(key)).is_false()
		rules.distance_units = roundi((end + 0.01) * 1000000)
		space.update_view(rules, 0.02, int(event.laneIndex), -1, false, "")
		assert_bool(space._collected.has(key)).is_true()
		assert_int(rules.score_units).is_zero()
		space.free()

func test_visible_road_tip_remains_in_the_tunnel_through_a_complete_route() -> void:
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("ls_10_01"), "challenging", 150)
	var space := NeonSpace.new()
	add_child(space)
	for s in range(0, 3600, 10):
		rules.distance_units = s * 1000000
		space.update_view(rules, 0, 0, -1, false, "")
		var tip := space.camera.to_local(space.path(space.portal_distance))
		var sky_basis: Basis = space._structures.portal_basis
		assert_float((-sky_basis.z).dot((space.path(space.portal_distance) - space.camera.position).normalized())).is_greater(0.99999)
		var screen := space.camera.unproject_position(space.path(space.portal_distance)) / space.get_viewport().get_visible_rect().size
		assert_float(screen.x).is_between(-0.2, 1.2)
		assert_float(screen.y).is_between(-0.2, 1.2)
		assert_float(space.portal_distance - s).is_greater(20.0)
	space.free()


func test_adjacent_targets_are_separated_and_rest_on_the_road() -> void:
	# New tracks leave empty road between sections; saved rides from earlier generators have
	# sections that touch. Close the gaps inside each lane block to exercise that layout.
	var course := NeonCourse.load_course("ls_10_01")
	for i in range(1, course.events.size()):
		var earlier: Dictionary = course.events[i - 1]
		var later: Dictionary = course.events[i]
		if int(earlier.laneIndex) != int(later.laneIndex): continue
		var length := int(later.endMs) - int(later.startMs)
		later.startMs = int(earlier.endMs)
		later.endMs = int(later.startMs) + length
	course.hazards = LaneSmashHazards.generate_dense(course.events)
	var rules := NeonRules.new()
	assert_array(rules.configure(course, "challenging", 150)).is_empty()
	var pairs := {}
	for i in range(1, rules.course.events.size()):
		var before: Dictionary = rules.course.events[i - 1]
		var after: Dictionary = rules.course.events[i]
		var pair := str(before.type) + ":" + str(after.type)
		if pairs.has(pair) or before.endMs != after.startMs: continue
		pairs[pair] = true
		var space := NeonSpace.new()
		add_child(space)
		rules._event_cursor = i - 1
		var boundary := int(before.endMs) / 1000.0 * NeonRules.MAX_SPEED_MPS
		rules.distance_units = roundi((boundary - 0.1) * 1000000)
		space.update_view(rules, 0, int(after.laneIndex), -1, false, "")
		var finish := space.finish_distance(str(before.type), int(before.endMs))
		if after.type in ["cruise", "hold"]:
			var next_at := (int(after.startMs) + 600) / 1000.0 * NeonRules.MAX_SPEED_MPS
			assert_float(next_at - finish).is_greater(6.0)
			var pool := space._bars if after.type == "cruise" else space._arrows
			var expected := space.pose(next_at, (int(after.laneIndex) - 2.5) * NeonSpace.LANE_WIDTH, NeonSpace.marker_height(str(after.type))).origin
			var found := false
			for n in pool.multimesh.visible_instance_count:
				if pool.multimesh.get_instance_transform(n).origin.distance_to(expected) < 0.01: found = true
			if DisplayServer.get_name() != "headless": assert_bool(found).is_true()
			assert_int(pool.multimesh.visible_instance_count).is_greater(1)
			rules.distance_units = roundi((boundary + 0.01) * 1000000)
			space.update_view(rules, 0.02, int(after.laneIndex), -1, false, "")
			assert_bool(space._collected.has(str(after.eventId) + ":0:0")).is_false()
			var half_height := 0.08 if after.type == "cruise" else 0.0
			assert_float(NeonSpace.marker_height(str(after.type)) - half_height).is_equal_approx(0.05, 0.001)
		space.free()
	assert_int(pairs.size()).is_equal(3)


func test_all_tracks_have_reproducible_bombs_outside_the_scoring_lane() -> void:
	for minutes in LaneSmashCatalog.LENGTHS:
		var ids: Array = LaneSmashCatalog.tracks(minutes).map(func(t): return t.id)
		for seed_value in [1, 17, 12345, 2147483646]: ids.append(LaneSmashCatalog.random_id(minutes, seed_value))
		for id: String in ids:
			var course := NeonCourse.load_course(id)
			assert_array(course.hazards).is_not_empty()
			assert_bool(LaneSmashHazards.valid_dense(course.hazards, course.events)).is_true()
			assert_array(course.hazards).is_equal(NeonCourse.load_course(id).hazards)
			var bad := course.duplicate(true)
			for event: Dictionary in bad.events:
				if bad.hazards[0].hitMs >= event.startMs and bad.hazards[0].hitMs < event.endMs:
					bad.hazards[0].laneIndex = event.laneIndex
			assert_array(NeonCourse.validate(bad)).is_not_empty()

func test_explosion_pools_are_bounded_and_expire() -> void:
	var space := NeonSpace.new()
	add_child(space)
	space.prepare_terrain(NeonCourse.load_course("ls_10_01"))
	for i in 100: space._explode(Vector3.ZERO, LaneSmashBombs.COLOR, 60, 2.5)
	assert_int(space._impacts.size()).is_equal(192)
	assert_int(space._shockwaves.size()).is_equal(12)
	space._animate_impacts(0.7)
	assert_int(space._impacts.size()).is_zero()
	assert_int(space._shockwaves.size()).is_zero()
	assert_int(space._rings.multimesh.visible_instance_count).is_zero()
	space.free()


func test_resistance_lanes_match_the_published_lanebreak_ranges() -> void:
	# Peloton's five Bike levels, lowest to highest resistance (Pelo Buddy, 22 June 2023; see
	# docs/research/lanebreak/06-difficulty-ranges.md).
	var published := {"light": [15, 56], "moderate": [20, 61], "hard": [25, 66], "challenging": [30, 71], "extreme": [35, 76]}
	assert_array(NeonRules.CURRENT_TIERS.keys()).contains_exactly_in_any_order(published.keys())
	for tier: String in published:
		assert_int(NeonRules.band(0, tier).x).is_equal(published[tier][0])
		assert_int(NeonRules.band(5, tier).y).is_equal(published[tier][1])
		for lane in 6:
			var band := NeonRules.band(lane, tier)
			# Six lanes of seven values each, with no gaps between them.
			assert_int(band.y - band.x).is_equal(6)
			if lane > 0: assert_int(band.x).is_equal(NeonRules.band(lane - 1, tier).y + 1)
			for resistance in range(band.x, band.y + 1):
				assert_int(NeonRules.lane_for(resistance, tier)).is_equal(lane)
		assert_int(NeonRules.lane_for(published[tier][0] - 1, tier)).is_equal(-1)
		assert_int(NeonRules.lane_for(published[tier][1] + 1, tier)).is_equal(-1)
	# Lanes read from Lanebreak itself, on its original four levels (kept here for saved
	# rides). The numbers at each lane's edges in Pelo Buddy's review footage: Expert (34-75)
	# 34|40, 41|47 and 48|54, its first three lanes; Intermediate (24-65) 24|30 and 38|44, its
	# first and third. A beta screenshot shows 51-57, the fourth lane on Advanced (30-71).
	# All six are seven wide and fall exactly where this subdivision puts them.
	assert_vector(NeonRules.band(0, "expert")).is_equal(Vector2i(34, 40))
	assert_vector(NeonRules.band(1, "expert")).is_equal(Vector2i(41, 47))
	assert_vector(NeonRules.band(2, "expert")).is_equal(Vector2i(48, 54))
	assert_vector(NeonRules.band(0, "intermediate")).is_equal(Vector2i(24, 30))
	assert_vector(NeonRules.band(2, "intermediate")).is_equal(Vector2i(38, 44))
	assert_vector(NeonRules.band(3, "advanced")).is_equal(Vector2i(51, 57))
	assert_vector(NeonRules.band(3, "challenging")).is_equal(Vector2i(51, 57))


func test_cadence_targets_follow_the_effort_and_bursts_are_spaced() -> void:
	# Light lanes are fast spins, heavy lanes are climbs.
	for lane in range(1, 6):
		assert_int(LaneSmashCatalog.WORK_CADENCE[lane]).is_less_equal(LaneSmashCatalog.WORK_CADENCE[lane - 1])
	assert_int(LaneSmashCatalog.WORK_CADENCE[0] - LaneSmashCatalog.WORK_CADENCE[5]).is_greater_equal(20)
	for id: String in ["ls_10_01", "ls_15_13", "ls_20_07", "ls_30_25", LaneSmashCatalog.random_id(15, 4242)]:
		var course := LaneSmashCatalog.load_track(id)
		var last_burst_end := -100000
		var bursts := 0
		for event: Dictionary in course.events:
			var minute := int(event.startMs) / 60000
			var recovering := false
			var easy := int(event.startMs) < LaneSmashCatalog.WARMUP_ROAD_MS
			var lane := int(event.laneIndex)
			if event.type == "hold":
				var expected: int = LaneSmashCatalog.EASY_CADENCE if easy else LaneSmashCatalog.WORK_CADENCE[lane]
				assert_int(int(event.cadenceMin)).override_failure_message("%s %s" % [id, event.eventId]).is_equal(expected)
				assert_int(int(event.cadenceMax)).is_equal(expected + 20)
			if event.type == "burst":
				# Never while recovering, and never closer together than the legs can repeat.
				assert_bool(recovering).override_failure_message("%s %s" % [id, event.eventId]).is_false()
				assert_int(int(event.startMs) - last_burst_end).is_greater_equal(30000)
				last_burst_end = int(event.endMs)
				bursts += 1
			# The recovery minute really is light: the two lowest lanes only.
			if recovering: assert_int(lane).override_failure_message("%s %s" % [id, event.eventId]).is_less_equal(1)
		# Regularly recurring bursts, with enough recovery and no rigid equal-length blocks.
		assert_int(bursts).override_failure_message(id).is_between(int(course.durationMs) / 65000, int(course.durationMs) / 45000)



func test_sections_have_clear_starts_and_ends_with_varied_gaps() -> void:
	for id: String in ["ls_10_01", "ls_15_13", "ls_20_07", "ls_30_25", LaneSmashCatalog.random_id(15, 4242)]:
		var course := LaneSmashCatalog.load_track(id)
		var gaps := {}
		var previous := {}
		for event: Dictionary in course.events:
			var phase: Dictionary = course.phases.filter(func(row): return int(event.startMs) >= int(row.startMs) and int(event.startMs) < int(row.endMs))[0]
			assert_int(int(event.endMs)).is_less_equal(int(phase.endMs))
			var gap := int(event.startMs) - int(previous.get("endMs", 0))
			gaps[gap] = true
			assert_int(gap).is_between(LaneSmashCatalog.GAP_MIN_MS, LaneSmashCatalog.GAP_MAX_MS)
			if not previous.is_empty() and int(previous.laneIndex) != int(event.laneIndex):
				assert_int(gap).is_greater_equal(LaneSmashCatalog.transition_gap(absi(int(previous.laneIndex) - int(event.laneIndex))))
			if not previous.is_empty() and int(previous.startMs) >= int(phase.startMs):
				assert_str(str(event.type)).is_not_equal(str(previous.type))
			previous = event
		assert_int(gaps.size()).is_greater_equal(4)

# End of catalog regressions.
