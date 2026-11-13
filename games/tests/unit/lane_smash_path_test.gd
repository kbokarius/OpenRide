extends GdUnitTestSuite

func test_saved_routes_reproduce_and_cover_every_duration() -> void:
	var paths := {}
	for minutes in LaneSmashCatalog.LENGTHS:
		var ids: Array = LaneSmashCatalog.tracks(minutes).map(func(track): return track.id)
		for seed_value in [1, 17, 2147483646]: ids.append(LaneSmashCatalog.random_id(minutes, seed_value))
		for id: String in ids:
			var course := NeonCourse.load_course(id)
			var data: Dictionary = course.presentation
			assert_bool(LaneSmashPath.valid(data, course.roadLengthMeters)).is_true()
			assert_str(JSON.stringify(data)).is_equal(JSON.stringify(NeonCourse.load_course(id).presentation))
			paths[JSON.stringify(data)] = true
			var restored: Dictionary = JSON.parse_string(JSON.stringify(course, "", true, true))
			var original := LaneSmashCoaster.new()
			var replay := LaneSmashCoaster.new()
			original.build(course.roadLengthMeters, course.seed, false, data)
			replay.build(restored.roadLengthMeters, restored.seed, false, restored.presentation)
			for at in [0.0, 350.0, 850.0, float(course.roadLengthMeters)]:
				assert_float(original.at(at).origin.distance_to(replay.at(at).origin)).is_less(0.01)
	assert_int(paths.size()).is_equal(112)

func test_geometry_is_immutable_as_camera_and_cadence_change() -> void:
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("ls_10_01"), "challenging", 150)
	var space := NeonSpace.new()
	add_child(space)
	space.update_view(rules, 0, 0, -1, false, "")
	var anchors := {}
	for s in range(0, 1500, 20): anchors[s] = space.pose(s, -7.5, 0.05)
	var camera_before := space.camera.transform
	for distance in [100, 250, 500, 800, 1100]:
		rules.distance_units = distance * 1000000
		rules.latest.cadence = 140
		space.update_view(rules, 1, 0, -1, false, "")
		for s in anchors:
			var current := space.pose(s, -7.5, 0.05)
			assert_vector(current.origin).is_equal(anchors[s].origin)
			assert_float(current.basis.x.distance_to(anchors[s].basis.x)).is_less(0.000001)
		assert_float(space.camera.position.distance_to(camera_before.origin)).is_greater(10.0)
	space.free()

func test_width_and_orientation_are_continuous_and_reduced_motion_has_no_inversions() -> void:
	var route := LaneSmashCoaster.new()
	route.build(10400, 113, false)
	var inverted := 0
	for s in range(0, 10400, 2):
		var pose := route.at(s)
		assert_float(pose.basis.determinant()).is_equal_approx(1, 0.001)
		assert_float(pose.basis.y.dot(route.at(s + 2).basis.y)).is_greater(0.98)
		assert_float((pose * Vector3(-9, 0, 0)).distance_to(pose * Vector3(9, 0, 0))).is_equal_approx(18, 0.005)
		if pose.basis.y.y < -0.9: inverted += 1
	assert_int(inverted).is_greater(30)
	route.build(10400, 113, true)
	for s in range(0, 10400, 10): assert_float(route.at(s).basis.y.y).is_greater(0.98)

func test_presentation_preserves_old_score_and_ghost_identity() -> void:
	var current := NeonCourse.load_course("ls_15_01")
	var legacy := current.duplicate(true)
	legacy.erase("presentation")
	var old_hash := JSON.stringify(legacy, "", true, true).sha256_text()
	assert_str(NeonCourse.fingerprint(current)).is_equal(old_hash)
	var old_rules := NeonRules.new()
	var new_rules := NeonRules.new()
	old_rules.configure(legacy, "challenging", 150)
	new_rules.configure(current, "challenging", 150)
	assert_str(new_rules.comparison_key("rider")).is_equal(old_rules.comparison_key("rider"))
	current.presentation.path[1].yaw = 0.314
	current.presentation.roadOpacity = 0.8
	assert_str(NeonCourse.fingerprint(current)).is_equal(old_hash)
	current.events[0].laneIndex = 2
	assert_str(NeonCourse.fingerprint(current)).is_not_equal(old_hash)

func test_invalid_saved_route_is_rejected() -> void:
	var course := NeonCourse.load_course("ls_10_01")
	course.presentation.path[2].distanceMeters = 90
	assert_array(NeonCourse.validate(course)).contains(["Invalid presentation path"])
	course = NeonCourse.load_course("ls_10_01")
	course.presentation.path[2].yaw = "bad"
	assert_array(NeonCourse.validate(course)).contains(["Invalid presentation path"])
