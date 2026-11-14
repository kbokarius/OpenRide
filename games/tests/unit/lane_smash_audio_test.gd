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
