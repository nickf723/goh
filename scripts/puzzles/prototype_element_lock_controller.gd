extends Node

signal puzzle_completed
signal puzzle_reset

@export var target_group_name: String = "element_lock_target"
@export var gate_path: NodePath
@export var puzzle_complete_message: String = "The element lock opens."
@export var objective_after: String = "Reach the final exit."

var puzzle_complete: bool = false
var hooked_targets: Array[Node] = []
var completion_count: int = 0


func _ready() -> void:
	await get_tree().process_frame
	hook_targets()
	check_targets()


func hook_targets() -> void:
	hooked_targets.clear()
	for target: Node in get_tree().get_nodes_in_group(target_group_name):
		hooked_targets.append(target)
		if target.has_signal("target_activated"):
			var callback := Callable(self, "_on_target_activated")
			if not target.is_connected("target_activated", callback):
				target.connect("target_activated", callback)


func _on_target_activated(_target: Node) -> void:
	check_targets()


func check_targets() -> void:
	if puzzle_complete:
		return
	var targets: Array[Node] = get_tree().get_nodes_in_group(target_group_name)
	if targets.is_empty():
		return
	for target: Node in targets:
		if not target.has_method("is_active"):
			return
		if not bool(target.call("is_active")):
			return
	complete_puzzle()


func complete_puzzle() -> void:
	if puzzle_complete:
		return
	puzzle_complete = true
	completion_count += 1
	unlock_gate()
	show_message(puzzle_complete_message)
	set_objective(objective_after)
	puzzle_completed.emit()


func reset_puzzle_state() -> void:
	puzzle_complete = false
	puzzle_reset.emit()


func unlock_gate() -> void:
	var gate: Node = get_node_or_null(gate_path)
	if gate != null and gate.has_method("unlock"):
		gate.call("unlock")


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)


func set_objective(text: String) -> void:
	GameState.set_objective(text)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text)


func get_debug_data() -> Dictionary:
	return {
		"complete": puzzle_complete,
		"targets": get_tree().get_nodes_in_group(target_group_name).size(),
		"completion_count": completion_count,
	}
