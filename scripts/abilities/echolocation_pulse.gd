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
	emit_acoustic_pulse(radius)

	spawn_wave_visual(radius, travel_time)
	schedule_detection(wave_speed)
	show_message("Echolocation pulse released.")

	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(travel_time + cleanup_padding)
	cleanup_timer.timeout.connect(Callable(self, "queue_free"))


func emit_acoustic_pulse(radius: float) -> void:
	var manager: PerceptionStimulusManager = get_tree().get_first_node_in_group("perception_stimulus_manager") as PerceptionStimulusManager
	if manager == null:
		return
	var loudness: float = clampf(radius * 0.9, 12.0, 28.0)
	var tags: Array[String] = ["acoustic", "echolocation", "magic", "frequency:broadband", "reveals_source"]
	manager.emit_stimulus(origin_position, loudness, "echolocation", 1.25, source_actor, "Echolocation pulse", 1.5, tags)
	if source_actor != null:
		var stealth: Node = source_actor.get_node_or_null("StealthController")
		if stealth != null and stealth.has_method("report_acoustic_event"):
			stealth.call("report_acoustic_event", "echolocation", loudness)


func spawn_wave_visual(radius: float, lifetime: float) -> void:
	var sound_color: Color = ElementVisuals.get_element_color("sound")

	for index: int in range(3):
		var ring := ElementVisuals.add_torus(
			self,
			"SoundRing" + str(index),
			0.2,
			0.235,
			sound_color.lightened(float(index) * 0.12),
			Vector3(0.0, 0.2 + float(index) * 0.08, 0.0),
			Vector3.ZERO,
			2.0,
			0.62 - float(index) * 0.1
		)
		ring.scale = Vector3.ONE * (0.18 + float(index) * 0.08)

		var ring_tween := ring.create_tween()
		var delay: float = float(index) * 0.055
		if delay > 0.0:
			ring_tween.tween_interval(delay)
		ring_tween.tween_property(ring, "scale", Vector3.ONE * radius, lifetime)

	var vertical_a := ElementVisuals.add_torus(
		self,
		"ResonanceA",
		0.16,
		0.2,
		sound_color,
		Vector3(0.0, 0.47, 0.0),
		Vector3(90.0, 0.0, 0.0),
		2.4,
		0.54
	)
	var vertical_b := ElementVisuals.add_torus(
		self,
		"ResonanceB",
		0.16,
		0.2,
		sound_color,
		Vector3(0.0, 0.47, 0.0),
		Vector3(0.0, 0.0, 90.0),
		2.4,
		0.54
	)
	vertical_a.scale = Vector3.ONE * 0.2
	vertical_b.scale = Vector3.ONE * 0.2
	vertical_a.create_tween().tween_property(vertical_a, "scale", Vector3.ONE * radius * 0.72, lifetime)
	vertical_b.create_tween().tween_property(vertical_b, "scale", Vector3.ONE * radius * 0.72, lifetime)


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

	var raw_result: Variant = receiver.call("receive_detection", detection_payload)
	if not (raw_result is Dictionary):
		return
	var result: Dictionary = raw_result

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
