class_name LaneSmashSound
extends Node
## Every contact has a cue. No repeat cooldown, probability gate or per-second sound limit.
## Short envelopes and conservative gain keep dense sections pleasant.
##
## One-shots go through AudioDirector's effect voices. Four beds have their own players so
## they can follow the ride smoothly: the power-section charge, the motorcycle's engine, the
## attacker's weapon charging and the machine-gun fire over a cadence section. All of it is
## presentation: nothing here reads back into the rules, and no prompt depends on being heard.

## One-shot cues (each between 0.07 and 0.6 s; see render_lane_smash_sfx.py).
const FILES := {
	"collect": preload("res://games/neon_vector/audio/sfx/collect.wav"),
	"cadence": preload("res://games/neon_vector/audio/sfx/cadence.wav"),
	"section": preload("res://games/neon_vector/audio/sfx/section.wav"),
	"power_finish": preload("res://games/neon_vector/audio/sfx/power_finish.wav"),
	"warning": preload("res://games/neon_vector/audio/sfx/warning.wav"),
	"launch": preload("res://games/neon_vector/audio/sfx/launch.wav"),
	"impact": preload("res://games/neon_vector/audio/sfx/impact.wav"),
	"bomb": preload("res://games/neon_vector/audio/sfx/bomb.wav"),
	"pass": preload("res://games/neon_vector/audio/sfx/pass.wav"),
	"avoid": preload("res://games/neon_vector/audio/sfx/avoid.wav"),
	"lane": preload("res://games/neon_vector/audio/sfx/lane.wav"),
	"gun_hit": preload("res://games/neon_vector/audio/sfx/gun_hit.wav"),
	"ui_tap": preload("res://games/neon_vector/audio/sfx/ui_tap.wav"),
	"ui_confirm": preload("res://games/neon_vector/audio/sfx/ui_confirm.wav"),
}
## Seamless beds, each on its own player.
const LOOPS := {
	"power": preload("res://games/neon_vector/audio/sfx/power_loop.wav"),
	"engine": preload("res://games/neon_vector/audio/sfx/engine_loop.wav"),
	"gun": preload("res://games/neon_vector/audio/sfx/gun_loop.wav"),
}
## The attacker's weapon gathering energy from target lock to launch.
const WEAPON_CHARGE := preload("res://games/neon_vector/audio/sfx/charge.wav")

## Consecutive gold bars climb a pentatonic scale, then hold its top note.
const STREAK_STEPS := [0, 2, 4, 7, 9, 12]
const STREAK_WINDOW_MSEC := 1800
const ENGINE_MIN_RPM := 5.0
const ENGINE_QUIET_DB := -22.0
const ENGINE_LOUD_DB := -14.0
const ENGINE_LOW_PITCH := 0.72
const ENGINE_HIGH_PITCH := 1.38
const WEAPON_DB := -5.0
## Machine-gun fire over a cadence section: quieter while the guns spin up and fire wide
## (the grace period), full once it counts, and a touch higher while rounds are landing.
const GUN_DB := -4.0
const GUN_GRACE_DB := -10.0
const GUN_EXPOSED_PITCH := 1.06
const GUN_FADE := 40.0  ## 1/s: in or out within about 70 ms, so the loop never clicks
## The blast itself under a dodge's own cue: it still lands on the road ahead or behind.
const DISTANT_BLAST_DB := -10.0

static var _registered := false

var track: NeonTrack
var active := false
var _charge: AudioStreamPlayer
var _engine: AudioStreamPlayer
var _weapon: AudioStreamPlayer
var _gun: AudioStreamPlayer
var _gun_gain := 0.0
var _gun_target := 0.0
var _gun_pitch := 1.0
var _gun_pitch_target := 1.0
var _shot_id := ""
var _fired := false
var _charge_gain := 0.0
var _charge_target := 0.0
var _engine_gain := 0.0
var _engine_target := 0.0
var _engine_pitch := 1.0
var _engine_pitch_target := 1.0
var _lane := -1
var _streak := 0
var _last_collect_msec := -100000


## Makes the one-shots known to AudioDirector (once; the menu needs them before any ride).
static func register_sounds() -> void:
	if _registered: return
	_registered = true
	for key in FILES: AudioDirector.register_sound("lane_smash_" + key, FILES[key])


## Menu feedback: `ui("tap")` or `ui("confirm")`. Silent while Sound effects is off.
static func ui(kind: String) -> void:
	register_sounds()
	AudioDirector.play_sfx("lane_smash_ui_" + kind)


func _ready() -> void:
	register_sounds()
	_charge = _loop_player("power")
	_engine = _loop_player("engine")
	_weapon = AudioStreamPlayer.new()
	_weapon.bus = AudioDirector.SFX_BUS
	_weapon.stream = WEAPON_CHARGE
	_weapon.volume_db = WEAPON_DB
	add_child(_weapon)
	track.space.target_hit.connect(_contact)
	track.section_finished.connect(_section)
	track.blast_resolved.connect(_blast)
	_gun = _loop_player("gun")
	# The gunfire rule and its signal arrive with the cadence-section attack.
	if track.has_signal(&"gun_hit"): track.connect(&"gun_hit", _gun_hit)
	AudioDirector.user_audio_changed.connect(_on_user_audio_changed)


func _on_user_audio_changed() -> void:
	if not AudioDirector.user_sfx_enabled: _silence()


func _loop_player(key: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = AudioDirector.SFX_BUS
	var loop: AudioStreamWAV = LOOPS[key].duplicate()
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	player.stream = loop
	player.volume_db = -80
	add_child(player)
	return player


func _play(kind: String, volume_db := 0.0, pitch := 1.0) -> void:
	if active: AudioDirector.play_sfx("lane_smash_" + kind, volume_db, pitch)


func _contact(kind: String) -> void:
	if kind == "hold":
		_play("cadence")
		return
	var now := Time.get_ticks_msec()
	_streak = mini(_streak + 1, STREAK_STEPS.size() - 1) if now - _last_collect_msec < STREAK_WINDOW_MSEC else 0
	_last_collect_msec = now
	_play("collect", 0.0, pow(2.0, STREAK_STEPS[_streak] / 12.0))


func _section(kind: String) -> void:
	_play("power_finish" if kind == "burst" else "section")


func _blast(hit: bool, points: int) -> void:
	# A static road bomb only ever reports a hit, and never during Incoming Fire.
	if track.rules == null or not track.rules.barrage.active:
		_play("bomb")
	elif hit:
		_play("impact")
	else:
		_play("impact", DISTANT_BLAST_DB, 0.9)
		_play("pass" if points > 0 else "avoid")


func _gun_hit(_points: int = 0) -> void:
	_play("gun_hit")


func update_audio() -> void:
	var rules := track.rules
	var cadence := float(rules.latest.get("cadence", 0))
	var audible := active and AudioDirector.user_sfx_enabled and rules.pause_reason.is_empty()
	var shot := rules.barrage.current_shot()
	if not shot.is_empty():
		if _shot_id != str(shot.shotId):
			_shot_id = str(shot.shotId)
			_fired = false
			_play("warning")
			# Join the charge where it should be by now (a ride resumed or sought mid-charge).
			var into := (rules.elapsed_ms - int(shot.lockMs)) / 1000.0
			if audible and into >= 0.0 and into < WEAPON_CHARGE.get_length() - 0.1 and rules.elapsed_ms < int(shot.fireMs):
				_weapon.play(into)
		if not _fired and rules.elapsed_ms >= int(shot.fireMs):
			_fired = true
			_weapon.stop()
			_play("launch")
	elif _weapon.playing:
		_weapon.stop()
	var fire: Dictionary = rules.call(&"gunfire") if rules.has_method(&"gunfire") else {}
	if audible and not fire.is_empty() and not bool(fire.get("spent", false)):
		_gun_target = db_to_linear(GUN_GRACE_DB if int(fire.get("graceLeftMs", 0)) > 0 else GUN_DB)
		_gun_pitch_target = GUN_EXPOSED_PITCH if bool(fire.get("exposed", false)) else 1.0
		if not _gun.playing:
			_gun_gain = 0.0
			_gun_pitch = _gun_pitch_target
			_gun.volume_db = -80
			_gun.pitch_scale = _gun_pitch
			_gun.play()
	else: _gun_target = 0.0
	var lane := rules.settled_lane
	if lane >= 0:
		if _lane >= 0 and lane != _lane and rules.elapsed_ms >= 1000: _play("lane")
		_lane = lane
	var event := rules.current_event()
	var charging: bool = audible and not rules.barrage.active and event.get("type") == "burst" and rules.road_time_ms() >= int(event.get("startMs", 0)) and rules.settled_lane == int(event.get("laneIndex", -2)) and cadence >= 20
	if charging:
		if not _charge.playing:
			_charge_gain = 0.0
			_charge.volume_db = -80
			_charge.play()
		_charge_target = db_to_linear(lerpf(-12, -3, clampf(rules.smoothed_power / 350.0, 0, 1)))
		_charge.pitch_scale = lerpf(0.85, 1.15, clampf(cadence / 140.0, 0, 1))
	else: _charge_target = 0.0
	if audible and cadence >= ENGINE_MIN_RPM:
		var drive := clampf(cadence / NeonRules.MAX_CADENCE, 0, 1)
		_engine_pitch_target = lerpf(ENGINE_LOW_PITCH, ENGINE_HIGH_PITCH, drive)
		if not _engine.playing:
			_engine_gain = 0.0
			_engine_pitch = _engine_pitch_target
			_engine.volume_db = -80
			_engine.pitch_scale = _engine_pitch
			_engine.play()
		_engine_target = db_to_linear(lerpf(ENGINE_QUIET_DB, ENGINE_LOUD_DB, drive))
	else: _engine_target = 0.0


func _process(delta: float) -> void:
	# `active` drops whenever a frame does not advance the ride: the beds fade with it.
	if not active:
		_charge_target = 0.0
		_engine_target = 0.0
		_gun_target = 0.0
	if _gun.playing:
		_gun_gain = lerpf(_gun_gain, _gun_target, 1.0 - exp(-delta * GUN_FADE))
		_gun_pitch = lerpf(_gun_pitch, _gun_pitch_target, 1.0 - exp(-delta * 12.0))
		_gun.volume_db = linear_to_db(maxf(0.0001, _gun_gain))
		_gun.pitch_scale = _gun_pitch
		if _gun_target == 0.0 and _gun_gain < 0.001: _gun.stop()
	if _charge.playing:
		_charge_gain = lerpf(_charge_gain, _charge_target, 1.0 - exp(-delta * 32.0))
		_charge.volume_db = linear_to_db(maxf(0.0001, _charge_gain))
		if _charge_target == 0.0 and _charge_gain < 0.001: _charge.stop()
	if _engine.playing:
		_engine_gain = lerpf(_engine_gain, _engine_target, 1.0 - exp(-delta * 5.0))
		_engine_pitch = lerpf(_engine_pitch, _engine_pitch_target, 1.0 - exp(-delta * 3.5))
		_engine.volume_db = linear_to_db(maxf(0.0001, _engine_gain))
		_engine.pitch_scale = _engine_pitch
		if _engine_target == 0.0 and _engine_gain < 0.001: _engine.stop()


func suspend() -> void:
	active = false
	_silence()


## Stops every bed at once (an interruption, the end of the ride, Sound effects Off).
func _silence() -> void:
	_charge_gain = 0.0
	_charge_target = 0.0
	_engine_gain = 0.0
	_engine_target = 0.0
	_gun_gain = 0.0
	_gun_target = 0.0
	_charge.stop()
	_engine.stop()
	_weapon.stop()
	_gun.stop()
