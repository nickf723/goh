extends Area3D
class_name SurfaceHazardArea

signal hazard_contact(body: Node, result: Dictionary)
signal hazard_negated(body: Node, result: Dictionary)
signal hazard_damaged(body: Node, result: Dictionary)

@export_group("Hazard")
@export var display_name: String = "Surface Hazard"
@export var hazard_type: String = "terrain"
@export var element: String = "neutral"
@export_range(0, 100, 1) var health_damage: int = 6
@export_range(0, 100, 1) var stance_damage: int = 3
@export_range(0.05, 5.0, 0.05) var tick_interval_seconds: float = 0.5
@export var additional_tags: Array[String] = []
@export var apply_immediately_on_entry: bool = true

var tracked_bodies: Dictionary = {}
var tick_remaining: float = 0.0
var contact_count: int = 0
var negation_count: int = 0
var damage_count: int = 0
var last_result: Dictionary = {}
var last_body_name: String = "none"


func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("surface_hazards")
	add_to_group("surf_passable_hazards")
	add_to_group("debuggable")
	set_process(false)


func _process(delta: float) -> void:
	if tracked_bodies.is_empty():
		set_process(false)
		return
	tick_remaining -= maxf(delta, 0.0)
	if tick_remaining > 0.0:
		return
	tick_remaining = maxf(tick_interval_seconds, 0.05)
	var stale_ids: Array[int] = []
	for body_id_value: Variant in tracked_bodies.keys():
		var body_id: int = int(body_id_value)
		var body_value: Variant = tracked_bodies.get(body_id)
		if not body_value is Node or not is_instance_valid(body_value as Node):
			stale_ids.append(body_id)
			continue
		apply_hazard_to_body(body_value as Node)
	for body_id: int in stale_ids:
		tracked_bodies.erase(body_id)
	if tracked_bodies.is_empty():
		set_process(false)


func _on_body_entered(body: Node) -> void:
	if not _is_supported_body(body):
		return
	tracked_bodies[body.get_instance_id()] = body
	tick_remaining = maxf(tick_interval_seconds, 0.05)
	set_process(true)
	if apply_immediately_on_entry:
		apply_hazard_to_body(body)


func _on_body_exited(body: Node) -> void:
	if body == null:
		return
	tracked_bodies.erase(body.get_instance_id())
	if tracked_bodies.is_empty():
		set_process(false)


func apply_hazard_to_body(body: Node) -> Dictionary:
	if not _is_supported_body(body):
		return {
			"outcome": "ignored",
			"message": "",
		}
	var defense: Node = body.get_node_or_null("PlayerDefenseController")
	if defense == null or not defense.has_method("resolve_incoming_attack"):
		return {
			"outcome": "missing_defense",
			"message": "",
		}
	var payload: DamagePayload = _make_payload()
	var result_value: Variant = defense.call(
		"resolve_incoming_attack",
		payload,
		null
	)
	var result: Dictionary = (
		(result_value as Dictionary).duplicate(true)
		if result_value is Dictionary
		else {}
	)
	contact_count += 1
	last_result = result.duplicate(true)
	last_body_name = str(body.name)
	hazard_contact.emit(body, result.duplicate(true))
	if bool(result.get("surf", false)):
		negation_count += 1
		hazard_negated.emit(body, result.duplicate(true))
	else:
		damage_count += 1
		hazard_damaged.emit(body, result.duplicate(true))
	return result


func _make_payload() -> DamagePayload:
	var payload := DamagePayload.new()
	payload.amount = maxi(health_damage, 0)
	payload.stance_damage = maxi(stance_damage, 0)
	payload.element = element.strip_edges().to_lower()
	if payload.element == "":
		payload.element = "neutral"
	payload.source_name = display_name
	payload.hit_type = "surface_hazard"
	var tags: Array[String] = [
		"hazard",
		"terrain",
		"surface_hazard",
		"ground_hazard",
	]
	var normalized_type: String = hazard_type.strip_edges().to_lower()
	if normalized_type != "" and not tags.has(normalized_type):
		tags.append(normalized_type)
	if normalized_type == "lava" and not tags.has("lava_surface"):
		tags.append("lava_surface")
	if normalized_type in ["spike", "spikes"] and not tags.has("spike_floor"):
		tags.append("spike_floor")
	for tag: String in additional_tags:
		var normalized_tag: String = tag.strip_edges().to_lower()
		if normalized_tag != "" and not tags.has(normalized_tag):
			tags.append(normalized_tag)
	payload.tags = tags
	return payload


func _is_supported_body(body: Node) -> bool:
	return (
		body != null
		and is_instance_valid(body)
		and body.get_node_or_null("PlayerDefenseController") != null
	)


func reset_target() -> void:
	tracked_bodies.clear()
	tick_remaining = 0.0
	contact_count = 0
	negation_count = 0
	damage_count = 0
	last_result.clear()
	last_body_name = "none"
	set_process(false)


func get_debug_data() -> Dictionary:
	return {
		"surface_hazard": true,
		"display_name": display_name,
		"hazard_type": hazard_type,
		"element": element,
		"health_damage": health_damage,
		"stance_damage": stance_damage,
		"tracked_bodies": tracked_bodies.size(),
		"contacts": contact_count,
		"negations": negation_count,
		"damage_events": damage_count,
		"last_body": last_body_name,
		"last_result": last_result.duplicate(true),
		"processing": is_processing(),
	}
