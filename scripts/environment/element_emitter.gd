extends Area3D
class_name ElementEmitter

signal pulse_emitted(payload: DamagePayload, results: Array[Dictionary])
signal active_changed(is_active: bool)
signal reservoir_changed(current_units: float, maximum_units: float)

@export var emitter_id: String = "element_source"
@export var display_name: String = "Element Source"
@export var element: String = "neutral"
@export var payload_tags: Array[String] = ["environment", "element_source"]
@export var pulse_interval: float = 0.5
@export var pulse_on_ready: bool = true
@export var active: bool = true

@export_group("Target Filters")
@export var required_target_tags: Array[String] = []
@export var blocked_target_tags: Array[String] = []

@export_group("Reservoir")
@export_enum("infinite", "renewable", "finite") var reservoir_mode: String = "infinite"
@export var maximum_units: float = 10.0
@export var starting_units: float = 10.0
@export var units_per_pulse: float = 0.0
@export var recovery_units_per_second: float = 0.0

var current_units: float = 0.0
var pulse_timer: float = 0.0
var pulse_count: int = 0
var last_target_names: Array[String] = []
var last_results: Array[Dictionary] = []


func _ready() -> void:
	monitoring = true
	monitorable = true
	current_units = clampf(starting_units, 0.0, max(maximum_units, 0.0))
	pulse_timer = max(pulse_interval, 0.02)
	add_to_group("debuggable")

	if pulse_on_ready:
		call_deferred("emit_pulse")


func _physics_process(delta: float) -> void:
	recover_reservoir(delta)

	if not active:
		return

	pulse_timer -= delta
	if pulse_timer > 0.0:
		return

	pulse_timer = max(pulse_interval, 0.02)
	emit_pulse()


func emit_pulse() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	last_target_names.clear()
	last_results.clear()

	if not active or not can_pay_pulse_cost():
		return results

	var payload: DamagePayload = build_payload()
	var seen_targets: Dictionary = {}

	for raw_target: Node in get_overlap_nodes():
		var target: Node = find_payload_target(raw_target)
		if target == null or is_source_branch(target):
			continue
		if not target_matches_filters(target):
			continue

		var target_id: int = target.get_instance_id()
		if seen_targets.has(target_id):
			continue
		seen_targets[target_id] = true

		var result: Dictionary = send_payload_to_target(target, payload)
		result["target"] = target.name
		results.append(result)
		last_target_names.append(target.name)

	consume_pulse_cost()
	pulse_count += 1
	last_results = results.duplicate(true)
	pulse_emitted.emit(payload, results)
	return results


func build_payload() -> DamagePayload:
	var payload := DamagePayload.new()
	payload.amount = 0
	payload.stance_damage = 0
	payload.element = element
	payload.source_name = display_name
	payload.hit_type = "environment"
	payload.tags = payload_tags.duplicate()

	for required_tag: String in [element, "environment", "element_source"]:
		if required_tag != "" and not payload.tags.has(required_tag):
			payload.tags.append(required_tag)

	return payload


func get_overlap_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	for body: Node3D in get_overlapping_bodies():
		nodes.append(body)
	for area: Area3D in get_overlapping_areas():
		nodes.append(area)
	return nodes


func find_payload_target(start_node: Node) -> Node:
	var current: Node = start_node

	while current != null:
		if current.has_method("receive_damage_payload"):
			return current
		if current.get_node_or_null("PayloadReceiver") != null:
			return current
		current = current.get_parent()

	return null


func send_payload_to_target(target: Node, payload: DamagePayload) -> Dictionary:
	if target.has_method("receive_damage_payload"):
		return target.receive_damage_payload(payload)

	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return payload_receiver.receive_payload(payload)

	return {
		"message": display_name + " reaches " + target.name + ", but it has no payload receiver.",
		"objective": "",
	}


func target_matches_filters(target: Node) -> bool:
	for required_tag: String in required_target_tags:
		if not target_has_tag_or_status(target, required_tag):
			return false

	for blocked_tag: String in blocked_target_tags:
		if target_has_tag_or_status(target, blocked_tag):
			return false

	return true


func target_has_tag_or_status(target: Node, tag: String) -> bool:
	if tag == "":
		return true

	if target.has_method("get_hazard_tags"):
		var hazard_tags: Variant = target.call("get_hazard_tags")
		if hazard_tags is Array and (hazard_tags as Array).has(tag):
			return true

	var tag_component: Node = target.get_node_or_null("TagComponent")
	if tag_component != null and tag_component.has_method("has_tag") and tag_component.has_tag(tag):
		return true

	var status_receiver: Node = target.get_node_or_null("StatusReceiver")
	if status_receiver != null and status_receiver.has_method("has_status") and status_receiver.has_status(tag):
		return true

	return false


func is_source_branch(target: Node) -> bool:
	var source_root: Node = get_parent()
	if target == self or target == source_root:
		return true
	if source_root != null and source_root.is_ancestor_of(target):
		return true
	if target.is_ancestor_of(self):
		return true
	return false


func set_emitting(next_active: bool) -> void:
	if active == next_active:
		return
	active = next_active
	active_changed.emit(active)


func request_element_units(requested_units: float) -> float:
	if not active or requested_units <= 0.0:
		return 0.0
	if reservoir_mode == "infinite":
		return requested_units

	var supplied: float = min(requested_units, current_units)
	current_units = max(current_units - supplied, 0.0)
	reservoir_changed.emit(current_units, maximum_units)
	return supplied


func can_pay_pulse_cost() -> bool:
	if units_per_pulse <= 0.0 or reservoir_mode == "infinite":
		return true
	return current_units >= units_per_pulse


func consume_pulse_cost() -> void:
	if units_per_pulse <= 0.0 or reservoir_mode == "infinite":
		return
	request_element_units(units_per_pulse)


func recover_reservoir(delta: float) -> void:
	if reservoir_mode != "renewable" or recovery_units_per_second <= 0.0:
		return
	if current_units >= maximum_units:
		return

	current_units = min(current_units + recovery_units_per_second * delta, maximum_units)
	reservoir_changed.emit(current_units, maximum_units)


func reset_emitter() -> void:
	current_units = clampf(starting_units, 0.0, max(maximum_units, 0.0))
	pulse_timer = max(pulse_interval, 0.02)
	pulse_count = 0
	last_target_names.clear()
	last_results.clear()
	active_changed.emit(active)
	reservoir_changed.emit(current_units, maximum_units)


func get_debug_data() -> Dictionary:
	return {
		"emitter": emitter_id,
		"element": element,
		"active": active,
		"mode": reservoir_mode,
		"units": "infinite" if reservoir_mode == "infinite" else snapped(current_units, 0.1),
		"pulses": pulse_count,
		"targets": last_target_names,
		"required": required_target_tags,
		"blocked": blocked_target_tags,
	}
