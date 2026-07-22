extends Node3D
class_name EcholocationPulse

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export var detection_payload: DetectionPayload
@export_range(1.0, 60.0, 0.5) var wave_speed_meters_per_second: float = 18.0
@export_range(0.1, 3.0, 0.05) var minimum_visual_lifetime: float = 0.35
@export_range(0.05, 2.0, 0.05) var cleanup_padding: float = 0.35
@export var detectable_group: String = "detectable"
@export var show_reveal_messages: bool = true

var source_actor: Node = null
var origin_position: Vector3 = Vector3.ZERO
var delivered_receiver_ids: Dictionary = {}


func set_payload(new_payload: Resource) -> void:
	if new_payload is DetectionPayload:
		detection_payload = new_payload as DetectionPayload


func set_source_actor(new_source_actor: Node) -> void:
	source_actor = new_source_actor


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	if player == null:
		queue_free()
		return

	if detection_payload == null:
		detection_payload = DetectionPayload.new()

	source_actor = player
	origin_position = player.global_position
	global_position = origin_position
	add_to_group("echolocation_pulses")

	var radius: float = max(detection_payload.radius, 0.5)
	var wave_speed: float = max(wave_speed_meters_per_second, 0.1)
	var travel_time: float = max(radius / wave_speed, minimum_visual_lifetime)

	ElementVisuals.spawn_sound_pulse(
		get_tree(),
		origin_position + Vector3.UP * 0.12,
		radius,
		travel_time
	)
	schedule_detection(wave_speed)
	show_message("Echolocation pulse released.")

	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(travel_time + cleanup_padding)
	cleanup_timer.timeout.connect(Callable(self, "queue_free"))


func schedule_detection(wave_speed: float) -> void:
	for receiver: Node in get_tree().get_nodes_in_group(detectable_group):
		if receiver == null or not is_instance_valid(receiver):
			continue
		if not receiver.has_method("receive_detection"):
			continue

		var target_position: Vector3 = get_receiver_position(receiver)
		var distance: float = origin_position.distance_to(target_position)
		if distance > detection_payload.radius:
			continue

		var delay: float = max(distance / wave_speed, 0.0)
		var delivery_timer: SceneTreeTimer = get_tree().create_timer(delay)
		delivery_timer.timeout.connect(
			Callable(self, "deliver_detection").bind(receiver)
		)


func deliver_detection(receiver: Node) -> void:
	if receiver == null or not is_instance_valid(receiver):
		return
	if not receiver.has_method("receive_detection"):
		return

	var receiver_id: int = receiver.get_instance_id()
	if delivered_receiver_ids.has(receiver_id):
		return
	delivered_receiver_ids[receiver_id] = true

	var result: Dictionary = receiver.call("receive_detection", detection_payload) as Dictionary
	if not show_reveal_messages:
		return

	var message: String = str(result.get("message", ""))
	if message != "":
		show_message(message)


func get_receiver_position(receiver: Node) -> Vector3:
	if receiver is Node3D:
		return (receiver as Node3D).global_position

	var parent: Node = receiver.get_parent()
	if parent is Node3D:
		return (parent as Node3D).global_position

	return Vector3.ZERO


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"echolocation_pulse": true,
		"origin": origin_position,
		"radius": detection_payload.radius if detection_payload != null else 0.0,
		"wave_speed": wave_speed_meters_per_second,
		"delivered": delivered_receiver_ids.size(),
	}
