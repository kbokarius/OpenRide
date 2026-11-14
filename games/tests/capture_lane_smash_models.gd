extends SceneTree
## Turntable stills of the Lane Smash models under the ride's own grade.
##   godot --path games -s res://tests/capture_lane_smash_models.gd -- --out=/abs/dir [--model=bike|ghost|attacker|mine] [--size=1100x700] [--visibility=0..1 (attacker fade)]

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.hide()
	_run.call_deferred()


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name): return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	var out := _arg("out", "user://model-review")
	var model := _arg("model", "bike")
	var dimensions := _arg("size", "1100x700").split("x")
	DirAccess.make_dir_recursive_absolute(out)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	var stage := Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = NeonSpace.make_environment()
	world.environment.background_color = Color("06080f")
	stage.add_child(world)
	var camera := Camera3D.new()
	camera.fov = 40
	stage.add_child(camera)
	camera.make_current()
	var subject: Node3D
	var focus := Vector3(0, 1.1, 0.2)
	var reach := 7.5
	match model:
		"ghost":
			var ghost := LaneSmashBike.new()
			ghost.translucent = true
			subject = ghost
		"attacker":
			subject = LaneSmashAttacker.new()
			focus = Vector3(0, 2.0, 0)
			reach = 11.0
		"mine":
			subject = Node3D.new()
			var mesh := MeshInstance3D.new()
			mesh.mesh = load("res://games/neon_vector/LaneSmashBombs.gd").call("mine_mesh")
			var material := ShaderMaterial.new()
			material.shader = load("res://games/neon_vector/ls_hull.gdshader")
			material.set_shader_parameter("accent", LaneSmashLook.DANGER)
			material.set_shader_parameter("rim_color", LaneSmashLook.DANGER)
			mesh.material_override = material
			subject.add_child(mesh)
			focus = Vector3(0, 0.0, 0)
			reach = 4.2
		_:
			subject = LaneSmashBike.new()
	stage.add_child(subject)
	if subject.has_method("tint"): subject.tint(LaneSmashLook.vivid(Color(_arg("accent", "8db9c9"))))
	for i in 6:
		if subject.has_method("animate"):
			if model == "attacker": subject.animate(float(_arg("visibility", "1.0")), i * 0.1, -1.0)
			else: subject.animate(100.0, 0.05)
		await process_frame
	var views := {"rear": Vector3(-0.42, 0.45, 1.0), "side": Vector3(1.0, 0.18, 0.05), "front": Vector3(0.55, 0.3, -1.0), "chase": Vector3(0.0, 0.5, 1.0)}
	for name: String in views:
		camera.position = focus + (views[name] as Vector3).normalized() * reach
		camera.look_at(focus)
		if subject.has_method("animate") and model != "attacker": subject.animate(100.0, 0.016)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("%s-%s.png" % [model, name]))
	print("MODEL REVIEW ", model, " views=", views.keys())
	stage.queue_free()
	await process_frame
	quit()
