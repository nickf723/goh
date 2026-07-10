extends Node3D
class_name GenericPulse

@export var payload: Resource

@export var default_radius: float = 8.0
@export var pulse_lifetime: float = 0.35
@export var visual_start_scale: Vector3 = Vector3(0.2, 0.2, 0.2)
@export var visual_end_scale: Vector3 = Vector3(8.0, 8.0, 8.0)

@export var detect_group: String = "detectable"
@export var hit_group: String = ""

@export var show_debug_prints: bool = false

var runtime_payload: Resource
var source_actor: Node
var origin_position: Vector3 = Vector3.ZERO


func set_payload(new_payload: Resource) -> void:
	runtime_payload = new_payload

func set_source_actor(new_source_actor: Node) -> void:
	source_actor = new_source_actor

func get_payload() -> Resource:
	if runtime_payload != null:
		return runtime_payload

	return payload

func execute(player: Node3D, _cast_direction: Vector3) -> void:
	origin_position = player.global_position
	global_position = origin_position

	var action_payload: Resource = get_payload()

	if action_payload is DetectionPayload:
		emit_detection(action_payload as DetectionPayload)
	elif action_payload is DamagePayload:
		emit_damage(action_payload as DamagePayload)
	else:
		show_message("Generic Pulse has no usable payload.")

	play_pulse_visual(action_payload)

func emit_detection(detection_payload: DetectionPayload) -> void:
	var detectable_nodes: Array[Node] = get_tree().get_nodes_in_group(detect_group)
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

func emit_damage(damage_payload: DamagePayload) -> void:
	var radius: float = default_radius
	var candidate_nodes: Array[Node] = get_damage_candidates()
	var messages: Array[String] = []
	var seen_ids: Dictionary = {}

	for candidate: Node in candidate_nodes:
		var target: Node = find_payload_target(candidate)

		if target == null:
			continue

		if should_ignore_target(target):
			continue

		var target_id: int = target.get_instance_id()

		if seen_ids.has(target_id):
			continue

		seen_ids[target_id] = true

		var target_position: Vector3 = get_receiver_position(target)
		var distance: float = origin_position.distance_to(target_position)

		if distance > radius:
			continue

		var result: Dictionary = send_damage_to_target(target, damage_payload)

		if result.has("message") and result["message"] != "":
			messages.append(str(result["message"]))

	if messages.size() > 0:
		show_message("\n".join(messages))
	else:
		show_message(damage_payload.source_name + " pulses through empty air.")

func get_damage_candidates() -> Array[Node]:
	if hit_group != "":
		return get_tree().get_nodes_in_group(hit_group)

	var candidates: Array[Node] = []
	candidates.append_array(get_tree().get_nodes_in_group("enemy"))
	candidates.append_array(get_tree().get_nodes_in_group("debuggable"))

	return candidates

func find_payload_target(start_node: Node) -> Node:
	var current: Node = start_node

	while current != null:
		if is_payload_target(current):
			return current

		current = current.get_parent()

	return null

func is_payload_target(node: Node) -> bool:
	if node.get_node_or_null("PayloadReceiver") != null:
		return true

	if node.get_node_or_null("HitReceiver") != null:
		return true

	if node.has_method("receive_damage_payload"):
		return true

	return false

func should_ignore_target(target: Node) -> bool:
	if source_actor == null:
		return false

	if target == source_actor:
		return true

	if source_actor.is_ancestor_of(target):
		return true

	return false

func send_damage_to_target(target: Node, damage_payload: DamagePayload) -> Dictionary:
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")

	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return payload_receiver.receive_payload(damage_payload)

	if target.has_method("receive_damage_payload"):
		return target.receive_damage_payload(damage_payload)

	var hit_receiver: Node = target.get_node_or_null("HitReceiver")

	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		return hit_receiver.receive_payload(damage_payload)

	return {
		"message": damage_payload.source_name + " hits " + target.name + ", but nothing receives it.",
		"objective": ""
	}

func get_receiver_position(receiver: Node) -> Vector3:
	if receiver is Node3D:
		return receiver.global_position

	var parent: Node = receiver.get_parent()

	if parent is Node3D:
		return parent.global_position

	return Vector3.ZERO

func play_pulse_visual(action_payload: Resource) -> void:
	var mesh: MeshInstance3D = get_node_or_null("PulseVisual")

	if mesh == null:
		queue_free()
		return

	mesh.visible = true
	mesh.scale = visual_start_scale

	var final_scale: Vector3 = visual_end_scale

	if action_payload is DetectionPayload:
		var detection_payload: DetectionPayload = action_payload as DetectionPayload
		final_scale = Vector3.ONE * detection_payload.radius

	var tween: Tween = create_tween()
	tween.tween_property(mesh, "scale", final_scale, pulse_lifetime)
	tween.finished.connect(queue_free)

func show_message(text: String) -> void:
	if show_debug_prints:
		print(text)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
