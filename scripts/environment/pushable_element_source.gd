extends CharacterBody3D
class_name PushableElementSource

@export var source_label: String = "Pushable Element Source"
@export var gravity_strength: float = 20.0
@export var resettable: bool = true

var initial_transform: Transform3D


func _ready() -> void:
	initial_transform = transform
	add_to_group("debuggable")
	if resettable:
		add_to_group("lab_resettable")


func _physics_process(delta: float) -> void:
	var force_receiver: ForceReceiver = get_node_or_null("ForceReceiver") as ForceReceiver
	var external_velocity: Vector3 = Vector3.ZERO
	if force_receiver != null:
		external_velocity = force_receiver.consume_external_velocity(delta)

	velocity.x = external_velocity.x
	velocity.z = external_velocity.z

	if is_on_floor():
		velocity.y = max(external_velocity.y, 0.0)
	else:
		velocity.y += external_velocity.y
		velocity.y -= gravity_strength * delta

	move_and_slide()


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	var payload_receiver: Node = get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return payload_receiver.receive_payload(payload)
	return {
		"message": source_label + " receives a payload, but its receiver is missing.",
		"objective": "",
	}


func get_emitter() -> ElementEmitter:
	return get_node_or_null("ElementEmitter") as ElementEmitter


func set_source_active(is_active: bool) -> void:
	var emitter: ElementEmitter = get_emitter()
	if emitter != null:
		emitter.set_emitting(is_active)
	update_source_visual(is_active)


func request_element_units(requested_units: float) -> float:
	var emitter: ElementEmitter = get_emitter()
	if emitter == null:
		return 0.0
	return emitter.request_element_units(requested_units)


func reset_source() -> void:
	transform = initial_transform
	velocity = Vector3.ZERO

	var force_receiver: ForceReceiver = get_node_or_null("ForceReceiver") as ForceReceiver
	if force_receiver != null:
		force_receiver.external_velocity = Vector3.ZERO
		force_receiver.last_force_summary = "none"

	var status_receiver: Node = get_node_or_null("StatusReceiver")
	if status_receiver != null and status_receiver.has_method("clear_all_statuses"):
		status_receiver.clear_all_statuses()

	var emitter: ElementEmitter = get_emitter()
	if emitter != null:
		emitter.reset_emitter()
	update_source_visual(emitter.active if emitter != null else true)


func reset_target() -> void:
	reset_source()


func update_source_visual(is_active: bool) -> void:
	var flame_root: Node3D = get_node_or_null("VisualRoot/FlameRoot") as Node3D
	if flame_root != null:
		flame_root.visible = is_active

	var source_light: Light3D = get_node_or_null("SourceLight") as Light3D
	if source_light != null:
		source_light.visible = is_active


func interact() -> Dictionary:
	var emitter: ElementEmitter = get_emitter()
	var state_text: String = "inactive"
	if emitter != null and emitter.active:
		state_text = emitter.element + " source active"
	return {
		"message": source_label + " | " + state_text + " | push with weapon force.",
		"objective": "Move environmental ingredients into contact to trigger reactions.",
	}


func get_debug_data() -> Dictionary:
	var emitter: ElementEmitter = get_emitter()
	var force_receiver: ForceReceiver = get_node_or_null("ForceReceiver") as ForceReceiver
	var status_receiver: Node = get_node_or_null("StatusReceiver")
	var status_data: Dictionary = {}
	if status_receiver != null and status_receiver.has_method("get_debug_data"):
		status_data = status_receiver.get_debug_data()
	return {
		"environment_source": source_label,
		"position": global_position,
		"speed": snapped(Vector2(velocity.x, velocity.z).length(), 0.01),
		"emitter": emitter.get_debug_data() if emitter != null else {},
		"force": force_receiver.get_debug_data() if force_receiver != null else {},
		"statuses": status_data,
	}
