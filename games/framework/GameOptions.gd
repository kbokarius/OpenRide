class_name GameOptions
extends RefCounted
## Each game's own options (`GameInfo.options`), remembered per rider (docs/GAMES.md,
## "Game options"). The shared pause screen shows and changes them; a game reads them with
## `Game.option(key)` and hears changes through `Game._on_option_changed(key, value)`.
##
## Stored in `user://game_options.cfg`, one section per rider and game: `<rider>/<game_id>`.
## The rider is `session_started`'s `rider_id`, or "guest" when no rider is active.
## Lane Smash music/SFX use one shared device section, independent of rider or screen.

const AUDIO_SECTION := "shared/lane_smash_audio"

const DEFAULT_PATH := "user://game_options.cfg"

## Tests point this elsewhere.
static var path := DEFAULT_PATH

static var _file: ConfigFile
static var _loaded_path := ""


## The rider the current session belongs to.
static func rider() -> String:
	var id = Session.plan.get("rider_id")
	return "guest" if id == null else str(id).trim_suffix(".0")


## `key`'s value for this rider and game: the stored choice, else the declared default.
static func get_value(info: GameInfo, key: String, rider_id := rider()) -> String:
	var spec := info.option_spec(key)
	if spec.is_empty():
		push_warning("GameOptions: %s declares no option '%s'" % [info.id, key])
		return ""
	var section := _option_section(info.id, key, rider_id)
	# Migrate a prior per-rider music preference once, then share audio across every screen.
	if section == AUDIO_SECTION and not _config().has_section_key(section, key) and _config().has_section_key(_section(info.id, rider_id), key):
		set_value(info, key, str(_config().get_value(_section(info.id, rider_id), key)), rider_id)
	var stored := str(_config().get_value(section, key, spec.default))
	return stored if (spec.choices as Array).has(stored) else str(spec.default)


## Stores `value` for this rider and game. Unknown keys and values are ignored.
static func set_value(info: GameInfo, key: String, value: String, rider_id := rider()) -> bool:
	var spec := info.option_spec(key)
	if spec.is_empty() or not (spec.choices as Array).has(value):
		return false
	var config := _config()
	var section := _option_section(info.id, key, rider_id)
	var existed := config.has_section_key(section, key)
	var previous: Variant = config.get_value(section, key) if existed else null
	config.set_value(section, key, value)
	var err := config.save(path)
	if err != OK:
		push_warning("GameOptions: can't save %s (%d)" % [path, err])
		if existed: config.set_value(section, key, previous)
		else: config.erase_section_key(section, key)
		return false
	if section == AUDIO_SECTION: apply_audio()
	return true


## The choice after `value` in the option's list, wrapping round (the pause screen's buttons).
static func next_choice(spec: Dictionary, value: String) -> String:
	var choices: Array = spec.get("choices", [])
	if choices.is_empty():
		return value
	return str(choices[(choices.find(value) + 1) % choices.size()])


## The shown text for `value`.
static func label_for(spec: Dictionary, value: String) -> String:
	var choices: Array = spec.get("choices", [])
	var labels: Array = spec.get("labels", choices)
	var i := choices.find(value)
	return str(labels[i]) if i >= 0 and i < labels.size() else value


## Forgets everything stored for `rider_id` (tests clean up with this).
static func forget_rider(rider_id: String) -> void:
	var config := _config()
	for section in config.get_sections():
		if section.begins_with(rider_id + "/"):
			config.erase_section(section)
	config.save(path)


## Forgets the cached file (tests, or after `path` changes).
static func reload() -> void:
	_file = null


static func _section(game_id: String, rider_id: String) -> String:
	return "%s/%s" % [rider_id, game_id]


static func _config() -> ConfigFile:
	if _file == null or _loaded_path != path:
		_file = ConfigFile.new()
		_loaded_path = path
		if FileAccess.file_exists(path):
			_file.load(path)
	return _file


static func _option_section(game_id: String, key: String, rider_id: String) -> String:
	return AUDIO_SECTION if game_id == "neon_vector" and key in ["music", "sfx"] else _section(game_id, rider_id)

## Lane Smash's automatic graphics tier, remembered per device (not per rider): the tier the
## last ride settled on, so the next one starts there instead of stepping down again.
const GRAPHICS_SECTION := "shared/lane_smash_graphics"

## The key carries a generation: when the picture's cost changes (revision 13 made every tier
## much cheaper), the tier an older build settled on is forgotten and Auto starts fresh.
const GRAPHICS_KEY := "auto_tier_2"

static func graphics_tier(fallback: String) -> String:
	return str(_config().get_value(GRAPHICS_SECTION, GRAPHICS_KEY, fallback))

static func set_graphics_tier(tier: String) -> void:
	_config().set_value(GRAPHICS_SECTION, GRAPHICS_KEY, tier)
	_config().save(path)

static func audio_values() -> Dictionary:
	return {"music": str(_config().get_value(AUDIO_SECTION, "music", "on")) != "off",
		"sfx": str(_config().get_value(AUDIO_SECTION, "sfx", "on")) != "off"}

## The mix: effects sit a little under the soundtrack (about 2 dB below it), so cues stay
## clear without talking over the music.
const MUSIC_LEVEL := 0.65
const SFX_LEVEL := 0.5

static func apply_audio() -> void:
	var director := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("AudioDirector")
	if director != null:
		var values := audio_values()
		director.set_volumes(true, MUSIC_LEVEL, SFX_LEVEL)
		director.set_user_audio(values.music, values.sfx)
