extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var totals := []
	for track in LaneSmashCatalog.tracks(20):
		var r := NeonRules.new()
		r.configure(NeonCourse.load_course(track.id), "challenging", 150)
		var rpm := 90.0
		for t in range(0, 1200000, 50):
			var e := r.current_event()
			var lane := int(e.get("laneIndex", 0))
			if r.barrage.active:
				lane = r.barrage.target_lane()
				var shot := r.barrage.current_shot()
				if not shot.is_empty(): rpm = lerpf(float(shot.baselineRpm), float(shot.targetRpm), clampf((t - int(shot.lockMs) - 2000) / 4000.0, 0, 1))
			else: rpm = (float(e.cadenceMin) + float(e.cadenceMax)) / 2 if e.get("type") == "hold" else (110.0 if e.get("type") == "burst" else 90.0)
			var resistance := NeonRules.band_center(lane, r.tier)
			# Modest lane-change reaction and occasional missed targets, not a perfect trace.
			if not r.barrage.active and t % 45000 < 1800: resistance = NeonRules.band_center((lane + 1) % 6, r.tier)
			var watts := roundi(rpm * (0.3 + resistance * 0.045))
			r.push_sample({"t": t, "seq": t + 1, "cadence": rpm, "power": watts, "resistance": resistance})
			r.advance(t + 50)
		var points := r.score_units / NeonRules.UNIT
		# New scoring removes credit for evading behind; this also calibrates older versions.
		if r.scoring_version == 5:
			for shot: Dictionary in r.barrage.shots:
				if not shot.hit and float(shot.impactRiderMeters) < float(shot.targetMeters): points -= shot.points
		totals.append(points)
	var sum := 0.0
	for value in totals: sum += value
	print("CALIBRATION tracks=",totals.size()," duration_min=20 mean=",sum/totals.size()," min=",totals.min()," max=",totals.max())
	quit()
