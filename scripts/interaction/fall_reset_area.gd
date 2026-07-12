extends Area3D
class_name FallResetArea

@export var reset_marker_path: NodePath
@export var reset_message: String = "Grace catches the edge of the echo and returns to solid ground."
@export var reset_objective: String = "Use Sound Pulse to reveal the path, then cross while it remains visible."

var reset_in_progress: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if reset_in_progress:
		return

	if body == null or not body.is_in_group("player"):
		return

	var marker: Node3D = get_node_or_null(reset_marker_path) as Node3D

	if marker == null:
		push_warning("FallResetArea has no valid reset marker.")
		return

	reset_in_progress = true
	call_deferred("_reset_player", body, marker.global_position)


func _reset_player(body: Node3D, reset_position: Vector3) -> void:
	if body == null or not is_instance_valid(body):
		reset_in_progress = false
		return

	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO

	body.global_position = reset_position
	show_feedback()

	await get_tree().create_timer(0.25).timeout
	reset_in_progress = false


func show_feedback() -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui == null:
		print(reset_message)
		return

	if ui.has_method("show_message"):
		ui.show_message(reset_message)

	if ui.has_method("set_objective"):
		ui.set_objective(reset_objective)
