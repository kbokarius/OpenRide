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
	# Road metres (the route's unit): the camera's distance behind the rider, how far behind an
	# arch is kept, and how far ahead the pool reaches.
	var camera_back := NeonSpace.CAMERA_BACK / NeonSpace.STRETCH
	var kept_behind := LaneSmashScenery.BEHIND / NeonSpace.STRETCH
	var reach := ((LaneSmashScenery.GANTRY_SLOTS - 1) * LaneSmashScenery.GANTRY_SPACING - LaneSmashScenery.BEHIND) / NeonSpace.STRETCH
	for metres in range(0, 400, 2):
		rules.distance_units = metres * 1000000
		space.update_view(rules, 1.0 / 60, 0, -1, false, "")
		# Every arch from the camera to most of the pool's reach must be standing on the fixed
		# route: none may be retired while it is still in front of the camera.
		var index := 0
		while LaneSmashScenery.gantry_distance(index) < metres + reach * 0.9:
			var s := LaneSmashScenery.gantry_distance(index)
			if s >= metres - camera_back:
				var expected: Vector3 = space.coaster.at(s).origin
				var found := false
				for slot in pool.instance_count:
					if pool.get_instance_transform(slot).origin.distance_to(expected) < 0.01: found = true
				if DisplayServer.get_name() != "headless":
					assert_bool(found).override_failure_message("arch at %.0f m missing with the rider at %d m" % [s, metres]).is_true()
			index += 1
	# Kept until well behind the camera, and visible far enough ahead to form a receding row.
	assert_float(kept_behind).is_greater(camera_back * 2.0)
	assert_float(reach * NeonSpace.STRETCH).is_greater(400.0)
	space.free()


func test_the_world_is_drawn_stretched_but_the_rules_distance_is_not() -> void:
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("ls_10_01"), "challenging", 150)
	var space := NeonSpace.new()
	add_child(space)
	space.update_view(rules, 0, 0, -1, false, "")
	# One road metre is STRETCH world metres along the route, everywhere.
	for s in [0.0, 40.0, 333.0, 1500.0]:
		assert_float(space.path(s).distance_to(space.path(s + 1.0))).is_equal_approx(NeonSpace.STRETCH, 0.02)
	# Ten seconds at 140 rpm is still exactly 166.67 road metres to the rules.
	for t in range(0, 10000, 50):
		rules.push_sample({"t": t, "seq": t + 1, "cadence": 140, "power": 200, "resistance": 33})
		rules.advance(t + 50)
	assert_float(rules.road_distance()).is_equal_approx(NeonRules.MAX_SPEED_MPS * 10.0, 0.01)
	space.free()


## Rides `seconds` at 30 fps with the bike parked at 100 m, calling `each_frame(frame)` before
## every update, and returns the power of every seam pulse launched.
func _launches(space: NeonSpace, rules: NeonRules, seconds: float, each_frame: Callable) -> Array[float]:
	var launched: Array[float] = []
	var delta := 1.0 / 30
	for frame in int(seconds * 30):
		each_frame.call(frame)
		space.update_view(rules, delta, 0, -1, false, "")
		for i in NeonSpace.WAVES:
			if space._wave_age[i] <= delta * 1.01 and space._wave_power[i] > 0.0:
				launched.append(space._wave_power[i])
				# A new pulse starts just ahead of the front wheel and is still nearly dark:
				# it brightens as it pulls away instead of flashing beside the bike.
				assert_float(space._wave_front[i] - space.distance * NeonSpace.STRETCH).is_between(2.0, 12.0)
				assert_float(space._wave_gain[i]).is_less(0.15)
	return launched


func test_seam_pulses_launch_on_the_beat_and_keep_a_soft_rhythm_in_silence() -> void:
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("ls_10_01"), "challenging", 150)
	rules.distance_units = 100 * 1000000
	var space := NeonSpace.new()
	add_child(space)
	# Nothing playing: a soft pulse every 0.9 s, so the road is never dead.
	var quiet := _launches(space, rules, 3.0, func(_frame): pass)
	assert_int(quiet.size()).is_between(3, 4)
	for power in quiet: assert_float(power).is_between(0.3, 0.65)
	# A 120 BPM kick: exactly one pulse per kick, stronger than the idle ones.
	space.music = Vector4(0.8, 0.4, 0.3, 0.3)
	var beats := [0]
	var kicked := _launches(space, rules, 3.0, func(frame: int):
		if frame % 15 == 0:
			beats[0] += 1
			space.music_beats = beats[0])
	assert_int(kicked.size()).is_equal(6)
	for power in kicked: assert_float(power).is_greater(0.9)
	# Every pulse runs ahead of the bike, and none is ever brighter than its launch power.
	for i in NeonSpace.WAVES:
		assert_float(space._wave_front[i]).is_greater(space.distance * NeonSpace.STRETCH)
		assert_float(space._wave_gain[i]).is_less_equal(space._wave_power[i])
	# Reduced motion ignores the kicks and keeps only the soft rhythm.
	space.reduced_motion = true
	var reduced := _launches(space, rules, 3.0, func(frame: int):
		if frame % 15 == 0:
			beats[0] += 1
			space.music_beats = beats[0])
	assert_int(reduced.size()).is_between(3, 4)
	for power in reduced: assert_float(power).is_less(0.65)
	space.free()


func test_seam_colours_swell_with_the_spectrum_instead_of_jumping() -> void:
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("ls_10_01"), "challenging", 150)
	var space := NeonSpace.new()
	add_child(space)
	var full := PackedFloat32Array()
	full.resize(8)
	full.fill(1.0)
	space.music_bands = full
	var previous := 0.0
	for frame in 60:
		space.update_view(rules, 1.0 / 30, 0, -1, false, "")
		# No seam moves more than a quarter of its range in one frame, even on a full-scale step.
		assert_float(space._seams.x - previous).is_less(0.25)
		previous = space._seams.x
	for i in 4: assert_float(space._seams[i]).is_greater(0.95)
	space.music_bands = PackedFloat32Array()
	for frame in 90: space.update_view(rules, 1.0 / 30, 0, -1, false, "")
	for i in 4: assert_float(space._seams[i]).is_less(0.01)
	space.free()
