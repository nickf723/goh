extends "res://scripts/ui/full_menu_shell_familiar_detail.gd"
class_name FullMenuShellFeedbackV1


func activate_action(action: Dictionary) -> void:
	if str(action.get("kind", "")) == "select_codex_record":
		var record_id: String = str(action.get("record_id", ""))
		if (
			record_id != ""
			and record_id == selected_codex_record_id
			and selected_codex_category == "challenges"
		):
			var row: Dictionary = _find_codex_row(
				_get_progression_challenge_rows(),
				record_id
			)
			var challenge_id: String = str(row.get("challenge_id", ""))
			var tracker: Node = _get_progression_tracker()
			if (
				challenge_id != ""
				and tracker != null
				and tracker.has_method("track_challenge")
				and bool(tracker.call("track_challenge", challenge_id))
			):
				rebuild_menu()
				return
	super.activate_action(action)


func get_codex_debug_data() -> Dictionary:
	var data: Dictionary = super.get_codex_debug_data()
	var tracker: Node = _get_progression_tracker()
	var tracked: Dictionary = {}
	if tracker != null and tracker.has_method("get_tracked_progress_row"):
		var tracked_value: Variant = tracker.call("get_tracked_progress_row")
		if tracked_value is Dictionary:
			tracked = (tracked_value as Dictionary).duplicate(true)
	data["tracked_progress"] = tracked
	data["challenge_pinning"] = true
	return data
