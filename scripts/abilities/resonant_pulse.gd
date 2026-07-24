extends Node3D
class_name ResonantPulse

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export var resonance_payload: ResonancePayload
@export_range(0.1, 2.0, 0.05) var visual_lifetime: float = 0.55
@export var show_cast_message: bool = true

var source_actor: Node = null
var origin_position: Vector3 = Vector3.ZERO
var affected_body_ids: Dictionary = {}


func set_payload(new_payload: Resource) -> void:
	if new_payload is ResonancePayload:
		resonance_payload = new_payload as ResonancePayload


func set_source_actor(new_source_actor: Node) -> void:
	source_actor = new_source_actor


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	if player == null:
		queue_free()
		return
	if resonance_payload == null:
		resonance_payload = ResonancePayload.new()
	source_actor = player
	origin_position = player.global_position
	global_position = origin_position
	add_to_group("resonant_pulses")
	deliver_resonance()
	spawn_pulse_visual()
	if show_cast_message:
		show_message(
			resonance_payload.source_name
			+ " "
			+ str(int(round(resonance_payload.frequency_hz)))
			+ " Hz energized "
			+ str(affected_body_ids.size())
			+ " resonator(s)."
		)
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(
		maxf(visual_lifetime, 0.1) + 0.1
	)
	cleanup_timer.timeout.connect(Callable(self, "queue_free"))


func deliver_resonance() -> void:
	for candidate: Node in get_tree().get_nodes_in_group("resonant_bodies"):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not candidate.has_method("receive_resonance"):
			continue
		var candidate_id: int = candidate.get_instance_id()
		if affected_body_ids.has(candidate_id):
			continue
		var target_position: Vector3 = get_candidate_position(candidate)
		var distance: float = origin_position.distance_to(target_position)
		if distance > resonance_payload.radius:
			continue
		var raw_result: Variant = candidate.call(
			"receive_resonance",
			resonance_payload,
			distance
		)
		if raw_result is Dictionary:
			var result: Dictionary = raw_result as Dictionary
			if float(result.get("added_energy", 0.0)) > 0.01:
				affected_body_ids[candidate_id] = true


func get_candidate_position(candidate: Node) -> Vector3:
	if candidate.has_method("get_owner_position"):
		var value: Variant = candidate.call("get_owner_position")
		if value is Vector3:
			return value as Vector3
	if candidate is Node3D:
		return (candidate as Node3D).global_position
	var parent: Node = candidate.get_parent()
	if parent is Node3D:
		return (parent as Node3D).global_position
	return Vector3.ZERO


func spawn_pulse_visual() -> void:
	var sound_color: Color = ElementVisuals.get_element_color("sound")
	var frequency_ratio: float = inverse_lerp(
		110.0,
		660.0,
		clampf(resonance_payload.frequency_hz, 110.0, 660.0)
	)
	var tuned_color: Color = sound_color.lerp(
		Color(1.0, 0.82, 0.24, 1.0),
		frequency_ratio
	)
	for index: int in range(4):
		var ring: MeshInstance3D = ElementVisuals.add_torus(
			self,
			"FrequencyRing" + str(index),
			0.16,
			0.205,
			tuned_color.lightened(float(index) * 0.08),
			Vector3(0.0, 0.3 + float(index) * 0.08, 0.0),
			Vector3.ZERO,
			2.4,
			0.7 - float(index) * 0.1
		)
		ring.scale = Vector3.ONE * (0.18 + float(index) * 0.07)
		var tween: Tween = ring.create_tween()
		if index > 0:
			tween.tween_interval(float(index) * 0.045)
		tween.tween_property(
			ring,
			"scale",
			Vector3.ONE * resonance_payload.radius,
			maxf(visual_lifetime, 0.1)
		)


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"resonant_pulse": true,
		"frequency_hz": (
			resonance_payload.frequency_hz
			if resonance_payload != null
			else 0.0
		),
		"energy": (
			resonance_payload.energy
			if resonance_payload != null
			else 0.0
		),
		"radius": (
			resonance_payload.radius
			if resonance_payload != null
			else 0.0
		),
		"affected": affected_body_ids.size(),
	}

