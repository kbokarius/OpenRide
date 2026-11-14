class_name NeonLocalInput
extends RefCounted
## Desktop mirror of BikeSampleBuffer + NeonTimeline. Explicit now arguments enable tests.

## The longest gap between two polls that is caught up without pausing the ride; mirrors
## `NeonTimeline.STALL_MS` in the app. Shorter hitches lose no input: every sample in that time
## is replayed with its own timestamp.
const STALL_MS := 1000

var samples: Array[Dictionary] = []
var sequence := 0
var active := false
var running := false
var acknowledged := 0
var duration := 0
var origin := 0
var epoch := 0
var reason := ""
var last_poll := 0


func record(now: int, cadence: float, power: float, resistance: float, connected: bool = true) -> void:
	if not connected or (not samples.is_empty() and now - int(samples[-1].received_ms) < 50):
		return
	sequence += 1
	samples.append({"received_ms": now, "seq": sequence, "cadence": cadence, "power": power, "resistance": resistance})
	while samples.size() > 1 and int(samples[0].received_ms) < now - 5000:
		samples.pop_front()


func control(action: String, processed: int, duration_ms: int, now: int) -> void:
	match action:
		"begin":
			if duration_ms <= 0 or duration_ms > 1800000 or duration_ms % 10 != 0:
				return
			active = true
			running = true
			acknowledged = 0
			duration = duration_ms
			origin = now
			last_poll = now
			epoch += 1
			reason = ""
		"ack", "pause":
			var available := mini(duration, now - origin) if running else acknowledged
			if active and processed >= acknowledged and processed <= available and processed % 10 == 0:
				acknowledged = processed
			if action == "pause" and running:
				running = false
				reason = "manual"
		"resume":
			if active and not running:
				origin = now - acknowledged
				last_poll = now
				epoch += 1
				running = true
				reason = ""
		"stop":
			active = false
			running = false
			reason = ""


func batch(after_sequence: int, now: int) -> Dictionary:
	while samples.size() > 1 and int(samples[0].received_ms) < now - 5000:
		samples.pop_front()
	var age := now - int(samples[-1].received_ms) if not samples.is_empty() else 2147483647
	var overflow := after_sequence >= 0 and not samples.is_empty() and after_sequence < int(samples[0].seq) - 1
	if running:
		if overflow or age > 1500 or now - last_poll > STALL_MS:
			running = false
			reason = "overflow" if overflow else ("sensor" if age > 1500 else "stall")
	last_poll = now
	var output: Array[Dictionary] = []
	if after_sequence < 0 and not samples.is_empty():
		output.append(samples[-1].duplicate())
	else:
		for sample in samples:
			if int(sample.seq) > after_sequence:
				output.append(sample.duplicate())
	return {"version": 1, "now_ms": now, "sample_age_ms": age, "sequence": sequence,
		"overflow": overflow, "fresh": age <= 1500, "active": active, "running": running,
		"elapsed_ms": mini(duration, now - origin) if running else acknowledged,
		"origin_ms": origin, "epoch": epoch, "pause_reason": reason, "samples": output}
