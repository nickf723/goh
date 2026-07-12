extends StaticBody3D

@export var gate_name: String = "Readable Magic Gate"
@export var unlock_message: String = "The magic barrier fades."
@export var barrier_path: NodePath = NodePath("Barrier")
@export var collision_path: NodePath = NodePath("BarrierCollision")
@export var frame_stays_after_unlock: bool = true
@export var auto_add_encounter_reward_group: bool = true

var is_unlocked: bool = false


func _ready() -> void:
	if auto_add_encounter_reward_group:
		add_to_group("encounter_reward")


func unlock() -> void:
	if is_unlocked:
		return

	is_unlocked = true
	disable_barrier()
	show_message(unlock_message)

	if not frame_stays_after_unlock:
		queue_free()


func disable_barrier() -> void:
	hide_barrier_visual()
	disable_gate_collision()


func hide_barrier_visual() -> void:
	var barrier: Node = get_node_or_null(barrier_path)

	if barrier is Node3D:
		var barrier_3d: Node3D = barrier as Node3D
		barrier_3d.visible = false
	elif barrier is CanvasItem:
		var barrier_canvas_item: CanvasItem = barrier as CanvasItem
		barrier_canvas_item.visible = false


func disable_gate_collision() -> void:
	# Clear the body itself first. This protects gate instances even if a collision
	# shape is renamed, inherited, duplicated, or nested deeper than expected.
	collision_layer = 0
	collision_mask = 0
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	var named_collision: Node = get_node_or_null(collision_path)

	if named_collision is CollisionShape3D:
		disable_collision_shape(named_collision as CollisionShape3D)

	disable_collision_shapes_recursive(self)


func disable_collision_shapes_recursive(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CollisionShape3D:
			disable_collision_shape(child as CollisionShape3D)

		disable_collision_shapes_recursive(child)


func disable_collision_shape(collision_shape: CollisionShape3D) -> void:
	collision_shape.disabled = true
	collision_shape.set_deferred("disabled", true)


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)


func get_debug_data() -> Dictionary:
	return {
		"gate": gate_name,
		"unlocked": is_unlocked,
		"frame_stays": frame_stays_after_unlock,
		"encounter_reward": auto_add_encounter_reward_group,
		"collision_layer": collision_layer,
		"collision_mask": collision_mask,
	}
