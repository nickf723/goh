extends "res://scripts/time/repeat_echo_controller_full_timeline.gd"
class_name RepeatEchoControllerTimeMemory

const StableTrajectoryEchoScript = preload(
	"res://scripts/time/repeat_trajectory_echo_stable.gd"
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
	return data
