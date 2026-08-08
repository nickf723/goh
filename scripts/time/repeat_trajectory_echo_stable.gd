extends "res://scripts/time/repeat_trajectory_echo.gd"
class_name RepeatTrajectoryEchoStable


func _build_visual_shell() -> void:
	super._build_visual_shell()
	# Packed scenes run `_ready()` when added as the memory's child. A real
	# projectile may re-enable collision/processing there, so neutralize once more
	# after tree entry before freezing any physics body shell.
	_neutralize_recursive(visual_shell)
	_freeze_physics_shells(visual_shell)


func _freeze_physics_shells(node: Node) -> void:
	if node == null:
		return
	if node is RigidBody3D:
		var body := node as RigidBody3D
		body.freeze = true
		body.sleeping = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	for child: Node in node.get_children():
		_freeze_physics_shells(child)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["physical_visual_shells_frozen"] = true
	data["post_ready_renormalized"] = true
	return data
