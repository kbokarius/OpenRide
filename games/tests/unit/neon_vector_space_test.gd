extends GdUnitTestSuite


func test_arrows_are_raised_and_move_toward_camera_after_section_entry() -> void:
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("tutorial"), "intermediate", 150)
	var space := NeonSpace.new()
	add_child(space)
	rules.elapsed_ms = 20000
	space.update_view(rules, 0, 0, -1, false, "ion")
	var anchored := space._arrows.multimesh.get_instance_transform(3).origin
	var in_view := space.camera.to_local(anchored)
	var camera_before := space.camera.position
	var fade_before := space._arrows.multimesh.get_instance_color(0).a
	var box := space._arrows.multimesh.mesh.get_aabb()
	assert_float(box.size.y).is_greater(0.2) # a solid extrusion, not a flat decal
	rules.elapsed_ms += 100
	space.update_view(rules, 0.1, 0, -1, false, "ion")
	var after := space._arrows.multimesh.get_instance_transform(3).origin
	assert_float(after.distance_to(anchored)).is_less(0.03) # only the small vertical hover changes
	assert_float(space.camera.position.distance_to(camera_before)).is_greater(1.0)
	assert_float(space.camera.to_local(after).z).is_greater(in_view.z)
	# The dummy headless renderer returns white for every instance color.
	# Run this suite once with the real rendering driver to check the visual fade.
	if DisplayServer.get_name() != "headless":
		assert_float(space._arrows.multimesh.get_instance_color(0).a).is_less(fade_before)
	space.free()
