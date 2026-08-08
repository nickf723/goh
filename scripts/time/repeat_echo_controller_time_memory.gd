extends "res://scripts/time/repeat_echo_controller_full_timeline.gd"
class_name RepeatEchoControllerTimeMemory

const StableTrajectoryEchoScript = preload(
	"res://scripts/time/repeat_trajectory_echo_stable.gd"
)


func _on_scene_node_added(node: Node) -> void:
	if _belongs_to_clone_memory(node):
		return
	super._on_scene_node_added(node)


func _belongs_to_clone_memory(node: Node) -> bool:
	var current: Node = node
	while current != null:
		if bool(current.get_meta("clone_spell_replay", false)):
			return true
		if current.is_in_group("clone_spell_replays"):
			return true
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return false


func _repeat_is_still_concentrated() -> bool:
	if concentration_manager == null or not is_instance_valid(concentration_manager):
		return false
	if concentration_manager.has_method("has_effect"):
		return bool(concentration_manager.call("has_effect", "repeat_concentration"))
	var active_value: Variant = concentration_manager.get("active_effect")
	return (
		active_value is Resource
		and str((active_value as Resource).get("effect_id"))
		== "repeat_concentration"
	)


func _spawn_trajectory_echo(
	record: Dictionary,
	echo: RepeatEchoActor
) -> RepeatTrajectoryEcho:
	var ability_value: Variant = record.get("ability")
	if not ability_value is AbilityDefinition:
		return null
	var trajectory := StableTrajectoryEchoScript.new() as RepeatTrajectoryEchoStable
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	trajectory.set_meta("clone_spell_replay", true)
	trajectory.set_meta("repeat_memory_root", true)
	scene_root.add_child(trajectory)
	var payload_value: Variant = record.get("payload")
	trajectory.configure(
		ability_value as AbilityDefinition,
		echo,
		payload_value as Resource if payload_value is Resource else null
	)
	return trajectory


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["time_memory_authority"] = true
	data["physical_replay_shells_frozen"] = true
	data["clone_subtree_recording_guard"] = true
	data["multi_concentration_aware"] = true
	return data
