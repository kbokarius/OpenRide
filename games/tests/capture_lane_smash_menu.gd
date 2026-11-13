extends SceneTree
## Isolated visual review of all card themes and menu sizes; never modifies real history.
var out := ""

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.hide()
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	if out.is_empty():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
	NeonRecords.path = "user://menu_review_" + NeonRecords.new_id()
	var options = load("res://framework/GameOptions.gd")
	options.path = NeonRecords.path + "_options.cfg"
	DisplayServer.window_set_size(Vector2i(1440, 810))
	change_scene_to_file("res://hub/Hub.tscn")
	await process_frame
	root.get_node("Session")._local.hub.begin_visit()
	await create_timer(1.0).timeout
	var setup: Node = current_scene.screen
	var checked := 0
	for duration in LaneSmashCatalog.LENGTHS:
		setup.length_picker.pick(str(duration))
		await process_frame
		await process_frame
		for card in setup.track_buttons:
			for child in card.get_children():
				if child is Label:
					assert(child.position.x + child.size.x <= card.size.x, "Card text overflows: " + child.text)
					assert(child.position.y + child.size.y <= card.size.y, "Card text is clipped: " + child.text)
			checked += 1
	setup.length_picker.pick("15")
	setup._pick_track(0)
	await create_timer(0.3).timeout
	for frame in 120:
		await create_timer(1.0 / 20.0).timeout
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		picture.save_jpg(out.path_join("frames/%04d.jpg" % frame), 0.9)
		if frame == 30: picture.save_png(out.path_join("menu.png"))
	var visible_card: Node = setup.track_buttons[0]
	var offscreen_card: Node = setup.track_buttons[24]
	var visible_before: float = visible_card.preview_distance
	var offscreen_before: float = offscreen_card.preview_distance
	await create_timer(0.2).timeout
	assert(visible_card.preview_distance > visible_before)
	assert(offscreen_card.preview_distance == offscreen_before)
	visible_card.reduced_motion = true
	visible_before = visible_card.preview_distance
	await create_timer(0.2).timeout
	assert(visible_card.preview_distance == visible_before)
	visible_card.reduced_motion = false
	for index in [3, 6, 9, 12, 15, 21]:
		setup._pick_track(index)
		setup.track_scroll.scroll_vertical = int(setup.track_buttons[index].position.y)
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("cards-%02d.png" % index))
	setup._open_extras()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("settings.png"))
	setup._close_panel()
	setup._random_track()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("random.png"))
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(dimensions)
		setup._pick_track(0)
		setup.track_scroll.scroll_vertical = 0
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("menu-%dx%d.png" % [dimensions.x, dimensions.y]))
	print("MENU REVIEW PASS cards=", checked, " visible/offscreen/reduced motion verified; four patterns/eight themes captured")
	current_scene.queue_free()
	await process_frame
	await process_frame
	quit()
