extends GdUnitTestSuite
var _path := ""
var _prefs := {}

func before_test() -> void:
	_path = GameOptions.path
	_prefs = {"music": AudioDirector.user_music_enabled, "sfx": AudioDirector.user_sfx_enabled}
	GameOptions.path = "user://audio_test_" + NeonRecords.new_id() + ".cfg"
	GameOptions.reload()
	GameOptions.apply_audio()

func after_test() -> void:
	DirAccess.remove_absolute(GameOptions.path)
	GameOptions.path = _path
	GameOptions.reload()
	AudioDirector.set_user_audio(_prefs.music, _prefs.sfx)

func test_audio_choices_are_shared_across_menu_ride_rider_and_restart() -> void:
	var info := GameRegistry.info("neon_vector")
	assert_bool(GameOptions.set_value(info, "music", "off", "menu-rider")).is_true()
	assert_bool(GameOptions.set_value(info, "sfx", "off", "ride-rider")).is_true()
	GameOptions.reload()
	assert_str(GameOptions.get_value(info, "music", "any-rider")).is_equal("off")
	assert_str(GameOptions.get_value(info, "sfx", "any-rider")).is_equal("off")
	assert_bool(GameOptions.set_value(info, "music", "on", "ride-rider")).is_true()
	assert_str(GameOptions.get_value(info, "music", "menu-rider")).is_equal("on")
	assert_str(GameOptions.get_value(info, "sfx", "menu-rider")).is_equal("off")

func test_old_music_choice_migrates_once_without_resetting_other_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("9/neon_vector", "music", "off")
	c.set_value("9/neon_vector", "ghost", "off")
	c.save(GameOptions.path)
	GameOptions.reload()
	var info := GameRegistry.info("neon_vector")
	assert_str(GameOptions.get_value(info, "music", "9")).is_equal("off")
	assert_str(GameOptions.get_value(info, "music", "10")).is_equal("off")
	assert_str(GameOptions.get_value(info, "ghost", "9")).is_equal("off")
	assert_str(GameOptions.get_value(info, "ghost", "10")).is_equal("on")

func test_switches_are_independent_and_host_refresh_does_not_unmute() -> void:
	var info := GameRegistry.info("neon_vector")
	GameOptions.set_value(info, "music", "off")
	GameOptions.set_value(info, "sfx", "off")
	AudioDirector.begin_segment({"audio": {"music": true, "sfx_volume": 1.0}})
	AudioDirector.set_volumes(true, 1, 1)
	for bus in ["Music", "SFX", "Cues"]:
		assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))).is_true()
	assert_bool(AudioDirector.play_cue("go")).is_false()
	assert_bool(AudioDirector.play_sfx("whoosh")).is_false()
	GameOptions.set_value(info, "music", "on")
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))).is_false()
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX"))).is_true()
	GameOptions.set_value(info, "sfx", "on")
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index("Cues"))).is_false()

func test_every_repeated_target_emits_sound_without_a_cooldown() -> void:
	var track := NeonTrack.new()
	track.rules = NeonRules.new()
	track.rules.configure(NeonCourse.load_course("ls_10_01"), "challenging", 150)
	add_child(track)
	var sounds := LaneSmashSound.new()
	sounds.track = track
	add_child(sounds)
	sounds.active = true
	var played: Array = []
	var listener := func(sound: String, _bus: String): played.append(sound)
	AudioDirector.sound_played.connect(listener)
	for i in 20: track.space.target_hit.emit("hold")
	assert_int(played.size()).is_equal(20)
	for sound: String in played: assert_str(sound).is_equal("lane_smash_cadence")
	GameOptions.set_value(GameRegistry.info("neon_vector"), "sfx", "off")
	track.space.target_hit.emit("hold")
	assert_int(played.size()).is_equal(20)
	GameOptions.set_value(GameRegistry.info("neon_vector"), "sfx", "on")
	track.space.target_hit.emit("hold")
	assert_int(played.size()).is_equal(21)
	AudioDirector.sound_played.disconnect(listener)
	sounds.free()
	track.free()

func test_recorded_cues_are_short_and_bounded() -> void:
	for sound: AudioStream in LaneSmashSound.FILES.values():
		assert_float(sound.get_length()).is_greater(0.07)
		assert_float(sound.get_length()).is_less(0.6)
	for key in ["collect", "cadence", "section", "power_finish", "warning", "launch", "impact", "bomb", "pass", "avoid", "lane", "gun_hit", "ui_tap", "ui_confirm"]:
		assert_bool(LaneSmashSound.FILES.has(key)).override_failure_message("Missing cue: " + key).is_true()


func test_beds_are_whole_loops_and_the_weapon_charge_fits_its_window() -> void:
	assert_array(LaneSmashSound.LOOPS.keys()).contains_exactly(["power", "engine", "gun"])
	assert_float(LaneSmashSound.LOOPS.power.get_length()).is_equal_approx(1.0, 0.001)
	assert_float(LaneSmashSound.LOOPS.engine.get_length()).is_equal_approx(2.0, 0.001)
	assert_float(LaneSmashSound.LOOPS.gun.get_length()).is_between(0.5, 1.0)
	assert_float(LaneSmashSound.FILES.gun_hit.get_length()).is_less_equal(0.3)
	# Lock to launch is LaneSmashBarrage.CHARGE_MS; the charge must end before the launch cue.
	assert_float(LaneSmashSound.WEAPON_CHARGE.get_length()).is_between(1.5, LaneSmashBarrage.CHARGE_MS / 1000.0)
	for stream: AudioStreamWAV in LaneSmashSound.LOOPS.values() + [LaneSmashSound.WEAPON_CHARGE] + LaneSmashSound.FILES.values():
		assert_int(stream.mix_rate).is_equal(44100)
		assert_bool(stream.stereo).is_false()
		assert_int(stream.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)


func _rig() -> Array:
	var track := NeonTrack.new()
	track.rules = NeonRules.new()
	track.rules.configure(NeonCourse.load_course("ls_10_01"), "challenging", 150)
	add_child(track)
	var sounds := LaneSmashSound.new()
	sounds.track = track
	add_child(sounds)
	sounds.active = true
	return [track, sounds]


func test_road_bombs_and_incoming_fire_have_their_own_explosions() -> void:
	var rig := _rig()
	var track: NeonTrack = rig[0]
	var played: Array = []
	var listener := func(sound: String, _bus: String): played.append(sound)
	AudioDirector.sound_played.connect(listener)
	track.blast_resolved.emit(true, -1800)
	assert_array(played).contains_exactly(["lane_smash_bomb"])
	played.clear()
	track.rules.barrage.active = true
	track.blast_resolved.emit(true, -1800)
	assert_array(played).contains_exactly(["lane_smash_impact"])
	played.clear()
	track.blast_resolved.emit(false, 1800)
	assert_array(played).contains_exactly(["lane_smash_impact", "lane_smash_pass"])
	played.clear()
	track.blast_resolved.emit(false, 0)
	assert_array(played).contains_exactly(["lane_smash_impact", "lane_smash_avoid"])
	AudioDirector.sound_played.disconnect(listener)
	rig[1].free()
	track.free()


func test_a_settled_lane_change_ticks_once_and_never_in_the_first_second() -> void:
	var rig := _rig()
	var track: NeonTrack = rig[0]
	var sounds: LaneSmashSound = rig[1]
	var played: Array = []
	var listener := func(sound: String, _bus: String): played.append(sound)
	AudioDirector.sound_played.connect(listener)
	track.rules.elapsed_ms = 400
	for lane in [1, -1, 2]:
		track.rules.settled_lane = lane
		sounds.update_audio()
	assert_int(played.count("lane_smash_lane")).is_equal(0)
	track.rules.elapsed_ms = 5000
	for lane in [2, -1, -1, 3, 3, 3, -1, 3]:
		track.rules.settled_lane = lane
		sounds.update_audio()
	assert_int(played.count("lane_smash_lane")).is_equal(1)
	track.rules.settled_lane = 0
	sounds.update_audio()
	assert_int(played.count("lane_smash_lane")).is_equal(2)
	sounds.active = false
	track.rules.settled_lane = 4
	sounds.update_audio()
	assert_int(played.count("lane_smash_lane")).is_equal(2)
	AudioDirector.sound_played.disconnect(listener)
	sounds.free()
	track.free()


func test_consecutive_gold_bars_climb_then_start_over_after_a_gap() -> void:
	var rig := _rig()
	var track: NeonTrack = rig[0]
	var sounds: LaneSmashSound = rig[1]
	var pitches: Array[float] = []
	for i in 8:
		track.space.target_hit.emit("cruise")
		var voice: AudioStreamPlayer = AudioDirector._sfx_players[posmod(AudioDirector._next_sfx - 1, AudioDirector._sfx_players.size())]
		pitches.append(voice.pitch_scale)
	assert_float(pitches[0]).is_equal_approx(1.0, 0.001)
	for i in range(1, 6): assert_float(pitches[i]).is_greater(pitches[i - 1])
	assert_float(pitches[5]).is_equal_approx(2.0, 0.001)
	assert_float(pitches[7]).is_equal_approx(2.0, 0.001)
	sounds._last_collect_msec -= LaneSmashSound.STREAK_WINDOW_MSEC + 1
	track.space.target_hit.emit("cruise")
	var last: AudioStreamPlayer = AudioDirector._sfx_players[posmod(AudioDirector._next_sfx - 1, AudioDirector._sfx_players.size())]
	assert_float(last.pitch_scale).is_equal_approx(1.0, 0.001)
	sounds.free()
	track.free()


func test_engine_bed_follows_cadence_and_stops_with_the_ride() -> void:
	var rig := _rig()
	var track: NeonTrack = rig[0]
	var sounds: LaneSmashSound = rig[1]
	track.rules.elapsed_ms = 5000
	track.rules.latest = {"cadence": 90.0, "power": 160.0, "resistance": 40.0}
	sounds.update_audio()
	assert_bool(sounds._engine.playing).is_true()
	for i in 60: sounds._process(0.1)
	var drive := 90.0 / NeonRules.MAX_CADENCE
	assert_float(sounds._engine.volume_db).is_equal_approx(lerpf(LaneSmashSound.ENGINE_QUIET_DB, LaneSmashSound.ENGINE_LOUD_DB, drive), 0.3)
	assert_float(sounds._engine.volume_db).is_between(-22.5, -13.5)
	assert_float(sounds._engine.pitch_scale).is_equal_approx(lerpf(LaneSmashSound.ENGINE_LOW_PITCH, LaneSmashSound.ENGINE_HIGH_PITCH, drive), 0.02)
	# Coasting to a stop fades it out; it never idles under a stationary rider.
	track.rules.latest = {"cadence": 2.0, "power": 0.0, "resistance": 40.0}
	sounds.update_audio()
	for i in 60: sounds._process(0.1)
	assert_bool(sounds._engine.playing).is_false()
	track.rules.latest = {"cadence": 120.0, "power": 250.0, "resistance": 40.0}
	sounds.update_audio()
	assert_bool(sounds._engine.playing).is_true()
	GameOptions.set_value(GameRegistry.info("neon_vector"), "sfx", "off")
	assert_bool(sounds._engine.playing).is_false()
	sounds.update_audio()
	assert_bool(sounds._engine.playing).is_false()
	GameOptions.set_value(GameRegistry.info("neon_vector"), "sfx", "on")
	sounds.update_audio()
	assert_bool(sounds._engine.playing).is_true()
	sounds.suspend()
	assert_bool(sounds._engine.playing).is_false()
	assert_bool(sounds.active).is_false()
	sounds.free()
	track.free()


## Stands in for the cadence-section gunfire rule: `fire` is what `gunfire()` reports.
class FireRules extends NeonRules:
	var fire := {}
	func gunfire() -> Dictionary:
		return fire


func test_machine_gun_bed_follows_the_gunfire_state_and_every_hit_cracks() -> void:
	var track := NeonTrack.new()
	var rules := FireRules.new()
	rules.configure(NeonCourse.load_course("ls_10_01"), "challenging", 150)
	track.rules = rules
	add_child(track)
	var sounds := LaneSmashSound.new()
	sounds.track = track
	add_child(sounds)
	sounds.active = true
	rules.elapsed_ms = 6000
	rules.latest = {"cadence": 70.0, "power": 120.0, "resistance": 33.0}
	sounds.update_audio()
	assert_bool(sounds._gun.playing).is_false()
	# Spinning up: fire is heard, but quieter, while the rider still has time to settle.
	rules.fire = {"eventId": "hold-1", "cadenceMin": 60, "cadenceMax": 80, "graceLeftMs": 1500, "exposed": false, "exposedMs": 0, "hits": 0, "spent": false}
	sounds.update_audio()
	assert_bool(sounds._gun.playing).is_true()
	assert_float(sounds._gun.volume_db).is_less(-60.0)
	for i in 10: sounds._process(0.02)
	assert_float(sounds._gun.volume_db).is_equal_approx(LaneSmashSound.GUN_GRACE_DB, 0.3)
	assert_float(sounds._gun.pitch_scale).is_equal_approx(1.0, 0.005)
	# Within 80 ms of a change the level is already most of the way there: no click, no lag.
	rules.fire.graceLeftMs = 0
	rules.fire.exposed = true
	sounds.update_audio()
	for i in 4: sounds._process(0.02)
	assert_float(sounds._gun.volume_db).is_between(LaneSmashSound.GUN_DB - 1.0, LaneSmashSound.GUN_DB)
	for i in 30: sounds._process(0.02)
	assert_float(sounds._gun.volume_db).is_equal_approx(LaneSmashSound.GUN_DB, 0.1)
	assert_float(sounds._gun.pitch_scale).is_equal_approx(LaneSmashSound.GUN_EXPOSED_PITCH, 0.005)
	rules.fire.exposed = false
	sounds.update_audio()
	for i in 30: sounds._process(0.02)
	assert_float(sounds._gun.pitch_scale).is_equal_approx(1.0, 0.005)
	# Every round that lands is heard, with no cooldown.
	var played: Array = []
	var listener := func(sound: String, _bus: String): played.append(sound)
	AudioDirector.sound_played.connect(listener)
	for i in 6:
		if track.has_signal(&"gun_hit"): track.emit_signal(&"gun_hit", 150)
		else: sounds._gun_hit(150)
	assert_int(played.count("lane_smash_gun_hit")).is_equal(6)
	AudioDirector.sound_played.disconnect(listener)
	# The section's hit cap ends the fire; so do the section's end, a pause and Effects Off.
	rules.fire.spent = true
	sounds.update_audio()
	for i in 10: sounds._process(0.02)
	assert_bool(sounds._gun.playing).is_false()
	rules.fire.spent = false
	sounds.update_audio()
	assert_bool(sounds._gun.playing).is_true()
	rules.fire = {}
	sounds.update_audio()
	for i in 10: sounds._process(0.02)
	assert_bool(sounds._gun.playing).is_false()
	rules.fire = {"eventId": "hold-2", "graceLeftMs": 0, "exposed": false, "spent": false}
	sounds.update_audio()
	assert_bool(sounds._gun.playing).is_true()
	sounds.active = false
	for i in 10: sounds._process(0.02)
	assert_bool(sounds._gun.playing).is_false()
	sounds.active = true
	sounds.update_audio()
	assert_bool(sounds._gun.playing).is_true()
	GameOptions.set_value(GameRegistry.info("neon_vector"), "sfx", "off")
	assert_bool(sounds._gun.playing).is_false()
	sounds.update_audio()
	assert_bool(sounds._gun.playing).is_false()
	GameOptions.set_value(GameRegistry.info("neon_vector"), "sfx", "on")
	sounds.update_audio()
	assert_bool(sounds._gun.playing).is_true()
	sounds.suspend()
	assert_bool(sounds._gun.playing).is_false()
	sounds.free()
	track.free()


func test_menu_feedback_follows_the_effects_switch() -> void:
	var played: Array = []
	var listener := func(sound: String, _bus: String): played.append(sound)
	AudioDirector.sound_played.connect(listener)
	LaneSmashSound.ui("tap")
	LaneSmashSound.ui("confirm")
	assert_array(played).contains_exactly(["lane_smash_ui_tap", "lane_smash_ui_confirm"])
	GameOptions.set_value(GameRegistry.info("neon_vector"), "sfx", "off")
	LaneSmashSound.ui("tap")
	assert_int(played.size()).is_equal(2)
	AudioDirector.sound_played.disconnect(listener)


func test_effects_sit_a_little_under_the_music_by_default() -> void:
	var music := AudioDirector.music_volume
	var sfx := AudioDirector.sfx_volume
	GameOptions.apply_audio()
	assert_float(AudioDirector.music_volume).is_equal_approx(GameOptions.MUSIC_LEVEL, 0.0001)
	assert_float(AudioDirector.sfx_volume).is_equal_approx(GameOptions.SFX_LEVEL, 0.0001)
	# Between one and a half and four decibels under the soundtrack: quieter, still clear.
	assert_float(linear_to_db(GameOptions.SFX_LEVEL / GameOptions.MUSIC_LEVEL)).is_between(-4.0, -1.5)
	AudioDirector.set_volumes(AudioDirector.music_enabled, music, sfx)
