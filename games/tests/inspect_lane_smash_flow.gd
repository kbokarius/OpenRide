extends SceneTree
## Offline timing trace for the first two-and-a-half minutes, with ordinary target following.
func _initialize() -> void:
	var rules := NeonRules.new()
	rules.configure(NeonCourse.load_course("ls_15_01"), "challenging", 150)
	var key := ""
	var shots := {}
	for time in range(0, 150000, 50):
		var event := rules.current_event()
		var lane := LaneSmashSteering.target_for(rules)
		var rpm := 96.0
		if event.get("type") == "hold": rpm = (float(event.cadenceMin) + float(event.cadenceMax)) * 0.5
		if event.get("type") == "burst": rpm = 120.0
		if rules.barrage.active:
			rpm = 80.0
			var shot := rules.barrage.current_shot()
			if not shot.is_empty(): rpm = lerpf(float(shot.baselineRpm), float(shot.targetRpm), clampf((time - int(shot.fireMs)) / 4000.0, 0, 1))
		var current := "ATTACK" if rules.barrage.active else (str(event.get("eventId", "end")) + (" ACTIVE" if rules.road_time_ms() >= int(event.get("startMs", 0)) else " APPROACH"))
		if current != key:
			print("FLOW ", time, " ", current, " lane=", lane + 1, " road=", rules.road_time_ms(), " event=", event)
			key = current
		rules.push_sample({"t": time, "seq": time + 1, "cadence": rpm, "power": 200, "resistance": NeonRules.band(lane, "challenging").x + 3})
		rules.advance(time + 50)
		for shot: Dictionary in rules.barrage.shots:
			if bool(shot.resolved) and not shots.has(shot.shotId):
				shots[shot.shotId] = true
				print("SHOT ", JSON.stringify(shot))
	quit()
