extends SceneTree
## Measures how long after a sound the picture can show it in a Movie Maker recording.
##
## Plays a click track (a 70 Hz burst every 0.51 s) through the jukebox and flashes two
## squares on the frame the jukebox counts each kick: the left square is stepped from
## `SceneTree.process_frame` (before any node has processed), the right one from a node that
## processes after the autoloads, which is when the game itself reads the jukebox. Comparing
## the flashes with the clicks in the recording's own soundtrack gives the delay of each, to
## the frame. Render it with:
##   godot --path games --fixed-fps 30 --write-movie /abs/probe.avi -s res://tests/probe_lane_smash_sync.gd
const PERIOD := 0.51
const LENGTH := 14.0
var jukebox: Node
var early: ColorRect
var late: ColorRect
var level: ColorRect
var _early_seen := 0
var _late_seen := 0


class Ticker extends Node:
	signal ticked
	func _process(_delta: float) -> void:
		ticked.emit()


func _initialize() -> void:
	_run.call_deferred()


func _clicks() -> AudioStreamWAV:
	var rate := 48000
	var data := PackedByteArray()
	data.resize(int(LENGTH * rate) * 2)
	var next := 1.0
	while next < LENGTH - 1.0:
		var start := int(next * rate)
		for i in int(0.25 * rate):
			var t := float(i) / rate
			var value := sin(TAU * 70.0 * t) * exp(-t / 0.05) * 0.85
			data.encode_s16((start + i) * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
		next += PERIOD
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _square(at: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = at
	rect.size = Vector2(200, 200)
	rect.color = Color.BLACK
	root.add_child(rect)
	return rect


func _run() -> void:
	var options = load("res://framework/GameOptions.gd")
	var path := "user://sync_probe_%d.cfg" % Time.get_ticks_usec()
	options.path = path
	options.reload()
	options.apply_audio()
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.size = Vector2(4000, 4000)
	root.add_child(back)
	early = _square(Vector2(100, 100))
	late = _square(Vector2(500, 100))
	level = _square(Vector2(900, 100))
	jukebox = root.get_node("Jukebox")
	jukebox.autoplay = true
	jukebox.set_playlist([{"id": "clicks", "title": "Clicks", "subtitle": "", "artist": "Probe", "stream": _clicks(), "length_sec": LENGTH}])
	jukebox.select(0, 0.0)
	var ticker := Ticker.new()
	root.add_child(ticker)
	ticker.ticked.connect(_late)
	process_frame.connect(_early)
	for i in int((LENGTH - 1.5) * 30): await process_frame
	print("SYNC PROBE kicks counted=", jukebox.beat_count)
	DirAccess.remove_absolute(path)
	quit()


func _early() -> void:
	early.color = Color.WHITE if jukebox.beat_count != _early_seen else Color.BLACK
	_early_seen = jukebox.beat_count


func _late() -> void:
	late.color = Color.WHITE if jukebox.beat_count != _late_seen else Color.BLACK
	_late_seen = jukebox.beat_count
	# The raw first two bands as a grey level: when the analysis first sees the click at all.
	var bass := maxf(float(jukebox.bands[0]), float(jukebox.bands[1]))
	level.color = Color(bass, bass, bass)
