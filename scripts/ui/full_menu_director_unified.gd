extends "res://scripts/ui/full_menu_director.gd"
class_name FullMenuDirectorUnified

const UnifiedProgressionFeedbackHUDScript = preload(
	"res://scripts/progression/progression_feedback_hud_unified.gd"
)


func _ensure_progression_feedback_hud(tracker: Node = null) -> CanvasLayer:
	var feedback: CanvasLayer = get_node_or_null("ProgressionFeedbackHUD") as CanvasLayer
	if feedback != null:
		var script_value: Script = feedback.get_script() as Script
		if (
			script_value != null
			and script_value.resource_path
			== "res://scripts/progression/progression_feedback_hud_unified.gd"
		):
			if tracker == null:
				tracker = _ensure_progression_tracker()
			if feedback.has_method("bind_tracker"):
				feedback.call("bind_tracker", tracker)
			return feedback
		remove_child(feedback)
		feedback.queue_free()
	feedback = UnifiedProgressionFeedbackHUDScript.new() as CanvasLayer
	feedback.name = "ProgressionFeedbackHUD"
	feedback.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(feedback)
	if tracker == null:
		tracker = _ensure_progression_tracker()
	if feedback.has_method("bind_tracker"):
		feedback.call("bind_tracker", tracker)
	return feedback


func get_unified_director_debug_data() -> Dictionary:
	var feedback: Node = get_node_or_null("ProgressionFeedbackHUD")
	return {
		"unified_progression_feedback": (
			feedback != null
			and feedback.get_script() != null
			and (feedback.get_script() as Script).resource_path
			== "res://scripts/progression/progression_feedback_hud_unified.gd"
		),
	}
