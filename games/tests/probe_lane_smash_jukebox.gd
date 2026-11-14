extends SceneTree
## Real-audio smoke run of the Lane Smash jukebox: loads the longest real track off the main
## thread, plays a few seconds, and reports load time, frame hitches, position, raw band
## levels and the published analysis. It makes sound for about seven seconds.
##
##   godot --path games -s res://tests/probe_lane_smash_jukebox.gd [-- --seconds=4 --track=2 --from=1800]
##
## Uses isolated settings; never touches ride history.

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.hide()
	_run.call_deferred()


func _arg(name: String, fallback: float) -> float:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name): return float(arg.trim_prefix("--%s=" % name))
	return fallback


func _run() -> void:
	var seconds := _arg("seconds", 4.0)
	var options = load("res://framework/GameOptions.gd")
	options.path = "user://jukebox_probe_" + NeonRecords.new_id() + ".cfg"
	options.reload()
	options.apply_audio()
	var jukebox: Node = root.get_node("Jukebox")
	var list: Array = jukebox.tracks()
	var names: Array[String] = []
	for track: Dictionary in list: names.append("%s (%.0f s)" % [track.title, track.length_sec])
	print("PROBE display=", DisplayServer.get_name(), " autoplay=", jukebox.autoplay, " started_by_itself=", jukebox.is_started(), " tracks=", names)
	if list.is_empty():
		quit(1)
		return
	var longest := 0
	for i in list.size():
		if float(list[i].length_sec) > float(list[longest].length_sec): longest = i
	if _arg("track", -1.0) >= 0.0: longest = clampi(int(_arg("track", 0.0)), 0, list.size() - 1)
	var from := _arg("from", float(list[longest].length_sec) * 0.37)
	var memory_before := OS.get_static_memory_usage()
	var hitch := await _start(jukebox, longest, from)
	print("PROBE track='%s' load_msec=%d longest_frame_while_loading_msec=%.1f memory_mb=+%.1f position=%.2f length=%.1f" % [
		jukebox.title(), jukebox.last_load_msec, hitch, (OS.get_static_memory_usage() - memory_before) / 1048576.0, jukebox.position_sec(), jukebox.length_sec()])
	var count: int = jukebox.BAND_COUNT
	var low := PackedFloat32Array()
	var high := PackedFloat32Array()
	var sum := PackedFloat32Array()
	low.resize(count)
	high.resize(count)
	sum.resize(count)
	low.fill(0.0)
	high.fill(-200.0)
	var peaks := {"level": 0.0, "bass": 0.0, "mid": 0.0, "treble": 0.0, "beat": 0.0}
	var means := {"level": 0.0, "bass": 0.0, "mid": 0.0, "treble": 0.0}
	var frames := 0
	var beats: int = jukebox.beat_count
	var flow: float = jukebox.flow
	var longest_frame := 0.0
	var series := {"raw_30_60": [], "raw_60_130": [], "raw_2100_4500": [], "bass": [], "mid": [], "treble": [], "level": []}
	var last := Time.get_ticks_usec()
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end:
		await process_frame
		var now := Time.get_ticks_usec()
		longest_frame = maxf(longest_frame, (now - last) / 1000.0)
		last = now
		frames += 1
		for b in count:
			var db := linear_to_db(maxf(0.0000001, float(jukebox._magnitude(jukebox.BAND_EDGES[b], jukebox.BAND_EDGES[b + 1]))))
			low[b] = minf(low[b], db)
			high[b] = maxf(high[b], db)
			sum[b] += db
			if b == 0: series.raw_30_60.append(db)
			if b == 1: series.raw_60_130.append(db)
			if b == 6: series.raw_2100_4500.append(db)
		for key in ["bass", "mid", "treble", "level"]: series[key].append(float(jukebox.get(key)))
		for key in peaks: peaks[key] = maxf(peaks[key], float(jukebox.get(key)))
		for key in means: means[key] += float(jukebox.get(key))
	var rows: Array[String] = []
	for b in count: rows.append("%d-%dHz %.0f/%.0f/%.0f" % [jukebox.BAND_EDGES[b], jukebox.BAND_EDGES[b + 1], low[b], sum[b] / frames, high[b]])
	print("PROBE raw band dB min/mean/max: ", ", ".join(rows))
	var spread: Array[String] = []
	for key: String in series:
		var values: Array = series[key]
		values.sort()
		spread.append("%s %.2f/%.2f/%.2f" % [key, values[values.size() / 10], values[values.size() / 2], values[values.size() * 9 / 10]])
	print("PROBE p10/p50/p90: ", ", ".join(spread))
	for key in means: means[key] = snappedf(means[key] / frames, 0.01)
	for key in peaks: peaks[key] = snappedf(peaks[key], 0.01)
	print("PROBE analysis over %.1f s: frames=%d longest_frame_msec=%.1f mean=%s peak=%s beats=%d (%.2f/s) flow=+%.2f latency_msec=%.0f position=%.2f" % [
		seconds, frames, longest_frame, means, peaks, jukebox.beat_count - beats, (jukebox.beat_count - beats) / seconds, jukebox.flow - flow,
		AudioServer.get_output_latency() * 1000.0, jukebox.position_sec()])
	# A seek stays on the same track and lands where asked.
	var target := float(list[longest].length_sec) * 0.6
	jukebox.seek(target)
	await create_timer(0.6).timeout
	print("PROBE seek to %.1f -> position=%.2f same_track=%s playing=%s" % [target, jukebox.position_sec(), jukebox.current == longest, jukebox.is_playing()])
	# Music Off holds the place without decoding; On resumes there.
	root.get_node("AudioDirector").set_user_audio(false, true)
	await create_timer(0.4).timeout
	var held: float = jukebox.position_sec()
	print("PROBE music off: playing=%s position=%.2f level=%.3f" % [jukebox.is_playing(), held, jukebox.level])
	root.get_node("AudioDirector").set_user_audio(true, true)
	await create_timer(0.5).timeout
	print("PROBE music on: playing=%s position=%.2f (held %.2f)" % [jukebox.is_playing(), jukebox.position_sec(), held])
	# Switching track loads the next one in the background and frees the previous stream.
	var other := (longest + 1) % list.size()
	memory_before = OS.get_static_memory_usage()
	hitch = await _start(jukebox, other, 600.0 if list.size() > 1 else 30.0)
	await create_timer(0.8).timeout
	print("PROBE switch track='%s' load_msec=%d longest_frame_while_loading_msec=%.1f memory_mb=%+.1f position=%.2f level=%.2f" % [
		jukebox.title(), jukebox.last_load_msec, hitch, (OS.get_static_memory_usage() - memory_before) / 1048576.0, jukebox.position_sec(), jukebox.level])
	jukebox.set_playlist([])
	DirAccess.remove_absolute(options.path)
	await process_frame
	quit()


## Selects a track and waits until it is audible; returns the longest frame meanwhile (ms).
func _start(jukebox: Node, index: int, from: float) -> float:
	var longest := 0.0
	var last := Time.get_ticks_usec()
	var deadline := Time.get_ticks_msec() + 30000
	jukebox.select(index, from)
	while not jukebox.is_playing() and Time.get_ticks_msec() < deadline:
		await process_frame
		var now := Time.get_ticks_usec()
		longest = maxf(longest, (now - last) / 1000.0)
		last = now
	return longest
