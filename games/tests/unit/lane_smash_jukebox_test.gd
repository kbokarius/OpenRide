extends GdUnitTestSuite
## The Lane Smash jukebox, its music panel and the in-ride audio menu, on a tiny generated
## playlist. Headless runs never start or load the real tracks by themselves.

const LENGTH := 200.0

var _path := ""
var _prefs := {}
var _kick := false


func before_test() -> void:
	_path = GameOptions.path
	GameOptions.path = "user://jukebox_test_" + NeonRecords.new_id() + ".cfg"
	GameOptions.reload()
	_prefs = {"music": AudioDirector.user_music_enabled, "sfx": AudioDirector.user_sfx_enabled}
	AudioDirector.set_volumes(true, 0.65, 0.7)
	AudioDirector.set_user_audio(true, true)
	_kick = false
	Jukebox.autoplay = false
	Jukebox.frozen = false
	Jukebox.spectrum_source = Callable()
	Jukebox.seed_random(7)
	Jukebox.set_playlist(_tiny(3))


func after_test() -> void:
	Jukebox.spectrum_source = Callable()
	Jukebox.frozen = false
	Jukebox.autoplay = false
	Jukebox.rescan()
	AudioDirector.set_user_audio(_prefs.music, _prefs.sfx)
	if FileAccess.file_exists(GameOptions.path): DirAccess.remove_absolute(GameOptions.path)
	GameOptions.path = _path
	GameOptions.reload()


func _tiny(count: int) -> Array:
	var list: Array = []
	for i in count:
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_8_BITS
		wav.mix_rate = 8000
		wav.stereo = false
		var data := PackedByteArray()
		data.resize(int(LENGTH * 8000))
		wav.data = data
		list.append({"id": "tiny_%d" % i, "title": "Tiny %d" % (i + 1), "subtitle": "", "artist": "Test", "stream": wav, "length_sec": LENGTH})
	return list


func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func _until_playing() -> void:
	for i in 120:
		if Jukebox.is_playing(): return
		await get_tree().process_frame


func test_nothing_starts_or_loads_by_itself_in_a_headless_run() -> void:
	Jukebox.rescan()
	assert_bool(Jukebox.tracks().is_empty()).is_false()
	assert_int(Jukebox.current).is_equal(-1)
	assert_bool(Jukebox.owns_music()).is_false()
	Jukebox.ensure_started()
	await _frames(3)
	assert_bool(Jukebox.is_started()).is_false()
	assert_bool(Jukebox.is_loading()).is_false()
	assert_bool(Jukebox.is_playing()).is_false()
	assert_str(Jukebox.title()).is_equal("")


func test_random_start_lands_inside_the_track_with_an_end_margin() -> void:
	var seen_tracks := {}
	var seen_positions := {}
	for value in 60:
		Jukebox.seed_random(value + 1)
		Jukebox.start_random()
		assert_int(Jukebox.current).is_between(0, 2)
		var at := Jukebox.position_sec()
		assert_float(at).is_between(0.0, LENGTH - Jukebox.END_MARGIN_SEC)
		seen_tracks[Jukebox.current] = true
		seen_positions[roundi(at)] = true
	assert_int(seen_tracks.size()).is_equal(3)
	assert_int(seen_positions.size()).is_greater(20)
	# The real mixes keep the same margin against their own lengths.
	for track: Dictionary in Jukebox.PERSONAL: assert_float(float(track.length_sec)).is_greater(Jukebox.END_MARGIN_SEC * 10)


func test_a_finished_track_hands_over_to_a_different_one_from_its_start() -> void:
	var changes: Array = []
	var listener := func(index: int): changes.append(index)
	Jukebox.track_changed.connect(listener)
	Jukebox.select(1, 150.0)
	await _until_playing()
	for i in 12:
		var before := Jukebox.current
		Jukebox._player.finished.emit()
		assert_int(Jukebox.current).is_not_equal(before)
		assert_float(Jukebox.position_sec()).is_less(1.0)
		await _until_playing()
		assert_bool(Jukebox.is_playing()).is_true()
	assert_int(changes.size()).is_equal(13)
	# With nothing else to choose, the same track starts over.
	Jukebox.set_playlist(_tiny(1))
	Jukebox.select(0, 120.0)
	await _until_playing()
	Jukebox._player.finished.emit()
	assert_int(Jukebox.current).is_equal(0)
	assert_float(Jukebox.position_sec()).is_less(1.0)
	Jukebox.track_changed.disconnect(listener)


func test_select_and_seek_are_clamped_and_a_seek_never_changes_track() -> void:
	Jukebox.select(-1)
	Jukebox.select(99)
	assert_int(Jukebox.current).is_equal(-1)
	Jukebox.select(2, 99999.0)
	assert_int(Jukebox.current).is_equal(2)
	assert_float(Jukebox.position_sec()).is_equal_approx(LENGTH - 1.0, 0.01)
	Jukebox.seek(-30.0)
	assert_float(Jukebox.position_sec()).is_equal_approx(0.0, 0.01)
	await _until_playing()
	Jukebox.seek(77.0)
	await _frames(4)
	assert_int(Jukebox.current).is_equal(2)
	assert_bool(Jukebox.is_playing()).is_true()
	assert_float(Jukebox.position_sec()).is_between(77.0, 78.5)
	Jukebox.seek(1.0e7)
	assert_float(Jukebox.position_sec()).is_between(LENGTH - 1.0, LENGTH)
	assert_int(Jukebox.current).is_equal(2)
	assert_float(Jukebox.length_sec()).is_equal_approx(LENGTH, 0.5)


func test_only_night_drive_plays_when_no_personal_track_is_present() -> void:
	Jukebox.rescan([{"id": "absent", "title": "Absent", "path": "res://games/neon_vector/audio/tracks/not_there.ogg", "length_sec": 100.0}])
	assert_int(Jukebox.tracks().size()).is_equal(1)
	assert_str(str(Jukebox.tracks()[0].id)).is_equal("night_drive")
	assert_bool(Jukebox.has_personal_tracks()).is_false()
	# The fallback is read off the main thread like any other track, then loops by itself.
	Jukebox.select(0, 5.0)
	assert_str(Jukebox.title()).is_equal("Night Drive")
	for i in 600:
		if Jukebox.is_playing(): break
		await get_tree().process_frame
	assert_bool(Jukebox.is_playing()).is_true()
	assert_bool(Jukebox._player.stream is AudioStreamOggVorbis).is_true()
	assert_float(Jukebox.length_sec()).is_between(100.0, 140.0)
	Jukebox._player.finished.emit()
	assert_int(Jukebox.current).is_equal(0)


func test_only_the_current_track_stays_in_memory() -> void:
	Jukebox.select(0, 10.0)
	await _until_playing()
	var first: AudioStream = Jukebox._player.stream
	assert_object(first).is_same(Jukebox.tracks()[0].stream)
	Jukebox.select(1, 0.0)
	assert_object(Jukebox._player.stream).is_null()
	await _until_playing()
	assert_object(Jukebox._player.stream).is_same(Jukebox.tracks()[1].stream)


func test_music_off_holds_the_position_and_on_resumes_there() -> void:
	var info := GameRegistry.info("neon_vector")
	Jukebox.select(0, 42.0)
	await _until_playing()
	assert_bool(Jukebox.is_playing()).is_true()
	assert_bool(GameOptions.set_value(info, "music", "off")).is_true()
	await _frames(3)
	assert_bool(Jukebox.is_playing()).is_false()
	assert_bool(Jukebox._player.playing).is_false()
	var held := Jukebox.position_sec()
	assert_float(held).is_between(42.0, 43.5)
	await get_tree().create_timer(0.3).timeout
	assert_float(Jukebox.position_sec()).is_equal(held)
	# Seeking while off moves the held position; nothing plays.
	Jukebox.seek(90.0)
	assert_bool(Jukebox.is_playing()).is_false()
	assert_float(Jukebox.position_sec()).is_equal(90.0)
	Jukebox.seek(held)
	assert_bool(GameOptions.set_value(info, "music", "on")).is_true()
	await _frames(3)
	assert_bool(Jukebox.is_playing()).is_true()
	assert_float(Jukebox.position_sec()).is_between(held, held + 1.0)
	# The rider's own music app and a host mute hold it the same way.
	AudioDirector.music_enabled = false
	await _frames(3)
	assert_bool(Jukebox.is_playing()).is_false()
	AudioDirector.music_enabled = true
	await _frames(3)
	assert_bool(Jukebox.is_playing()).is_true()


func test_the_player_feeds_the_music_bus_through_its_own_analysed_bus() -> void:
	var index := AudioServer.get_bus_index(Jukebox.BUS)
	assert_int(index).is_greater(0)
	assert_str(str(AudioServer.get_bus_send(index))).is_equal(AudioDirector.MUSIC_BUS)
	assert_str(str(Jukebox._player.bus)).is_equal(Jukebox.BUS)
	# A new segment clears the Music bus's effects; the analyser is not on that bus.
	AudioDirector.begin_segment({"audio": {"music": true}})
	var analysers := 0
	for i in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, i) is AudioEffectSpectrumAnalyzer: analysers += 1
	assert_int(analysers).is_equal(1)


func _spectrum(_from_hz: float, to_hz: float) -> float:
	if to_hz <= 130.0: return 0.2 if _kick else 0.004
	return 0.02


func test_analysis_follows_the_music_and_falls_to_zero_when_it_stops() -> void:
	Jukebox.spectrum_source = _spectrum
	Jukebox.select(0, 20.0)
	await _until_playing()
	await get_tree().create_timer(0.5).timeout
	assert_float(Jukebox.mid).is_greater(0.3)
	assert_float(Jukebox.treble).is_greater(0.3)
	assert_float(Jukebox.level).is_between(0.05, 1.0)
	assert_int(Jukebox.bands.size()).is_equal(8)
	var count := Jukebox.beat_count
	var flow := Jukebox.flow
	for i in 4:
		_kick = true
		await get_tree().create_timer(0.08).timeout
		assert_float(Jukebox.bass).is_greater(0.5)
		_kick = false
		await get_tree().create_timer(0.3).timeout
		assert_float(Jukebox.bass).is_less(0.3)
	assert_int(Jukebox.beat_count - count).is_equal(4)
	assert_float(Jukebox.beat).is_between(0.0, 1.0)
	assert_float(Jukebox.flow).is_greater(flow)
	flow = Jukebox.flow
	AudioDirector.set_user_audio(false, true)
	await get_tree().create_timer(0.8).timeout
	for value in [Jukebox.level, Jukebox.bass, Jukebox.mid, Jukebox.treble, Jukebox.beat]:
		assert_float(value).is_equal(0.0)
	for value in Jukebox.bands: assert_float(value).is_equal(0.0)
	# The music-driven phase stops with the music and never runs backwards.
	assert_float(Jukebox.flow).is_greater_equal(flow)
	var resting := Jukebox.flow
	await get_tree().create_timer(0.2).timeout
	assert_float(Jukebox.flow).is_equal(resting)


func test_calm_values_swell_and_settle_instead_of_jumping() -> void:
	# What the scenery reads: a kick may move the fast values by most of their range in one
	# frame, but the calm ones never move more than a small step per frame.
	Jukebox.frozen = true
	for value in ["bass", "mid", "treble", "level", "beat", "calm_bass", "calm_mid", "calm_treble", "calm_level", "pulse"]: Jukebox.set(value, 0.0)
	var largest_step := 0.0
	var previous := 0.0
	var peak := 0.0
	for frame in 90:
		var kick := frame % 15 == 0  # a 120 BPM kick at 30 fps
		Jukebox.bass = 0.95 if kick else maxf(0.25, Jukebox.bass - 0.12)
		Jukebox.beat = 1.0 if kick else Jukebox.beat * 0.75
		Jukebox._ease_calm(1.0 / 30.0)
		largest_step = maxf(largest_step, maxf(absf(Jukebox.calm_bass - previous), 0.0))
		previous = Jukebox.calm_bass
		peak = maxf(peak, Jukebox.pulse)
	assert_float(largest_step).is_less(0.09)
	assert_float(Jukebox.calm_bass).is_between(0.3, 0.75)  # it follows the music's level
	assert_float(peak).is_between(0.1, Jukebox.PULSE_DEPTH)  # a kick is a soft swell, never a flash
	for value in ["bass", "beat", "calm_bass", "calm_mid", "calm_treble", "calm_level", "pulse"]: Jukebox.set(value, 0.0)


func test_frozen_analysis_keeps_values_set_by_a_capture() -> void:
	Jukebox.frozen = true
	Jukebox.bass = 0.8
	Jukebox.beat = 1.0
	await _frames(5)
	assert_float(Jukebox.bass).is_equal(0.8)
	assert_float(Jukebox.beat).is_equal(1.0)
	Jukebox.bass = 0.0
	Jukebox.beat = 0.0


func test_music_panel_picks_tracks_and_seeks_once_on_release() -> void:
	var panel: LaneSmashMusicPanel = auto_free(LaneSmashMusicPanel.new(LaneSmashMenuTheme.new(), 780))
	add_child(panel)
	Jukebox.select(0, 10.0)
	await _until_playing()
	await _frames(3)
	assert_int(panel.track_buttons.size()).is_equal(3)
	assert_bool(panel.track_row.visible).is_true()
	assert_str(panel.title_label.text).is_equal("Tiny 1")
	assert_str(panel.time_label.text).is_equal("0:10 / 3:20")
	for button in panel.track_buttons:
		assert_float(button.size.y).is_greater_equal(72.0)
		assert_int(button.get_theme_font_size("font_size")).is_greater_equal(30)
	assert_float(panel.seek.size.y).is_greater_equal(72.0)
	assert_float(panel.size.x).is_less_equal(780.5)
	panel.track_buttons[2].pressed.emit()
	assert_int(Jukebox.current).is_equal(2)
	assert_float(Jukebox.position_sec()).is_less(1.0)
	await _until_playing()
	await _frames(2)
	assert_str(panel.title_label.text).is_equal("Tiny 3")
	# A drag previews the time without touching playback; the release seeks once.
	var seeks: Array = []
	var listener := func(): seeks.append(Jukebox.position_sec())
	var width: float = panel.seek.size.x
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(width * 0.25, 30)
	panel.seek._gui_input(press)
	Jukebox.playback_changed.connect(listener)
	for step in 20:
		var move := InputEventMouseMotion.new()
		move.position = Vector2(width * (0.25 + step * 0.0125), 30)
		panel.seek._gui_input(move)
	assert_bool(panel.seek.dragging).is_true()
	assert_int(seeks.size()).is_equal(0)
	assert_float(Jukebox.position_sec()).is_less(2.0)
	assert_str(panel.time_label.text).is_not_equal("0:00 / 3:20")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(width * 0.5, 30)
	panel.seek._gui_input(release)
	Jukebox.playback_changed.disconnect(listener)
	assert_int(seeks.size()).is_equal(1)
	assert_float(Jukebox.position_sec()).is_between(LENGTH * 0.5 - 4.0, LENGTH * 0.5 + 4.0)
	assert_int(Jukebox.current).is_equal(2)


func test_music_panel_is_disabled_while_music_is_off_and_hides_a_lone_track() -> void:
	var panel: LaneSmashMusicPanel = auto_free(LaneSmashMusicPanel.new(LaneSmashMenuTheme.new(), 780))
	add_child(panel)
	Jukebox.select(1, 30.0)
	await _until_playing()
	await _frames(3)
	assert_bool(panel.seek.disabled).is_false()
	var heights: Array[float] = []
	for button in panel.track_buttons: heights.append(button.size.y)
	var panel_height := panel.size.y
	AudioDirector.set_user_audio(false, true)
	await _frames(3)
	assert_bool(panel.seek.disabled).is_true()
	assert_str(panel.detail_label.text).is_equal("Music is off")
	for button in panel.track_buttons: assert_bool(button.disabled).is_true()
	# Restyling for the new state never re-flows the row: every button keeps its height.
	for i in panel.track_buttons.size(): assert_float(panel.track_buttons[i].size.y).is_equal(heights[i])
	assert_float(panel.size.y).is_equal(panel_height)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(300, 30)
	panel.seek._gui_input(press)
	assert_bool(panel.seek.dragging).is_false()
	AudioDirector.set_user_audio(true, true)
	await _frames(3)
	assert_bool(panel.seek.disabled).is_false()
	assert_str(panel.detail_label.text).is_equal("Test")
	Jukebox.set_playlist(_tiny(1))
	Jukebox.select(0)
	await _frames(3)
	assert_bool(panel.track_row.visible).is_false()
	assert_int(panel.track_buttons.size()).is_equal(0)


func test_clock_reads_minutes_then_hours() -> void:
	assert_str(LaneSmashMusicPanel.clock(0)).is_equal("0:00")
	assert_str(LaneSmashMusicPanel.clock(724.9)).is_equal("12:04")
	assert_str(LaneSmashMusicPanel.clock(1850.5)).is_equal("30:50")
	assert_str(LaneSmashMusicPanel.clock(3723)).is_equal("1:02:03")
	assert_str(LaneSmashMusicPanel.clock(4935.4)).is_equal("1:22:15")


func test_ride_audio_menu_keeps_both_switches_and_fits_below_its_button() -> void:
	var controls: LaneSmashAudioControls = auto_free(LaneSmashAudioControls.new())
	controls.info = GameRegistry.info("neon_vector")
	add_child(controls)
	controls.position = Vector2(1500, 250)
	Jukebox.select(0, 10.0)
	await _until_playing()
	controls.pressed.emit()
	await _frames(4)
	assert_bool(controls.panel.visible).is_true()
	assert_bool(controls.rows.has("music") and controls.rows.has("sfx")).is_true()
	assert_object(controls.music_panel).is_not_null()
	assert_int(controls.music_panel.track_buttons.size()).is_equal(3)
	# Right-aligned to the HUD margin, and short enough to clear the lane dock (about y 900).
	var rect: Rect2 = controls.panel.get_global_rect()
	assert_float(rect.end.x).is_equal_approx(1920.0 - HudTheme.MARGIN, 1.0)
	assert_float(rect.position.x).is_greater_equal(0.0)
	assert_float(rect.size.y).is_less_equal(520.0)
	assert_float(rect.end.y).is_less_equal(890.0)
	for key in ["music", "sfx"]:
		for button: Button in controls.rows[key].segmented.buttons: assert_float(button.size.y).is_greater_equal(72.0)
	controls.rows.music.segmented.pick("off")
	await _frames(3)
	assert_bool(AudioDirector.user_music_enabled).is_false()
	assert_bool(Jukebox.is_playing()).is_false()
	assert_bool(controls.music_panel.seek.disabled).is_true()
	controls.rows.music.segmented.pick("on")
	await _frames(3)
	assert_bool(Jukebox.is_playing()).is_true()
	controls._close()
	assert_bool(controls.panel.visible).is_false()


func test_the_soundtrack_fades_instead_of_cutting_on_every_start_stop_and_change() -> void:
	var info := GameRegistry.info("neon_vector")
	# A start comes up from silence.
	Jukebox.select(0, 30.0)
	await _until_playing()
	assert_float(Jukebox._gain).is_less(0.5)
	assert_float(Jukebox._player.volume_db).is_less(-12.0)
	await get_tree().create_timer(Jukebox.FADE_IN_SEC + 0.3).timeout
	assert_float(Jukebox._gain).is_equal(1.0)
	assert_float(Jukebox._player.volume_db).is_equal_approx(0.0, 0.01)
	# A seek: the old position carries on, fading, on the other deck while the new one comes in.
	var deck := Jukebox._player
	Jukebox.seek(90.0)
	assert_object(Jukebox._tail).is_same(deck)
	assert_bool(Jukebox._tail.playing).is_true()
	assert_float(Jukebox._tail_gain).is_equal(1.0)
	assert_float(Jukebox._gain).is_equal(0.0)
	assert_bool(Jukebox.is_playing()).is_true()
	await _frames(4)
	assert_float(Jukebox._tail_gain).is_between(0.5, 0.999)
	assert_float(Jukebox._gain).is_between(0.001, 0.5)
	await get_tree().create_timer(Jukebox.FADE_IN_SEC + 0.3).timeout
	# The old sound has stopped and let go of its track; the new one is at full level.
	assert_bool(Jukebox._tail.playing).is_false()
	assert_object(Jukebox._tail.stream).is_null()
	assert_float(Jukebox._gain).is_equal(1.0)
	# Changing track: the old track fades out while the new one is fetched and started.
	deck = Jukebox._player
	Jukebox.select(1, 0.0)
	assert_object(Jukebox._tail).is_same(deck)
	assert_bool(Jukebox._tail.playing).is_true()
	await _until_playing()
	assert_float(Jukebox._gain).is_less(0.5)
	await get_tree().create_timer(Jukebox.FADE_IN_SEC + 0.3).timeout
	assert_bool(Jukebox._tail.playing).is_false()
	# Music Off: reported as stopped at once (the position is held), but heard fading out.
	assert_bool(GameOptions.set_value(info, "music", "off")).is_true()
	await _frames(2)
	assert_bool(Jukebox.is_playing()).is_false()
	assert_bool(Jukebox._player.playing).is_false()
	assert_bool(Jukebox._tail.playing).is_true()
	assert_float(Jukebox._tail_gain).is_between(0.5, 0.999)
	await get_tree().create_timer(Jukebox.FADE_OUT_SEC + 0.3).timeout
	assert_bool(Jukebox._tail.playing).is_false()
	# And On again fades back in from where it was held.
	assert_bool(GameOptions.set_value(info, "music", "on")).is_true()
	await _until_playing()
	assert_float(Jukebox._gain).is_less(0.5)

