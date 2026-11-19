class_name NeonBenchmark
extends RefCounted
## Personal track benchmarks survive rules updates. Exact-version comparison keys and
## immutable saved courses still govern historical replay and formal record eligibility.

static func matches(row: Dictionary, rules: NeonRules, rider: String, exact_key := "") -> bool:
	if row.get("riderId", "") != rider: return false
	if row.get("courseId", "") != rules.course.courseId: return false
	if exact_key.is_empty(): exact_key = rules.comparison_key(rider)
	if row.get("comparisonKey", "") == exact_key: return true
	# Only distance-era scores in the same units, resistance bands and Kid cadence mode.
	# IDs include duration and random seed, so unrelated random tracks never share a ghost.
	return row.get("courseId", "") == rules.course.courseId \
		and int(row.get("durationMs", 0)) == int(rules.course.durationMs) \
		and row.get("difficulty", "") == rules.tier \
		and float(row.get("referencePower", -1)) == rules.reference_power \
		and int(row.get("scoreScale", -1)) == rules.score_scale \
		and int(row.get("envelopeVersion", -1)) == NeonRules.ENVELOPE_VERSION \
		and int(row.get("kidCadencePercent", 100)) == int(rules.course.get("kidCadencePercent", 100)) \
		and _same_bands(row.get("laneBands", []), rules.tier)


static func _same_bands(bands: Array, tier: String) -> bool:
	# JSON numbers are floats; Godot nested Array equality also compares numeric types.
	if bands.size() != 6: return false
	for lane in 6:
		if not bands[lane] is Array or bands[lane].size() != 2: return false
		var band := NeonRules.band(lane, tier)
		if float(bands[lane][0]) != band.x or float(bands[lane][1]) != band.y: return false
	return true


static func better(a: Dictionary, b: Dictionary) -> bool:
	if int(a.scoreUnits) != int(b.scoreUnits): return int(a.scoreUnits) > int(b.scoreUnits)
	if int(a.updatedMs) != int(b.updatedMs): return int(a.updatedMs) < int(b.updatedMs)
	return str(a.attemptId) < str(b.attemptId)


static func select(stats: Dictionary, rules: NeonRules, rider: String) -> Dictionary:
	var best := {}
	var last := {}
	var key := rules.comparison_key(rider)
	for stat: Dictionary in stats.values():
		var candidate: Dictionary = stat.get("best", {})
		if not candidate.is_empty() and candidate.get("status") == "completed" and matches(candidate, rules, rider, key):
			if best.is_empty() or better(candidate, best): best = candidate
		candidate = stat.get("last", {})
		if not candidate.is_empty() and candidate.get("status") in ["completed", "ended", "interrupted"] and matches(candidate, rules, rider, key):
			if last.is_empty() or int(candidate.updatedMs) > int(last.updatedMs) or (int(candidate.updatedMs) == int(last.updatedMs) and str(candidate.attemptId) > str(last.attemptId)):
				last = candidate
	return {"best": best, "last": last, "differentVersion": not best.is_empty() and best.comparisonKey != key}


static func menu_text(selection: Dictionary) -> String:
	var last: Dictionary = selection.last
	var best: Dictionary = selection.best
	if last.is_empty(): return "No previous ride at this difficulty"
	var text := "Last %s%s" % [HudTheme.grouped(int(last.scoreUnits) / NeonRules.UNIT), " (partial)" if last.status != "completed" else ""]
	text += "  ·  Best %s" % HudTheme.grouped(int(best.scoreUnits) / NeonRules.UNIT) if not best.is_empty() else "  ·  No completed best"
	if bool(selection.differentVersion): text += " · different version"
	return text
