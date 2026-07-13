extends Node3D

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export var detection_payload: DetectionPayload
@export var pulse_lifetime: float = 0.48
@export var visual_radius_multiplier: float = 1.0

var origin_position: Vector3 = Vector3.ZERO


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	if detection_payload == null:
		detection_payload = DetectionPayload.new()

	origin_position = player.global_position
	global_position = origin_position
	emit_detection()
	play_pulse_visual()


func emit_detection() -> void:
	var detectable_nodes: Array[Node] = get_tree().get_nodes_in_group("detectable")
	var messages: Array[String] = []

	for receiver: Node in detectable_nodes:
		if receiver == null:
			continue

		if not receiver.has_method("receive_detection"):
			continue

		var target_position: Vector3 = get_receiver_position(receiver)
		var distance: float = origin_position.distance_to(target_position)

		if distance > detection_payload.radius:
			continue

		var result: Dictionary = receiver.receive_detection(detection_payload)

		if result.has("message") and result["message"] != "":
			messages.append(str(result["message"]))

	if messages.size() > 0:
		show_message("\n".join(messages))
	else:
		show_message(detection_payload.source_name + " echoes into silence.")


func get_receiver_position(receiver: Node) -> Vector3:
	if receiver is Node3D:
		return receiver.global_position

	var parent: Node = receiver.get_parent()

	if parent is Node3D:
		return parent.global_position

	return Vector3.ZERO


func play_pulse_visual() -> void:
	var pulse_radius: float = max(detection_payload.radius * visual_radius_multiplier, 0.5)
	ElementVisuals.spawn_sound_pulse(get_tree(), global_position + Vector3.UP * 0.1, pulse_radius, pulse_lifetime)

	var cleanup: Tween = create_tween()
	cleanup.tween_interval(pulse_lifetime + 0.12)
	cleanup.tween_callback(Callable(self, "queue_free"))


func show_message(text: String) -> void:
	print(text)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
