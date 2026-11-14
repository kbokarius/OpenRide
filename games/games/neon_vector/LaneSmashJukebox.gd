extends Node
## Lane Smash's persistent soundtrack (autoload `Jukebox`) and its live spectrum analysis.
##
## One long track plays at a time. The app starts on a random track at a random position and
## keeps playing across the menu, rides and results; when a track ends another random one
## follows. The rider picks tracks and seeks through `select` / `seek` (LaneSmashMusicPanel).
##
## The player sits on its own bus, `LaneSmashMusic`, which sends to AudioDirector's `Music`
## bus: the Music switch, host volume and cue ducking keep working, while the spectrum
## analyser survives AudioDirector clearing the `Music` bus's effects every segment.
## Music Off, the rider's own music app or a host mute stop decoding and hold the position.
##
## The three long-form tracks live in `audio/tracks/`. A build without them plays the
## original Night Drive loop instead.
##
## The analysis values are presentation only; nothing here can affect rules or scores.

signal track_changed(index: int)
signal playback_changed

const BUS := "LaneSmashMusic"
## A random start never lands closer than this to a track's end.
const END_MARGIN_SEC := 60.0
const PERSONAL := [
	{"id": "discovery_project", "title": "Discovery Project", "subtitle": "Electric Forest", "artist": "Devloe",
		"path": "res://games/neon_vector/audio/tracks/devloe_discovery_project.ogg", "length_sec": 1850.5},
	{"id": "dns_mix", "title": "DNS Mix", "subtitle": "", "artist": "Devloe",
		"path": "res://games/neon_vector/audio/tracks/devloe_dns_mix.ogg", "length_sec": 1794.0},
	{"id": "dystopian_euphoria", "title": "Dystopian Euphoria", "subtitle": "", "artist": "Devloe",
		"path": "res://games/neon_vector/audio/tracks/devloe_dystopian_euphoria.ogg", "length_sec": 4935.4},
]
const FALLBACK := {"id": "night_drive", "title": "Night Drive", "subtitle": "", "artist": "Lane Smash",
	"path": "res://games/neon_vector/audio/vector_drive.ogg", "length_sec": 120.0}

const BAND_COUNT := 8
## Log-spaced band edges in Hz: bands 0-1 are bass, 2-5 mids, 6-7 treble.
const BAND_EDGES := [30.0, 60.0, 130.0, 260.0, 520.0, 1050.0, 2100.0, 4500.0, 12000.0]
## Each band is read between two followers of its own level: a running peak and a running
## trough. Their distance is the band's span, so a heavily compressed master still swings the
## full range, while a band that drops out (a breakdown without bass) goes dark.
const SPAN_MIN_DB := 9.0
const SPAN_MAX_DB := 28.0
const START_SPAN_DB := 18.0
const TROUGH_RISE_DB := 7.0  ## dB per second the trough climbs back after a dip
## Where each band's running peak starts (dB, average magnitude): typical of mastered dance
## music, measured on the real mixes, so the first seconds neither flash nor sit dark.
const START_PEAK_DB := [-20.0, -20.0, -25.0, -35.0, -41.0, -44.0, -47.0, -53.0]
const PEAK_FLOOR_BELOW_START_DB := 22.0  ## a peak never adapts lower: near-silence stays dark
const PEAK_DECAY_DB := 2.0  ## dB per second the running peak relaxes in quieter passages
const CONTRAST := 2.0  ## above 1 keeps the sustained level low and lets peaks stand out
const ATTACK := 34.0
const RELEASE := 10.0
const SILENCE_RELEASE := 14.0
const ONSET_RATIO := 1.38  ## bass energy against its running average
const ONSET_RISE := 1.12  ## and against the previous frame (flux)
const ONSET_MIN := 0.3  ## normalised bass below this never counts as a kick
const REFRACTORY_SEC := 0.18
const BEAT_DECAY := 2.8  ## about a quarter-second half-life
const MAX_LATENCY_SEC := 0.35
const CALM_ATTACK := 2.2    ## per second: about half a second to rise
const CALM_RELEASE := 1.1   ## about a second to fall
const CALM_STOP_RELEASE := 10.0  ## when playback stops: settled within half a second
const PULSE_ATTACK := 6.0
const PULSE_RELEASE := 2.0
const PULSE_DEPTH := 0.5    ## how much of a kick reaches the picture
const HISTORY := 64
## The soundtrack never starts or stops abruptly. Whatever starts fades in, and whatever was
## playing (a track being replaced, a seek's old position, Music Off) fades out on a second
## player while the new sound comes in, so a change is a short crossfade.
const FADE_IN_SEC := 0.6
const FADE_OUT_SEC := 0.4
const STRIDE := BAND_COUNT + 2  # time, bands, onset

## The tracks that can play: `{id, title, subtitle, artist, path, length_sec}`. Tests may
## assign their own (an entry may carry a ready `stream` instead of a path).
var playlist: Array = []
var current := -1
## False in headless runs: nothing starts or loads by itself; tests drive the jukebox.
var autoplay := DisplayServer.get_name() != "headless"
## Holds the published analysis values as they are (captures and tests set them directly).
var frozen := false
## Tests: `func(from_hz, to_hz) -> float` linear magnitude, instead of the bus analyser.
var spectrum_source := Callable()
## Milliseconds the last track load took (0 for a ready stream).
var last_load_msec := 0

# --- Analysis, eased, 0..1, zero while nothing is audible ---
var level := 0.0  ## overall loudness
var bass := 0.0  ## about 30-130 Hz
var mid := 0.0  ## about 130-2100 Hz
var treble := 0.0  ## about 2100-12000 Hz
var beat := 0.0  ## 1 on a detected kick, then an exponential decay
var beat_count := 0  ## +1 per kick
var flow := 0.0  ## a phase that only music moves forward; never decreases
## The same analysis, slowed for scenery: these rise over about half a second and fall
## over about a second, so the picture swells and settles with the music instead of twitching
## with every transient. `pulse` is the kick as a soft swell rather than a flash. Anything
## that moves a large part of the screen reads these, never the fast values above.
var calm_bass := 0.0
var calm_mid := 0.0
var calm_treble := 0.0
var calm_level := 0.0
var pulse := 0.0
var bands := PackedFloat32Array()  ## the eight bands

var _player: AudioStreamPlayer  ## the deck that is (or will be) playing the current track
var _tail: AudioStreamPlayer    ## the other deck: whatever was playing before, fading out
var _gain := 0.0       ## the current deck's level, 0..1
var _tail_gain := 0.0  ## the outgoing deck's level
var _analyzer: AudioEffectSpectrumAnalyzerInstance
var _rng := RandomNumberGenerator.new()
var _started := false
var _stream_ready := false
var _audible := false
var _resume_at := 0.0
var _play_started_msec := 0
var _loading_path := ""
var _load_started_msec := 0
var _stale: Array[String] = []
var _history := PackedFloat64Array()
var _head := 0
var _read := 0
var _targets := PackedFloat32Array()
var _peaks := PackedFloat32Array()
var _troughs := PackedFloat32Array()
var _bass_average := 0.0
var _bass_previous := 0.0
var _last_onset := -10.0
var _latency := 0.0
var _latency_age := 10.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	bands.resize(BAND_COUNT)
	_targets.resize(BAND_COUNT)
	_peaks.resize(BAND_COUNT)
	_troughs.resize(BAND_COUNT)
	_history.resize(HISTORY * STRIDE)
	_reset_analysis()
	_ensure_bus()
	for deck_name in ["Player", "Tail"]:
		var deck := AudioStreamPlayer.new()
		deck.name = deck_name
		deck.bus = BUS
		deck.finished.connect(_on_deck_finished.bind(deck))
		add_child(deck)
	_player = get_node("Player")
	_tail = get_node("Tail")
	rescan()
	if autoplay:
		_autostart.call_deferred()


## Rebuilds the playlist from the files present: the personal tracks, else Night Drive.
## `manifest` is PERSONAL unless a test passes its own.
func rescan(manifest: Array = PERSONAL) -> void:
	var found: Array = []
	for track: Dictionary in manifest:
		if ResourceLoader.exists(str(track.path)): found.append(track.duplicate())
	if found.is_empty() and ResourceLoader.exists(str(FALLBACK.path)): found.append(FALLBACK.duplicate())
	set_playlist(found)


## Replaces the playlist and forgets the current track (tests, or after `rescan`).
func set_playlist(list: Array) -> void:
	_halt()
	_player.stream = null
	_stream_ready = false
	_abandon_load()
	playlist = list
	current = -1
	_started = false
	_resume_at = 0.0
	track_changed.emit(-1)
	playback_changed.emit()


func tracks() -> Array:
	return playlist


## True while more than the built-in fallback loop is available.
func has_personal_tracks() -> bool:
	return not playlist.is_empty() and str(playlist[0].get("id", "")) != str(FALLBACK.id)


func title() -> String:
	return str(playlist[current].get("title", "")) if current >= 0 else ""


func artist() -> String:
	return str(playlist[current].get("artist", "")) if current >= 0 else ""


func subtitle() -> String:
	return str(playlist[current].get("subtitle", "")) if current >= 0 else ""


## Audible playback: a loaded track that is neither held by a gate nor still loading.
func is_playing() -> bool:
	return _audible


## A track was chosen and is being read from storage.
func is_loading() -> bool:
	return current >= 0 and not _stream_ready and not _loading_path.is_empty()


## A start was asked for (by the app's launch, the hub, a ride or the rider).
func is_started() -> bool:
	return _started


## The jukebox is, or is about to be, the app's soundtrack: nothing else should play music.
func owns_music() -> bool:
	return _started or autoplay


func position_sec() -> float:
	if current < 0: return 0.0
	if not _audible: return _resume_at
	var at := _player.get_playback_position()
	# The mixer reports zero for a moment after a start or seek.
	if Time.get_ticks_msec() - _play_started_msec < 400: at = maxf(at, _resume_at)
	return clampf(at, 0.0, length_sec())


func length_sec() -> float:
	if current < 0: return 0.0
	return float(playlist[current].get("length_sec", 0.0))


## Plays track `index` from `from_sec` (clamped), replacing whatever plays now.
func select(index: int, from_sec := 0.0) -> void:
	if index < 0 or index >= playlist.size(): return
	_halt()
	_player.stream = null
	_stream_ready = false
	current = index
	_started = true
	_resume_at = clampf(from_sec, 0.0, _last_start(index))
	track_changed.emit(index)
	playback_changed.emit()


## Moves within the current track; works while paused or loading too.
func seek(seconds: float) -> void:
	if current < 0: return
	_resume_at = clampf(seconds, 0.0, _last_start(current))
	if _audible: _play_from(_resume_at)
	else: playback_changed.emit()


## A random track at a random position, at least END_MARGIN_SEC before its end.
func start_random() -> void:
	if playlist.is_empty(): rescan()
	if playlist.is_empty(): return
	var index := _rng.randi_range(0, playlist.size() - 1)
	var length := float(playlist[index].get("length_sec", 0.0))
	select(index, _rng.randf_range(0.0, maxf(0.0, length - END_MARGIN_SEC)))
	print("OPENRIDE_GAMES jukebox start: %s at %d s of %d s (%d tracks)" % [title(), int(_resume_at), int(length), playlist.size()])


## Starts the music once (the hub and the ride call this); never restarts a playing track.
## Does nothing in headless runs unless `autoplay` was turned on.
func ensure_started() -> void:
	if not _started and autoplay: start_random()


## Another random track from its beginning: a different one whenever there is a choice.
func next_random() -> void:
	if playlist.is_empty(): return
	var index := 0
	if playlist.size() > 1:
		index = _rng.randi_range(0, playlist.size() - 2)
		if index >= current: index += 1
	select(index, 0.0)


## Tests: makes random picks repeatable.
func seed_random(value: int) -> void:
	_rng.seed = value


func _autostart() -> void:
	# A `-s` script (tests, captures) has no main scene: it starts music itself if it wants it.
	if get_tree().current_scene != null: ensure_started()


func _process(delta: float) -> void:
	_collect_stale()
	if current >= 0:
		var allowed := _allowed()
		if not _stream_ready and (allowed or not _loading_path.is_empty()): _load_step()
		if _stream_ready:
			if allowed and not _audible: _play_from(_resume_at)
			elif not allowed and _audible: _hold()
			# Belt and braces for the `finished` signal: a track that ran out moves on.
			elif _audible and not _player.playing and Time.get_ticks_msec() - _play_started_msec > 800: _on_finished()
	_fade(delta)
	_analyze(delta)


## Moves both decks toward their levels: the current one up to full, the outgoing one down to
## silence, where it stops and lets go of its track.
func _fade(delta: float) -> void:
	delta = clampf(delta, 0.0, 0.1)
	if _audible and _gain < 1.0:
		_gain = minf(1.0, _gain + delta / FADE_IN_SEC)
		_player.volume_db = _level_db(_gain)
	if _tail.playing:
		_tail_gain = maxf(0.0, _tail_gain - delta / FADE_OUT_SEC)
		_tail.volume_db = _level_db(_tail_gain)
		if _tail_gain <= 0.0:
			_tail.stop()
			_tail.stream = null


## A level of 0..1 as decibels; squared, so a fade sounds even from end to end.
static func _level_db(level: float) -> float:
	return linear_to_db(maxf(level * level, 0.00001))


## Hands whatever the current deck is playing to the outgoing deck, to fade out from the level
## it has now, and leaves the current deck silent and free.
func _release() -> void:
	if not _player.playing: return
	if _tail.playing: _tail.stop()
	var outgoing := _player
	_player = _tail
	_tail = outgoing
	_tail_gain = _gain
	_gain = 0.0
	_player.stream = null


func _allowed() -> bool:
	return _started and AudioDirector.user_music_enabled and AudioDirector.music_enabled and not AudioDirector.rider_music


func _last_start(index: int) -> float:
	var length := float(playlist[index].get("length_sec", 0.0))
	# An unknown length is settled when the stream arrives (`_adopt`).
	return maxf(0.0, length - 1.0) if length > 0.0 else 1.0e9


func _play_from(seconds: float) -> void:
	_resume_at = clampf(seconds, 0.0, _last_start(current))
	# A seek while playing: the old position fades out as the new one fades in.
	var stream := _player.stream
	_release()
	_player.stream = stream
	_gain = 0.0
	_player.volume_db = _level_db(0.0)
	_player.play(_resume_at)
	_play_started_msec = Time.get_ticks_msec()
	_audible = true
	playback_changed.emit()


## Stops decoding and remembers the position (Music Off, the rider's own music, a host mute).
func _hold() -> void:
	_resume_at = position_sec()
	_halt()
	playback_changed.emit()


func _halt() -> void:
	if _audible:
		_audible = false
		# The sound fades out on the outgoing deck; the current deck is stopped and silent.
		var stream := _player.stream
		_release()
		_player.stream = stream


func _on_deck_finished(deck: AudioStreamPlayer) -> void:
	if deck == _player: _on_finished()


func _on_finished() -> void:
	# stop() never reports here; only a track that ran out does.
	if not _audible: return
	_audible = false
	next_random()


func _load_step() -> void:
	var track: Dictionary = playlist[current]
	if track.get("stream") is AudioStream:
		last_load_msec = 0
		_adopt(track.stream)
		return
	var path := str(track.path)
	if _loading_path != path:
		_abandon_load()
		if path in _stale:
			_stale.erase(path)  # that read is still in flight: take it over
		elif ResourceLoader.load_threaded_request(path, "AudioStream") != OK:
			_drop_current("could not start reading")
			return
		_loading_path = path
		_load_started_msec = Time.get_ticks_msec()
		playback_changed.emit()
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: return
	_loading_path = ""
	var stream: AudioStream = null
	if status == ResourceLoader.THREAD_LOAD_LOADED: stream = ResourceLoader.load_threaded_get(path) as AudioStream
	if stream == null:
		_drop_current("could not be read")
		return
	last_load_msec = Time.get_ticks_msec() - _load_started_msec
	_adopt(stream)


func _adopt(stream: AudioStream) -> void:
	_player.stream = stream
	var length := stream.get_length()
	if length > 0.0: playlist[current].length_sec = length
	_resume_at = clampf(_resume_at, 0.0, _last_start(current))
	_stream_ready = true
	playback_changed.emit()


## A track that cannot be read leaves the playlist; the next one takes over.
func _drop_current(why: String) -> void:
	push_warning("Jukebox: %s %s" % [playlist[current].get("path", playlist[current].get("id", "?")), why])
	playlist.remove_at(current)
	current = -1
	_stream_ready = false
	track_changed.emit(-1)
	if playlist.is_empty():
		_started = false
		playback_changed.emit()
	else:
		next_random()


func _abandon_load() -> void:
	if not _loading_path.is_empty():
		_stale.append(_loading_path)
		_loading_path = ""


## A read nobody waits for any more is still collected, so its memory is released.
func _collect_stale() -> void:
	for i in range(_stale.size() - 1, -1, -1):
		var status := ResourceLoader.load_threaded_get_status(_stale[i])
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
		if status == ResourceLoader.THREAD_LOAD_LOADED: ResourceLoader.load_threaded_get(_stale[i])
		_stale.remove_at(i)


func _ensure_bus() -> void:
	var index := AudioServer.get_bus_index(BUS)
	if index == -1:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		var parent := AudioDirector.MUSIC_BUS if AudioServer.get_bus_index(AudioDirector.MUSIC_BUS) != -1 else "Master"
		AudioServer.set_bus_send(index, parent)
	var slot := -1
	for i in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, i) is AudioEffectSpectrumAnalyzer: slot = i
	if slot == -1:
		var effect := AudioEffectSpectrumAnalyzer.new()
		effect.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
		effect.buffer_length = 0.1
		AudioServer.add_bus_effect(index, effect)
		slot = AudioServer.get_bus_effect_count(index) - 1
	_analyzer = AudioServer.get_bus_effect_instance(index, slot) as AudioEffectSpectrumAnalyzerInstance


# --- Analysis ---

func _reset_analysis() -> void:
	_head = 0
	_read = 0
	_bass_average = 0.0
	_bass_previous = 0.0
	for b in BAND_COUNT:
		_targets[b] = 0.0
		_peaks[b] = START_PEAK_DB[b]
		_troughs[b] = START_PEAK_DB[b] - START_SPAN_DB


func _magnitude(from_hz: float, to_hz: float) -> float:
	if spectrum_source.is_valid(): return float(spectrum_source.call(from_hz, to_hz))
	if _analyzer == null: return 0.0
	var pair := _analyzer.get_magnitude_for_frequency_range(from_hz, to_hz, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
	return (pair.x + pair.y) * 0.5


func _analyze(delta: float) -> void:
	delta = clampf(delta, 0.0, 0.1)
	if frozen:
		_ease_calm(delta)
		return
	var now := Time.get_ticks_usec() / 1000000.0
	var onset := false
	if _audible:
		_latency_age += delta
		if _latency_age > 1.0:
			_latency_age = 0.0
			_latency = clampf(AudioServer.get_output_latency(), 0.0, MAX_LATENCY_SEC)
		# Newest spectrum goes into the ring; what the speakers play now comes out of it.
		var base := _head * STRIDE
		_history[base] = now
		var low := 0.0
		for b in BAND_COUNT:
			var db := linear_to_db(maxf(_magnitude(BAND_EDGES[b], BAND_EDGES[b + 1]), 0.0000001))
			var peak := maxf(maxf(db, _peaks[b] - PEAK_DECAY_DB * delta), START_PEAK_DB[b] - PEAK_FLOOR_BELOW_START_DB)
			var trough := clampf(minf(db, _troughs[b] + TROUGH_RISE_DB * delta), peak - SPAN_MAX_DB, peak - SPAN_MIN_DB)
			_peaks[b] = peak
			_troughs[b] = trough
			var span := clampf((db - trough) / (peak - trough), 0.0, 1.0)
			_history[base + 1 + b] = pow(span, CONTRAST)
			if b < 2: low = maxf(low, span)
		var energy := low * low
		var kick := energy > _bass_average * ONSET_RATIO and energy > _bass_previous * ONSET_RISE and low > ONSET_MIN and now - _last_onset > REFRACTORY_SEC
		if kick: _last_onset = now
		_bass_average = lerpf(_bass_average, energy, 1.0 - exp(-delta * 2.2))
		_bass_previous = energy
		_history[base + 1 + BAND_COUNT] = 1.0 if kick else 0.0
		_head = (_head + 1) % HISTORY
		if _head == _read: _read = (_read + 1) % HISTORY  # the ring is full: drop the oldest
		var due := now - _latency
		while _read != _head and _history[_read * STRIDE] <= due:
			var from := _read * STRIDE
			for b in BAND_COUNT: _targets[b] = _history[from + 1 + b]
			if _history[from + 1 + BAND_COUNT] > 0.5: onset = true
			_read = (_read + 1) % HISTORY
	else:
		_reset_analysis()
	var release := RELEASE if _audible else SILENCE_RELEASE
	var total := 0.0
	for b in BAND_COUNT:
		var value := bands[b]
		var target := _targets[b]
		value = lerpf(value, target, 1.0 - exp(-delta * (ATTACK if target > value else release)))
		if value < 0.002 and target <= 0.0: value = 0.0
		bands[b] = value
		total += value
	bass = maxf(bands[0], bands[1])
	mid = (bands[2] + bands[3] + bands[4] + bands[5]) * 0.25
	treble = (bands[6] + bands[7]) * 0.5
	level = total / BAND_COUNT
	if onset:
		beat = 1.0
		beat_count += 1
	else:
		beat *= exp(-delta * (BEAT_DECAY if _audible else SILENCE_RELEASE))
		if beat < 0.002: beat = 0.0
	_ease_calm(delta)


## Eases the calm values toward the fast ones and advances the music phase at a steady,
## slowly varying rate (a rate that jumped on every kick made the scenery lurch).
func _ease_calm(delta: float) -> void:
	# Within the music the fall is slow; when playback itself stops (Music Off, a held track)
	# the picture settles promptly, so the phase stops with the music.
	var release := CALM_RELEASE if _audible or frozen else CALM_STOP_RELEASE
	calm_bass = _calm(calm_bass, bass, delta, release)
	calm_mid = _calm(calm_mid, mid, delta, release)
	calm_treble = _calm(calm_treble, treble, delta, release)
	calm_level = _calm(calm_level, level, delta, release)
	var kick := beat * PULSE_DEPTH
	pulse = lerpf(pulse, kick, 1.0 - exp(-delta * (PULSE_ATTACK if kick > pulse else maxf(PULSE_RELEASE, release))))
	if pulse < 0.002 and kick <= 0.0: pulse = 0.0
	flow += delta * (calm_level * 0.9 + calm_bass * 0.5)


static func _calm(value: float, target: float, delta: float, release: float) -> float:
	value = lerpf(value, target, 1.0 - exp(-delta * (CALM_ATTACK if target > value else release)))
	return 0.0 if value < 0.002 and target <= 0.0 else value
