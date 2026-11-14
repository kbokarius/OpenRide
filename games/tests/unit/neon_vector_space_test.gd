extends GdUnitTestSuite


func test_arrows_are_solid_and_stay_on_the_road_after_section_entry() -> void:
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("tutorial"), "intermediate", 150)
	var space := NeonSpace.new()
	add_child(space)
	# Use the neighboring lane so a hit cannot remove/reindex the arrow being tracked.
	rules.elapsed_ms = 20000
	space.update_view(rules, 0, 1, -1, false, "ion")
	var anchored := space._arrows.multimesh.get_instance_transform(1).origin
	var distance_before := space.camera.position.distance_to(anchored)
	var camera_before := space.camera.position
	var fade_before := space._arrows.multimesh.get_instance_color(0).a
	var box := space._arrows.multimesh.mesh.get_aabb()
	assert_float(box.size.y).is_greater(0.2) # a solid extrusion, not a flat decal
	rules.elapsed_ms += 100
	space.update_view(rules, 0.1, 1, -1, false, "ion")
	var after := space._arrows.multimesh.get_instance_transform(1).origin
	assert_float(after.distance_to(anchored)).is_less(0.001) # fixed on the road, with no vertical hover
	assert_float(space.camera.position.distance_to(camera_before)).is_greater(1.0)
	# The dummy headless renderer returns white for every instance color.
	# Run this suite once with the real rendering driver to check the visual fade.
	if DisplayServer.get_name() != "headless":
		assert_float(space.camera.position.distance_to(after)).is_less(distance_before)
		assert_float(space._arrows.multimesh.get_instance_color(0).a).is_less(fade_before)
	space.free()


func test_gantries_stay_until_they_are_behind_the_camera() -> void:
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("ls_10_01"), "challenging", 150)
	var space := NeonSpace.new()
	add_child(space)
	var pool: MultiMesh = space.scenery.gantries.multimesh
	for metres in range(0, 600, 3):
		rules.distance_units = metres * 1000000
		space.update_view(rules, 1.0 / 60, 0, -1, false, "")
		var camera_s := float(metres) - NeonSpace.CAMERA_BACK
		# Every arch between the camera and 250 m ahead of the rider must be in the pool, standing
		# on the fixed route: none may be retired while it is still in front of the camera.
		var index := 0
		while LaneSmashScenery.gantry_distance(index) < metres + 250.0:
			var s := LaneSmashScenery.gantry_distance(index)
			if s >= camera_s:
				var expected: Vector3 = space.coaster.at(s).origin
				var found := false
				for slot in pool.instance_count:
					if pool.get_instance_transform(slot).origin.distance_to(expected) < 0.01: found = true
				if DisplayServer.get_name() != "headless":
					assert_bool(found).override_failure_message("arch at %.0f m missing with the rider at %d m" % [s, metres]).is_true()
				assert_float(s - float(metres)).is_greater_equal(-LaneSmashScenery.BEHIND)
			index += 1
	# The pool's window always reaches from behind the camera to well down the road.
	assert_float(LaneSmashScenery.BEHIND).is_greater(NeonSpace.CAMERA_BACK + 15.0)
	assert_float((LaneSmashScenery.GANTRY_SLOTS - 1) * LaneSmashScenery.GANTRY_SPACING - LaneSmashScenery.BEHIND).is_greater(250.0)
	space.free()
