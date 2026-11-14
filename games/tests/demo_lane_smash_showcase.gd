extends SceneTree
## The Lane Smash showcase: the real selector and settings, then every section type and every
## outcome on the real renderer, HUD, sound effects and soundtrack, with deterministic
## simulated sensors. It never reads or writes personal ride history or settings.
##
## For a video with sound, run it under Movie Maker (frames and audio are captured together,
## independent of how fast this machine renders):
##   godot --path games --fixed-fps 30 --write-movie /abs/demo.avi \
##       -s res://tests/demo_lane_smash_showcase.gd [-- --music-track=0 --music-at=640]
## Movie Maker records at the project's window size (1280x720 here, from the window override
## in project.godot). For 1920x1080, put a temporary `games/override.cfg` beside project.godot
## for the render and delete it afterwards (never commit it):
##   [display]
##   window/size/window_width_override=1920
##   window/size/window_height_override=1080
## Then encode, delaying the soundtrack by one frame (1600 samples at 48 kHz), e.g.
##   ffmpeg -i demo.avi -filter_complex "[0:a]adelay=1600S:all=1[a]" -map 0:v -map "[a]" \
##       -c:v libx264 -crf 19 -pix_fmt yuv420p -c:a aac -b:a 192k demo.mp4
## Why the delay: Movie Maker mixes a frame's audio after that frame's scripts have run, so
## the picture can only show a sound on the next frame. `probe_lane_smash_sync.gd` measures
## it: a kick reaches the picture 5-65 ms after it is heard (median 35 ms at 30 fps); with the
## one-frame delay it is -28 to +32 ms (median 2 ms). The game itself has no such offset.
##
## Sound and picture fade together at every cut (`_cut`, `_fade`): a quick fade out, a beat
## of black and silence while the ride skips ahead, and a quick fade back in.
## Without --write-movie it simply plays in a window in real time.
##
## Between scenes the ride is fast-forwarded through the rules alone (no rendering), so the
## showcase reaches a mine or the second attack without showing minutes of riding.

const COURSE := "ls_15_01"
const FPS := 30.0
const PALETTE_TRACKS := ["ls_15_06", "ls_15_07", "ls_15_11"]

var rules := NeonRules.new()
var track: Node  # autoload-using classes are loaded at run time: a -s script compiles before the autoloads exist
var replay: Node
var hud: Node
var status: Node
var sounds: Node
var audio_controls: Node
var jukebox: Node
var overlay: CanvasLayer
var shade: ColorRect
var caption_box: PanelContainer
var caption_title: Label
var caption_text: Label
var card_title: Label
var card_line: Label
var _rpm := 90.0
var _next_sample := 0
var _duration := 900000
var _last_second := -1
var _held_rpm := 78.0
var _free_rpm := 90.0  ## the cadence the "free" policy rides at outside cadence sections
var _music_bus := -1
var _sfx_bus := -1
var _sfx_base_db := 0.0
var _gain := 1.0
var ticker: Ticker


## Steps the showcase from inside the frame's processing, after the autoloads. The game reads
## the jukebox's analysis in the same frame it is made; `SceneTree.process_frame` fires before
## any node has processed, so stepping from it showed every musical response one frame late.
class Ticker extends Node:
	signal ticked
	func _process(_delta: float) -> void:
		ticked.emit()
var _options_path := ""
var notes: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name): return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	NeonRecords.path = "user://lane_smash_showcase_" + NeonRecords.new_id()
	var options = load("res://framework/GameOptions.gd")
	_options_path = NeonRecords.path + "_options.cfg"
	options.path = _options_path
	options.reload()
	options.apply_audio()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	Engine.max_fps = int(FPS)
	jukebox = root.get_node_or_null("Jukebox")
	ticker = Ticker.new()
	root.add_child(ticker)
	_music_gain(0.0)
	_build_overlay()
	await _selector()
	await _ride()
	await _palettes()
	await _closing()
	print("LANE SMASH SHOWCASE complete scenes=", notes.size(), " notes=", notes)
	DirAccess.remove_absolute(_options_path)
	quit()


# --- Overlay: captions, a fade and title cards, above everything else ---

func _build_overlay() -> void:
	var look := LaneSmashMenuTheme.shared()
	overlay = CanvasLayer.new()
	overlay.layer = 60
	root.add_child(overlay)
	caption_box = PanelContainer.new()
	caption_box.add_theme_stylebox_override("panel", look.panel_style(Color(0.02, 0.035, 0.065, 0.9)))
	caption_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(caption_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	caption_box.add_child(row)
	caption_title = look.caption("", LaneSmashMenuTheme.ACCENT, 34)
	row.add_child(caption_title)
	caption_text = look.label("", 36, LaneSmashMenuTheme.TEXT)
	row.add_child(caption_text)
	caption_box.visible = false
	shade = ColorRect.new()
	shade.color = Color(0.016, 0.026, 0.05, 1.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	root.get_node("Stage").bleed(shade)
	card_title = look.label("", 120, LaneSmashMenuTheme.TEXT)
	card_title.add_theme_font_override("font", look.caps_font())
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title.position = Vector2(0, 400)
	card_title.size = Vector2(1920, 140)
	overlay.add_child(card_title)
	card_line = look.label("", 44, LaneSmashMenuTheme.TEXT_MUTED)
	card_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_line.position = Vector2(0, 560)
	card_line.size = Vector2(1920, 60)
	overlay.add_child(card_line)


## A caption centred on `centre_x`: above the lane dock in the ride, along the bottom of the
## library column in the selector.
func _caption(title: String, text: String, top := 826.0, centre_x := 960.0) -> void:
	caption_title.text = title
	caption_text.text = text
	caption_box.visible = not (title.is_empty() and text.is_empty())
	caption_box.reset_size()
	caption_box.position = Vector2(centre_x - caption_box.get_combined_minimum_size().x * 0.5, top)
	notes.append(title if not title.is_empty() else text)


func _card(title: String, line: String) -> void:
	card_title.text = title
	card_line.text = line
	card_title.visible = not title.is_empty()
	card_line.visible = not line.is_empty()


func _fade(to: float, frames := 9, tick := Callable()) -> void:
	var from := shade.color.a
	for i in frames:
		shade.color.a = lerpf(from, to, (i + 1) / float(frames))
		var cards := clampf(shade.color.a * 2.0 - 1.0, 0.0, 1.0)
		card_title.modulate.a = cards
		card_line.modulate.a = cards
		# The soundtrack dips with the picture: a quick fade out and back in at every cut.
		_music_gain(1.0 - shade.color.a)
		if tick.is_valid(): tick.call()
		await ticker.ticked


func _wait(seconds: float) -> void:
	for i in int(seconds * FPS): await ticker.ticked


## The recording's sound level, 0..1 (squared, so the fade sounds even): the soundtrack, and
## the effects on top of whatever level the game gave them, so a cut never chops the engine
## or a gun mid-note. The jukebox's analyser sits before the music bus's fader, so the
## picture keeps following the music while it is faded down.
func _music_gain(gain: float) -> void:
	if _music_bus < 0: _music_bus = AudioServer.get_bus_index("LaneSmashMusic")
	if _sfx_bus < 0: _sfx_bus = AudioServer.get_bus_index(str(root.get_node("AudioDirector").SFX_BUS))
	var level := clampf(gain, 0.0, 1.0)
	var db := linear_to_db(maxf(level * level, 0.00001))
	if _music_bus >= 0: AudioServer.set_bus_volume_db(_music_bus, db)
	if _sfx_bus >= 0:
		if _gain >= 1.0: _sfx_base_db = AudioServer.get_bus_volume_db(_sfx_bus)
		AudioServer.set_bus_volume_db(_sfx_bus, _sfx_base_db + db)
	_gain = level


# --- Part 1: the real selector and settings ---

func _selector() -> void:
	_card("LANE SMASH", "A resistance-controlled ride for the bike")
	change_scene_to_file("res://hub/Hub.tscn")
	await process_frame
	root.get_node("Session")._local.hub.begin_visit()
	await _wait(1.0)
	if jukebox != null:
		jukebox.autoplay = true
		jukebox.select(int(_arg("music-track", "0")), float(_arg("music-at", "640")))
	await _wait(1.2)
	var setup: Node = current_scene.screen
	setup.length_picker.pick("15")
	setup._pick_track(0)
	await _wait(0.3)
	_caption("TRACK SELECTOR", "25 tracks per duration, each with its own colours and sky", 990.0)
	await _fade(0.0)
	_card("", "")
	await _wait(2.6)
	for i in 70:
		setup.track_scroll.scroll_vertical += 9
		await process_frame
	setup._pick_track(3)
	await _wait(1.3)
	setup._pick_tier("hard")
	await _wait(0.9)
	setup._pick_tier("challenging")
	await _wait(0.9)
	_caption("SETTINGS", "Pick a music track, drag the slider to skip; effects, ghost, motion, graphics", 990.0)
	setup._open_extras()
	await _wait(2.2)
	if jukebox != null: jukebox.seek(jukebox.position_sec() + 95.0)
	await _wait(2.4)
	setup._close_panel()
	setup.track_scroll.scroll_vertical = 0
	setup._pick_track(0)
	_caption("", "")
	_card("THE RIDE", "Every section type and what happens in each")
	await _fade(1.0)
	current_scene.queue_free()
	await process_frame


# --- Part 2: the ride ---

func _build_ride(course_id: String, ghost: bool) -> void:
	var errors := rules.configure(NeonCourse.load_course(course_id), "challenging", 150)
	assert(errors.is_empty())
	_duration = int(rules.course.durationMs)
	_next_sample = 0
	_rpm = 90.0
	_last_second = -1
	if track == null:
		track = load("res://games/neon_vector/NeonTrack.gd").new()
		track.rules = rules
		replay = load("res://games/neon_vector/NeonVector.gd").new()
		replay.rules = rules
		replay.track = track
		root.add_child(track)
		track.apply_quality("high")
		hud = load("res://framework/hud/Hud.gd").new()
		root.add_child(hud)
		var info: RefCounted = load("res://games/Registry.gd").info("neon_vector")
		hud.setup(info, {"duration_sec": _duration / 1000, "effort": false})
		hud.set_process(false)
		hud.timer.set_process(false)
		hud.metrics.set_process(false)
		var skin: Dictionary = load("res://games/neon_vector/NeonVector.gd").hud_skin()
		replay._hud_panel = skin.get("panel")
		hud.set_skin(skin)
		audio_controls = load("res://games/neon_vector/LaneSmashAudioControls.gd").new()
		audio_controls.info = info
		var buttons: Node = hud.end_button.get_parent()
		buttons.add_child(audio_controls)
		buttons.move_child(audio_controls, hud.end_button.get_index())
		status = load("res://games/neon_vector/NeonStatus.gd").new()
		status.rules = rules
		hud.add_widget(status)
		status.set_process(false)
		replay.status = status
		sounds = load("res://games/neon_vector/LaneSmashSound.gd").new()
		sounds.track = track
		track.add_child(sounds)
	track.world_id = rules.course.theme
	track._completion_cursor = 0
	replay._ghost = []
	replay._ghost_cursor = 0
	track.ghost_visible = false
	if ghost:
		var previous := NeonRules.new()
		previous.configure(rules.course, "challenging", 150)
		for t in range(0, _duration, 50):
			var event := previous.current_event()
			var lane := 0 if previous.barrage.active else int(event.get("laneIndex", 0))
			var rpm := 88.0 if event.get("type", "") != "hold" else (float(event.cadenceMin) + float(event.cadenceMax)) * 0.5
			previous.push_sample({"t": t, "seq": t + 1, "cadence": rpm, "power": 170, "resistance": NeonRules.band(lane, "challenging").x + 3})
			previous.advance(t + 50)
		replay._ghost = previous.ghost_trace
	_resync()


func _ride() -> void:
	_build_ride(COURSE, true)
	for i in 70:
		track.update_view(0)
		await ticker.ticked
	track.space._warming = false
	sounds.active = true
	_caption("COLLECT", "Turn the resistance knob to the marked lane and ride over the gold bars")
	await _fade(0.0, 9, _tick)
	_card("", "")
	# 1. Gold bars, then the first cadence section ridden correctly.
	await _play_until(func(): return _in("hold"), 9.0, _policy("follow"))
	_caption("CADENCE", "Hold the rpm range: the machine-gun fire stays ahead of you and behind you")
	await _play_until(func(): return not _in("hold"), 15.0, _policy("follow"))
	_caption("BEST-RIDE GHOST", "Your best ride on this track rides with you; the dock marks the lane to be in")
	await _play(4.0, _policy("follow"))
	_caption("AUDIO", "Change track or drag the slider to skip, without pausing the ride")
	audio_controls.pressed.emit()
	await _play(3.8, _policy("follow"))
	audio_controls.panel.hide()
	_caption("ON THE BEAT", "Every kick sends a pulse down the road; colours follow the bass, mids and treble")
	await _play(6.0, _policy("follow"))
	# 2. The second cadence section ridden too fast.
	await _cut(func(): return _near("hold", 1300), _policy("follow"))
	_caption("TOO FAST", "Above the range the fire ahead reaches you: each round costs 60 points")
	await _play_until(func(): return not _near("hold", 1400), 11.0, _policy("too_fast"))
	# 3. Power burst (it follows that section directly).
	_caption("POWER BURST", "Push in the marked lane: the zone charges with your output, 18 points per 5 joules")
	await _play_until(func(): return _in("burst"), 6.0, _policy("follow"))
	await _play_until(func(): return not _in("burst"), 12.0, _policy("follow"))
	await _play(2.0, _policy("follow"))
	# 4. Incoming Fire: pass the first blast, hang back from the second.
	await _cut(func(): return rules.barrage.active and rules.elapsed_ms >= int(rules.barrage.section.startMs) + 2500, _policy("follow"))
	_caption("INCOMING FIRE", "A blast zone is marked ahead. Pedal faster and get past it: +1,800")
	await _play_until(func(): return _resolved(0), 16.0, _policy("follow"))
	await _play(2.2, _policy("follow"))
	_caption("INCOMING FIRE", "Or ease off and stay behind the blast: safe, but no bonus")
	await _play_until(func(): return _resolved(1), 16.0, _policy("follow"))
	await _play(2.4, _policy("follow"))
	# 5. The next cadence section after the attack, ridden too slowly.
	await _cut(func(): return not rules.barrage.active and _near("hold", 1300), _policy("follow"))
	_caption("TOO SLOW", "Below the range the fire behind catches you")
	await _play_until(func(): return not _near("hold", 1400), 9.0, _policy("too_slow"))
	# 6. The next attack, taken on the chin.
	var second: Dictionary = rules.course.barrages[1]
	await _cut(func(): return rules.elapsed_ms >= int(second.startMs) + 6000 + 4500, _policy("hit"))
	_caption("CAUGHT IN THE BLAST", "Hold the same pace and the shot lands on you: up to −1,800")
	await _play_until(func(): return _resolved(0), 9.0, _policy("hit"))
	await _play(2.6, _policy("hit"))
	# 7. Road mines: one passed, one hit.
	var first_mine := _next_mine()
	if first_mine >= 0:
		await _cut(func(): return rules.road_time_ms() >= int(rules.course.hazards[first_mine].hitMs) - 4200, _policy("follow"))
		_caption("ROAD MINES", "They sit beside the scoring lane. Stay on target and you pass them")
		await _play(6.4, _policy("follow"))
	var second_mine := _next_mine()
	if second_mine >= 0:
		await _cut(func(): return rules.road_time_ms() >= int(rules.course.hazards[second_mine].hitMs) - 3600, _policy("follow"))
		_caption("ROAD MINES", "Drift into one and it costs up to 1,800 points")
		await _play_until(func(): return bool(rules.hazard_states[second_mine].resolved), 7.0, _policy("mine"))
		await _play(2.6, _policy("follow"))
	# 8. Speed: a clear stretch of road, ridden slowly and then flat out.
	await _cut(func(): return _open_road(10500), _policy("follow"))
	_caption("SPEED", "The road moves with your legs. Ease right off and it slows to a cruise…")
	_free_rpm = 52.0
	await _play(4.6, _policy("free"))
	_caption("SPEED", "…spin up and it flies: 96 rpm is about 77 mph on screen, flat out is 112")
	_free_rpm = 134.0
	await _play(7.0, _policy("free"))
	# 9. The roller coaster.
	var loop_at := _next_inversion()
	if loop_at > 0.0:
		await _cut(func(): return rules.road_distance() >= loop_at - 95.0, _policy("follow"))
		_caption("THE ROAD", "A fixed roller coaster through space: loops, rolls and banked turns")
		await _play(11.0, _policy("follow"))
	_caption("", "")
	await _fade(1.0, 9, _tick)
	sounds.suspend()


func _palettes() -> void:
	for id: String in PALETTE_TRACKS:
		_build_ride(id, false)
		_skip(func(): return rules.elapsed_ms >= 4000, _policy("follow"))
		var palette := NeonWorlds.world(str(rules.course.theme))
		sounds.active = true
		_caption(str(rules.course.title).to_upper(), "%s palette · %s sky" % [palette.title, LaneSmashEnvironment.TITLES.get(rules.course.background, "")])
		await _fade(0.0, 7, _tick)
		await _play(5.2, _policy("follow"))
		await _fade(1.0, 7, _tick)
		sounds.suspend()


func _closing() -> void:
	_caption("", "")
	_card("LANE SMASH", "A faster road · pulses on the beat · colour from the music · tracks tuned as a workout")
	# The music comes back under the closing card and fades out with it.
	for i in 12:
		_music_gain((i + 1) / 12.0)
		await ticker.ticked
	await _wait(2.4)
	for i in 27:
		_music_gain(1.0 - (i + 1) / 27.0)
		await ticker.ticked
	await _wait(0.2)


# --- Ride plumbing ---

func _in(kind: String) -> bool:
	var event := rules.current_event()
	return not rules.barrage.active and event.get("type", "") == kind and rules.road_time_ms() >= int(event.get("startMs", 0))


func _near(kind: String, lead_ms: int) -> bool:
	var event := rules.current_event()
	return not rules.barrage.active and event.get("type", "") == kind and rules.road_time_ms() >= int(event.get("startMs", 0)) - lead_ms


## True once more than `ordinal` shots of the current attack have landed (or it is over).
func _resolved(ordinal: int) -> bool:
	if not rules.barrage.active: return true
	var count := 0
	for shot: Dictionary in rules.barrage.shots:
		if shot.sectionId == rules.barrage.section.barrageId and bool(shot.resolved): count += 1
	return count > ordinal


## True on a stretch of plain road: collect bars now, and no cadence section, power burst or
## attack for the next `room_ms` of road, so the rider is free to ride at any cadence.
func _open_road(room_ms: int) -> bool:
	if rules.barrage.active: return false
	var now := rules.road_time_ms()
	var event := rules.current_event()
	if event.get("type", "") != "cruise" or now < int(event.get("startMs", 0)): return false
	for upcoming: Dictionary in rules.course.events:
		if int(upcoming.endMs) <= now: continue
		if int(upcoming.startMs) - now >= room_ms: break
		if upcoming.type in ["hold", "burst"]: return false
	for section: Dictionary in rules.course.barrages:
		var lead := int(section.startMs) - rules.elapsed_ms
		if lead > -45000 and lead < 20000: return false
	return true


## The next road mine that is not swallowed by an attack and is still ahead.
func _next_mine() -> int:
	for i in rules.course.hazards.size():
		var hazard: Dictionary = rules.course.hazards[i]
		if int(hazard.hitMs) < rules.road_time_ms() + 9000 or bool(rules.hazard_states[i].resolved): continue
		return i
	return -1


func _next_inversion() -> float:
	var s := rules.road_distance() + 140.0
	while s < float(rules.course.roadLengthMeters) - 200.0:
		if track.space.coaster.at(s).basis.y.y < -0.6: return s
		s += 6.0
	return -1.0


## What the simulated rider does. `mode` only changes the part of the ride a scene is about.
func _policy(mode: String) -> Callable:
	return func() -> Dictionary:
		var event := rules.current_event()
		var lane := int(event.get("laneIndex", 0))
		var kind := str(event.get("type", ""))
		var rpm := _free_rpm if mode == "free" else 94.0
		if kind == "hold":
			rpm = (float(event.cadenceMin) + float(event.cadenceMax)) * 0.5
			if rules.road_time_ms() >= int(event.startMs) - 400:
				if mode == "too_fast": rpm = float(event.cadenceMax) + 17.0
				elif mode == "too_slow": rpm = float(event.cadenceMin) - 19.0
		elif kind == "burst" and rules.road_time_ms() >= int(event.startMs) - 800:
			rpm = 126.0
		if rules.barrage.active:
			lane = 0
			rpm = _held_rpm
			var shot := rules.barrage.current_shot()
			if not shot.is_empty() and not bool(shot.resolved):
				var blend := clampf((rules.elapsed_ms - int(shot.lockMs) - 1500) / 4000.0, 0.0, 1.0)
				rpm = float(shot.baselineRpm) if mode == "hit" else lerpf(float(shot.baselineRpm), float(shot.targetRpm), blend)
				if mode != "hit" and blend >= 1.0: _held_rpm = float(shot.targetRpm)
		else:
			_held_rpm = 78.0
			if mode == "mine":
				for hazard: Dictionary in rules.course.hazards:
					if rules.road_time_ms() >= int(hazard.hitMs) - 2600 and rules.road_time_ms() <= int(hazard.hitMs) + 300: lane = int(hazard.laneIndex)
		# The speed scene changes cadence the way legs do, not in a step.
		return {"lane": lane, "rpm": rpm, "step": 1.1 if mode == "free" else 4.0}


func _push(policy: Callable) -> void:
	var input: Dictionary = policy.call()
	_rpm = move_toward(_rpm, float(input.rpm), float(input.get("step", 4.0)))
	var resistance := NeonRules.band(int(input.lane), rules.tier).x + 3
	rules.push_sample({"t": _next_sample, "seq": _next_sample + 1, "cadence": roundf(_rpm), "power": roundi(_rpm * (0.3 + resistance * 0.045)), "resistance": resistance})
	_next_sample += 50


## Advances the ride through the rules alone until `until` holds. Nothing is drawn or heard.
func _skip(until: Callable, policy: Callable) -> void:
	sounds.suspend()
	var guard := 0
	while not until.call() and rules.elapsed_ms < _duration - 2000 and guard < 40000:
		_push(policy)
		rules.advance(_next_sample)
		guard += 1
	_resync()


## A cut: picture and sound fade out together, the ride skips ahead under a beat of black
## and silence, and both fade back in on the new moment.
func _cut(until: Callable, policy: Callable) -> void:
	await _fade(1.0, 9, _tick)
	_skip(until, policy)
	for i in 4:
		_tick()
		await ticker.ticked
	sounds.active = true
	await _fade(0.0, 9, _tick)


## After a skip, the presentation forgets everything that happened off screen.
func _resync() -> void:
	if track == null: return
	var space: NeonSpace = track.space
	track._completion_cursor = rules._event_cursor
	track._completion_age = 10.0
	track.visual_lane = float(maxi(0, rules.selected_lane))
	space.bombs.feedback_cursor = rules._hazard_cursor
	space.gunfire_view._hits_seen = rules.gun_hits
	space.gunfire_view._feedback.clear()
	space.gunfire_view._tracers.clear()
	space.gunfire_view._presence = 0.0
	space.barrage_view._feedback = {}
	space.fx.clear()
	space._impacts.clear()
	space._shockwaves.clear()
	space._trail_points.clear()
	space._collected.clear()
	replay._ghost_cursor = 0
	_last_second = -1
	track.update_view(0)
	status.refresh()


func _tick() -> void:
	track.update_view(0)


func _play(seconds: float, policy: Callable) -> void:
	await _play_until(func(): return false, seconds, policy)


func _play_until(until: Callable, max_seconds: float, policy: Callable) -> void:
	var start := rules.elapsed_ms
	for frame in int(max_seconds * FPS):
		if until.call() or rules.elapsed_ms >= _duration - 2000: break
		var target := start + floori((frame + 1) * 1000.0 / FPS / 10) * 10
		while _next_sample < target: _push(policy)
		rules.advance(target)
		_frame(1.0 / FPS)
		await ticker.ticked


func _frame(delta: float) -> void:
	replay._update_ghost()
	track.update_view(delta)
	replay._pulse_hud()
	status.refresh()
	status._process(delta)
	sounds.update_audio()
	root.get_node("Effort")._meter.score = float(rules.score_units) / NeonRules.UNIT
	hud._process(delta)
	if rules.elapsed_ms / 1000 != _last_second:
		_last_second = rules.elapsed_ms / 1000
		var left := maxi(0, _duration / 1000 - _last_second)
		hud.timer.set_value("%d:%02d" % [left / 60, left % 60])
		for pair in [[hud.metrics._rpm, "cadence"], [hud.metrics._watts, "power"], [hud.metrics._resistance, "resistance"]]:
			pair[0].text = str(roundi(float(rules.latest.get(pair[1], 0))))
