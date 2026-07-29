extends "res://scripts/player/player_status_receiver.gd"
class_name PlayerStatusReceiverDivineSpecial


func apply_status(
	status_name: String,
	duration: float,
	strength: float = 1.0,
	source: String = "unknown"
) -> void:
	var normalized_status: String = status_name.strip_edges().to_lower()
	if _hearth_blocks_status(normalized_status):
		remove_status(normalized_status)
		last_result = "blocked_by_hearth:" + normalized_status
		total_blocked_statuses += 1
		status_blocked.emit(normalized_status, source)
		return
	super.apply_status(status_name, duration, strength, source)


func sustain_status(
	status_name: String,
	duration: float,
	strength: float = 1.0,
	source: String = "unknown"
) -> void:
	var normalized_status: String = status_name.strip_edges().to_lower()
	if _hearth_blocks_status(normalized_status):
		remove_status(normalized_status)
		last_result = "blocked_by_hearth:" + normalized_status
		total_blocked_statuses += 1
		status_blocked.emit(normalized_status, source)
		return
	super.sustain_status(status_name, duration, strength, source)


func prune_blocked_statuses() -> int:
	var removed: int = super.prune_blocked_statuses()
	if _hearth_blocks_status("burning") and has_status("burning"):
		remove_status("burning")
		removed += 1
	return removed


func _hearth_blocks_status(status_name: String) -> bool:
	var actor: Node = get_parent()
	return (
		status_name == "burning"
		and actor != null
		and bool(actor.get_meta("divine_special_fire_immunity", false))
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["hearth_fire_immunity"] = _hearth_blocks_status("burning")
	return data
