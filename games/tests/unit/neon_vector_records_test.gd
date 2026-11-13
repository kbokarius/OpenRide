extends GdUnitTestSuite

var _old_path := ""


func before_test() -> void:
	_old_path = NeonRecords.path
	NeonRecords.path = "user://test_neon_%s" % NeonRecords.new_id()


func after_test() -> void:
	for file in DirAccess.get_files_at(NeonRecords.path):
		DirAccess.remove_absolute(NeonRecords.path.path_join(file))
	DirAccess.remove_absolute(NeonRecords.path)
	NeonRecords.path = _old_path


func _record(rider: String = "1", key: String = "a", course_id: String = "steady_flow_10") -> Dictionary:
	return {"version": 1, "attemptId": NeonRecords.new_id(), "riderId": rider,
		"comparisonKey": key.repeat(64), "course": {"courseId": course_id, "durationMs": 600000},
		"result": {"status": "pending", "activeDurationMs": 0, "scoreUnits": 0, "stars": 0, "courseId": course_id}, "ghost": []}


func _save(record: Dictionary) -> Dictionary:
	return NeonRecords.local_request({"action": "save", "record": record}, str(record.riderId))


func _finish(record: Dictionary, score: int = 100) -> void:
	assert_bool(_save(record).ok).is_true()
	record.result.status = "completed"
	record.result.activeDurationMs = 600000
	record.result.scoreUnits = score
	record.result.stars = 3
	record.ghost = [[100, 0, 0], [600000, 3, score]]
	assert_bool(_save(record).ok).is_true()


func test_checkpoint_crash_recovery_never_creates_a_record_or_unlock() -> void:
	var record := _record()
	assert_bool(_save(record).ok).is_true()
	record.result.activeDurationMs = 20000
	record.result.scoreUnits = 300
	assert_bool(_save(record).ok).is_true()
	NeonRecords._recovered_path = ""  # another process opens the same files
	var state := NeonRecords.local_request({"action": "state"}, "1")
	assert_int(state.completions).is_zero()
	assert_str(state.history[0].result.status).is_equal("interrupted")
	assert_int(int(state.history[0].result.scoreUnits)).is_equal(300)
	assert_dict(NeonRecords.local_request({"action": "best", "key": record.comparisonKey}, "1").record).is_empty()
	assert_str(_save(record).status).is_equal("interrupted")


func test_final_result_is_idempotent_and_immutable_after_late_checkpoint() -> void:
	var record := _record()
	_finish(record)
	assert_str(_save(record).status).is_equal("completed")
	record.result.status = "pending"
	record.result.activeDurationMs = 100
	record.ghost = []
	assert_str(_save(record).status).is_equal("completed")
	assert_int(NeonRecords.local_request({"action": "state"}, "1").completions).is_equal(1)


func test_bests_are_isolated_by_rider_and_comparison_key_and_keep_exact_ghost() -> void:
	var original := _record()
	_finish(original, 100)
	_finish(_record("1", "b"), 900)
	_finish(_record("2", "a"), 800)
	var newer := _record()
	_finish(newer, 200)
	var best: Dictionary = NeonRecords.local_request({"action": "best", "key": original.comparisonKey}, "1").record
	assert_str(best.attemptId).is_equal(newer.attemptId)
	assert_int(int(best.ghost[-1][2])).is_equal(200)
	assert_int(int(best.ghost[-1][1])).is_equal(3)
	assert_bool(NeonRecords.local_request({"action": "get", "attemptId": newer.attemptId}, "2").ok).is_false()


func test_tutorial_and_partial_rides_do_not_unlock_cosmetics() -> void:
	_finish(_record("1", "a", "tutorial"))
	var partial := _record()
	assert_bool(_save(partial).ok).is_true()
	partial.result.status = "ended"
	partial.result.scoreUnits = 100
	assert_bool(_save(partial).ok).is_true()
	var state := NeonRecords.local_request({"action": "state"}, "1")
	assert_int(state.completions).is_zero()
	assert_int(state.history.size()).is_equal(2)
	for count in [0, 3, 7, 12]:
		assert_bool(NeonWorlds.unlocked("arctic", count)).is_true()
	assert_bool(NeonWorlds.unlocked("cobalt", 0)).is_true()
	assert_bool(NeonWorlds.unlocked("cobalt", 3)).is_true()
	assert_bool(NeonWorlds.unlocked("comet", 9, true)).is_false()
	assert_bool(NeonWorlds.unlocked("comet", 10, true)).is_true()


func test_invalid_record_identity_ghost_and_backward_checkpoints_are_rejected() -> void:
	var record := _record()
	record.attemptId = "../escape"
	assert_bool(_save(record).ok).is_false()
	record.attemptId = NeonRecords.new_id()
	assert_bool(_save(record).ok).is_true()
	record.result.activeDurationMs = 20000
	assert_bool(_save(record).ok).is_true()
	record.result.activeDurationMs = 100
	assert_bool(_save(record).ok).is_false()
	record.result.activeDurationMs = 20000
	record.ghost = [[100, 0, 0], [90, 0, 0]]
	assert_bool(_save(record).ok).is_false()
	record.ghost = []
	record.comparisonKey = "b".repeat(64)
	assert_bool(_save(record).ok).is_false()
