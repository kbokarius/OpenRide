class_name LaneSmashBenchmarkCard
extends VBoxContainer
## Fits the existing intro visual slot; all states reserve the same height.

var best_label: Label
var target_label: Label
var detail_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(1120, 174)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := LaneSmashMenuTheme.shared()
	best_label = look.label("Loading previous best…", 36, LaneSmashMenuTheme.TEXT_MUTED)
	target_label = look.label("", 52, GameTheme.TARGET)
	detail_label = look.label("", 30, LaneSmashMenuTheme.TEXT_MUTED)
	for label in [best_label, target_label, detail_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)


func show_benchmark(selection: Dictionary, ghost_enabled: bool, has_trace: bool, complete_trace := true) -> void:
	var best: Dictionary = selection.get("best", {})
	if best.is_empty():
		best_label.text = "No completed ride at this difficulty yet"
		target_label.text = "Set your first high score"
		detail_label.text = "Finish this ride to save your motorcycle ghost"
		return
	var score := int(best.scoreUnits) / NeonRules.UNIT
	best_label.text = "PREVIOUS BEST  %s" % HudTheme.grouped(score)
	target_label.text = "SCORE TO BEAT  %s" % HudTheme.grouped(score + 1)
	detail_label.text = "Race your best-ride ghost" if ghost_enabled and has_trace else ("Ghost is off in Settings" if not ghost_enabled else "This saved ride has no ghost recording")
	if ghost_enabled and has_trace and not complete_trace:
		detail_label.text = "Ghost recording is incomplete"
	if bool(selection.get("differentVersion", false)):
		detail_label.text += " · Different track version"


func show_error() -> void:
	best_label.text = "Previous best could not be loaded"
	target_label.text = "Ride storage unavailable"
	detail_label.text = "End this ride and try again"
