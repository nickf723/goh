extends "res://scripts/actions/metal_needle_fan.gd"
class_name MetalNeedleFanReady

# The shared fan owns movement, collision, payloads, and presentation. The
# production authority gives the rapid sequence a readable center-out rhythm and
# reasserts world-space presentation before the action computes its launch line.


func execute(player: Node3D, requested_direction: Vector3) -> void:
	global_transform = Transform3D.IDENTITY
	super.execute(player, requested_direction)


func _build_needle_states() -> void:
	super._build_needle_states()
	var center_index: int = floori(float(needle_count) * 0.5)
	for needle_index: int in range(needle_count):
		var launch_rank: int = 0
		if needle_index < center_index:
			launch_rank = (center_index - needle_index) * 2 - 1
		elif needle_index > center_index:
			launch_rank = (needle_index - center_index) * 2
		needle_launch_times[needle_index] = (
			float(launch_rank) * launch_interval_seconds
		)


func get_launch_order() -> Array[int]:
	var order: Array[int] = []
	for launch_rank: int in range(needle_count):
		for needle_index: int in range(needle_count):
			if is_equal_approx(
				needle_launch_times[needle_index],
				float(launch_rank) * launch_interval_seconds
			):
				order.append(needle_index)
				break
	return order


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["center_out_launch"] = true
	data["launch_order"] = get_launch_order()
	data["world_space_multimesh"] = true
	return data
