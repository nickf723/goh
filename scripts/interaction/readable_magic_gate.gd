extends StaticBody3D

@export var gate_name: String = "Readable Magic Gate"
@export var unlock_message: String = "The magic barrier fades."
@export var barrier_path: NodePath = NodePath("Barrier")
@export var collision_path: NodePath = NodePath("BarrierCollision")
@export var frame_stays_after_unlock: bool = true

var is_unlocked: bool = false


func _ready() -> void:
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
	var barrier: Node = get_node_or_null(barrier_path)

	if barrier != null:
		if barrier is Node3D:
			(barrier as Node3D).visible = false
		elif barrier is CanvasItem:
			(barrier as CanvasItem).visible = false

	var collision_node: Node = get_node_or_null(collision_path)

	if collision_node is CollisionShape3D:
		(collision_node as CollisionShape3D).disabled = true


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)


func get_debug_data() -> Dictionary:
	return {
		"gate": gate_name,
		"unlocked": is_unlocked,
		"frame_stays": frame_stays_after_unlock,
	}
