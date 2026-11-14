class_name LaneSmashSound
extends Node
## Every contact has a cue. No repeat cooldown, probability gate or per-second sound limit.
## Short envelopes and conservative gain keep dense sections pleasant.
const FILES := {
	"collect": preload("res://games/neon_vector/audio/sfx/collect.wav"),
	"cadence": preload("res://games/neon_vector/audio/sfx/cadence.wav"),
	"section": preload("res://games/neon_vector/audio/sfx/section.wav"),
	"power_finish": preload("res://games/neon_vector/audio/sfx/power_finish.wav"),
	"warning": preload("res://games/neon_vector/audio/sfx/warning.wav"),
	"launch": preload("res://games/neon_vector/audio/sfx/launch.wav"),
	"impact": preload("res://games/neon_vector/audio/sfx/impact.wav"),
	"pass": preload("res://games/neon_vector/audio/sfx/pass.wav"),
	"avoid": preload("res://games/neon_vector/audio/sfx/avoid.wav"),
}
var track: NeonTrack
var active := false
var _charge: AudioStreamPlayer
var _shot_id := ""
var _fired := false
var _charge_gain := 0.0
var _charge_target := 0.0

func _ready() -> void:
	for key in FILES: AudioDirector.register_sound("lane_smash_" + key, FILES[key])
	_charge = AudioStreamPlayer.new()
	_charge.bus = AudioDirector.SFX_BUS
	var loop: AudioStreamWAV = preload("res://games/neon_vector/audio/sfx/power_loop.wav").duplicate()
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_charge.stream = loop
	add_child(_charge)
	track.space.target_hit.connect(_contact)
	track.section_finished.connect(_section)
	track.blast_resolved.connect(_blast)
	AudioDirector.user_audio_changed.connect(func():
		if not AudioDirector.user_sfx_enabled:
			_charge.stop()
			_charge_gain = 0.0
			_charge_target = 0.0)

func _play(kind: String) -> void:
	if active: AudioDirector.play_sfx("lane_smash_" + kind)

func _contact(kind: String) -> void:
	_play("cadence" if kind == "hold" else "collect")

func _section(kind: String) -> void:
	_play("power_finish" if kind == "burst" else "section")

func _blast(hit: bool, points: int) -> void:
	_play("impact" if hit else ("pass" if points > 0 else "avoid"))

func update_audio() -> void:
	var rules := track.rules
	var shot := rules.barrage.current_shot()
	if not shot.is_empty():
		if _shot_id != str(shot.shotId):
			_shot_id = str(shot.shotId)
			_fired = false
			_play("warning")
		if not _fired and rules.elapsed_ms >= int(shot.fireMs):
			_fired = true
			_play("launch")
	var event := rules.current_event()
	var charging: bool = active and AudioDirector.user_sfx_enabled and rules.pause_reason.is_empty() and not rules.barrage.active and event.get("type") == "burst" and rules.road_time_ms() >= int(event.get("startMs", 0)) and rules.settled_lane == int(event.get("laneIndex", -2)) and float(rules.latest.get("cadence", 0)) >= 20
	if charging:
		if not _charge.playing:
			_charge_gain = 0.0
			_charge.volume_db = -80
			_charge.play()
		_charge_target = db_to_linear(lerpf(-12, -3, clampf(rules.smoothed_power / 350.0, 0, 1)))
		_charge.pitch_scale = lerpf(0.85, 1.15, clampf(float(rules.latest.cadence) / 140.0, 0, 1))
	else: _charge_target = 0.0

func _process(delta: float) -> void:
	if not _charge.playing: return
	_charge_gain = lerpf(_charge_gain, _charge_target, 1.0 - exp(-delta * 32.0))
	_charge.volume_db = linear_to_db(maxf(0.0001, _charge_gain))
	if _charge_target == 0.0 and _charge_gain < 0.001: _charge.stop()

func suspend() -> void:
	active = false
	_charge_gain = 0.0
	_charge_target = 0.0
	_charge.stop()
