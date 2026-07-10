extends Node3D
class_name FireField

const ComboRuleRegistryScript = preload("res://scripts/systems/combo_rule_registry.gd")

const TARGET_LAYER: int = 1
const HAZARD_LAYER: int = 2

@export var radius: float = 3.0
@export var lifetime: float = 5.0
@export var tick_interval: float = 0.3
@export var spawn_distance: float = 3.25
@export var spawn_height: float = 0.06
@export var visual_height_scale: float = 0.18
@export var show_debug_prints: bool = true
@export var payload: DamagePayload

@export var maximum_flare_radius: float = 5.25
@export var flare_radius_bonus: float = 1.0
@export var flare_lifetime_bonus: float = 1.25
@export var flare_duration: float = 1.0
@export var maximum_flare_count: int = 2

var runtime_payload: DamagePayload
var source_actor: Node3D
var lifetime_timer: float = 0.0
var tick_timer: float = 0.0
var flare_timer: float = 0.0
var flare_count: int = 0
var triggered_hazards: Array[Node] = []
var last_hazard_reaction_summary: String = "none"

@onready var hit_area: Area3D = get_node_or_null("HitArea")
@onready var field_visual: MeshInstance3D = get_node_or_null("FieldVisual")
@onready var collision_shape: CollisionShape3D = get_node_or_null("HitArea/CollisionShape3D")


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("hazard_reactive")
	lifetime_timer = lifetime
	tick_timer = 0.0
	configure_area()
	configure_visual()


func set_payload(new_payload: Resource) -> void:
	if new_payload is DamagePayload:
		runtime_payload = new_payload as DamagePayload


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func execute(player: Node3D, cast_direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player

	var flat_direction: Vector3 = cast_direction
	flat_direction.y = 0.0

	if flat_direction.length() <= 0.01 and player != null:
		flat_direction = -player.global_transform.basis.z
		flat_direction.y = 0.0

	if flat_direction.length() <= 0.01:
		flat_direction = Vector3.FORWARD

	flat_direction = flat_direction.normalized()

	if player != null:
		global_position = player.global_position + flat_direction * spawn_distance + Vector3.UP * spawn_height

	configure_area()
	configure_visual()
	apply_field_tick()

	if show_debug_prints:
		print("Fire Field ignites at ", global_position)


func _process(delta: float) -> void:
	lifetime_timer -= delta
	tick_timer -= delta

	if flare_timer > 0.0:
		flare_timer -= delta

	if tick_timer <= 0.0:
		tick_timer = tick_interval
		apply_field_tick()

	update_visual_pulse()

	if lifetime_timer <= 0.0:
		queue_free()


func configure_area() -> void:
	if hit_area == null:
		hit_area = Area3D.new()
		hit_area.name = "HitArea"
		add_child(hit_area)

	hit_area.monitoring = true
	hit_area.monitorable = true
	hit_area.collision_layer = HAZARD_LAYER
	hit_area.collision_mask = TARGET_LAYER | HAZARD_LAYER

	if collision_shape == null:
		collision_shape = hit_area.get_node_or_null("CollisionShape3D") as CollisionShape3D

	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		hit_area.add_child(collision_shape)

	var sphere_shape: SphereShape3D = collision_shape.shape as SphereShape3D

	if sphere_shape == null:
		sphere_shape = SphereShape3D.new()
		collision_shape.shape = sphere_shape

	sphere_shape.radius = radius


func configure_visual() -> void:
	if field_visual == null:
		return

	field_visual.scale = Vector3(radius, radius * visual_height_scale, radius)


func update_visual_pulse() -> void:
	if field_visual == null:
		return

	var age: float = lifetime - lifetime_timer
	var flare_ratio: float = clamp(flare_timer / max(flare_duration, 0.01), 0.0, 1.0)
	var pulse: float = 1.0 + sin(age * 8.0) * (0.055 + flare_ratio * 0.08)
	var height_bonus: float = 1.0 + flare_ratio * 0.65
	field_visual.scale = Vector3(radius * pulse, radius * visual_height_scale * height_bonus, radius * pulse)


func apply_field_tick() -> void:
	if hit_area == null:
		return

	var targets: Array[Node] = []
	var hazards: Array[Node] = []

	for body: Node in hit_area.get_overlapping_bodies():
		var body_target: Node = find_status_target(body)

		if body_target != null and not targets.has(body_target):
			targets.append(body_target)

	for area: Area3D in hit_area.get_overlapping_areas():
		var area_target: Node = find_status_target(area)

		if area_target != null and not targets.has(area_target):
			targets.append(area_target)

		var hazard_target: Node = find_hazard_target(area)

		if hazard_target != null and hazard_target != self and not hazards.has(hazard_target):
			hazards.append(hazard_target)

	for hazard: Node in hazards:
		trigger_hazard_reaction(hazard)

	for target: Node in targets:
		apply_burning_to_target(target)


func trigger_hazard_reaction(hazard: Node) -> void:
	if hazard == null:
		return

	if triggered_hazards.has(hazard) and is_instance_valid(hazard):
		return

	triggered_hazards.append(hazard)

	var reactions: Array[Dictionary] = ComboRuleRegistryScript.resolve_hazard_reactions(hazard, get_payload(), global_position)

	if reactions.size() > 0:
		last_hazard_reaction_summary = "registry: " + get_reaction_summary(reactions)
		return

	if hazard.has_method("react_to_payload"):
		hazard.call("react_to_payload", get_payload(), global_position)
		last_hazard_reaction_summary = "legacy: " + get_hazard_label(hazard)


func apply_burning_to_target(target: Node) -> void:
	var status_receiver: Node = get_component(target, "StatusReceiver")

	if status_receiver == null:
		return

	var field_payload: DamagePayload = get_payload()
	var status_name: String = field_payload.status_effect
	var status_duration: float = field_payload.status_duration
	var status_strength: float = field_payload.status_strength

	if status_name == "":
		status_name = "burning"

	if status_duration <= 0.0:
		status_duration = 1.2

	if status_strength <= 0.0:
		status_strength = 1.0

	if flare_timer > 0.0:
		status_strength += 0.5

	if status_receiver.has_method("sustain_status"):
		status_receiver.sustain_status(
			status_name,
			status_duration,
			status_strength,
			field_payload.source_name
		)
	elif status_receiver.has_method("apply_status"):
		status_receiver.apply_status(
			status_name,
			status_duration,
			status_strength,
			field_payload.source_name
		)


func react_to_payload(incoming_payload: DamagePayload, source_position: Vector3 = Vector3.ZERO) -> void:
	if incoming_payload == null:
		return

	var reactions: Array[Dictionary] = ComboRuleRegistryScript.resolve_hazard_reactions(self, incoming_payload, source_position)

	if reactions.size() > 0:
		last_hazard_reaction_summary = "registry: " + get_reaction_summary(reactions)
		return

	if payload_has_any_tag(incoming_payload, ["air", "wind", "gust", "force"]) or incoming_payload.element == "air":
		flare_field(source_position)
		last_hazard_reaction_summary = "legacy: fanned_flames"
		return


func flare_field(_source_position: Vector3 = Vector3.ZERO) -> void:
	if flare_count >= maximum_flare_count:
		show_reaction_message("Wind scrapes the fire field, but the flames are already roaring.")
		return

	flare_count += 1
	radius = min(radius + flare_radius_bonus, maximum_flare_radius)
	lifetime_timer += flare_lifetime_bonus
	flare_timer = flare_duration
	configure_area()
	show_reaction_message("Fanned Flames! Wind fattens the fire field.")

	if show_debug_prints:
		print("FireField reaction: Fanned Flames. Radius now ", radius)


func get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload

	if payload != null:
		return payload

	var fallback_payload: DamagePayload = DamagePayload.new()
	fallback_payload.amount = 1
	fallback_payload.stance_damage = 0
	fallback_payload.element = "fire"
	fallback_payload.source_name = "Fire Field"
	fallback_payload.hit_type = "status"
	fallback_payload.status_effect = "burning"
	fallback_payload.status_duration = 1.2
	fallback_payload.status_strength = 1.0
	fallback_payload.tags = ["fire", "flame", "field", "hazard", "status", "magic"]
	return fallback_payload


func get_hazard_tags() -> Array[String]:
	return ["fire", "flame", "field", "hazard"]


func find_status_target(node: Node) -> Node:
	var current: Node = node

	while current != null:
		if get_component(current, "StatusReceiver") != null:
			return current

		current = current.get_parent()

	return null


func find_hazard_target(node: Node) -> Node:
	var current: Node = node

	while current != null:
		if current.has_method("react_to_payload") and current.has_method("get_hazard_tags"):
			return current

		current = current.get_parent()

	return null


func get_component(target: Node, component_name: String) -> Node:
	if target == null:
		return null

	var direct: Node = target.get_node_or_null(component_name)

	if direct != null:
		return direct

	for child: Node in target.get_children():
		if child.name == component_name:
			return child

	return null


func payload_has_any_tag(incoming_payload: DamagePayload, tags_to_check: Array[String]) -> bool:
	if incoming_payload == null:
		return false

	for tag: String in tags_to_check:
		if incoming_payload.tags.has(tag):
			return true

	return false


func hazard_has_any_tag(hazard: Node, tags_to_check: Array[String]) -> bool:
	if hazard == null or not hazard.has_method("get_hazard_tags"):
		return false

	var hazard_tags: Array = hazard.call("get_hazard_tags")

	for tag: String in tags_to_check:
		if hazard_tags.has(tag):
			return true

	return false


func get_hazard_label(hazard: Node) -> String:
	if hazard == null:
		return "hazard"

	if hazard.has_method("get_hazard_tags"):
		var tags: Array = hazard.call("get_hazard_tags")

		if tags.size() > 0:
			return str(tags[0]).capitalize() + " Hazard"

	return hazard.name


func get_reaction_summary(reactions: Array[Dictionary]) -> String:
	var names: Array[String] = []

	for reaction: Dictionary in reactions:
		if reaction.has("reaction"):
			names.append(str(reaction["reaction"]))

	if names.size() <= 0:
		return "reaction"

	return ", ".join(names)


func show_reaction_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui == null:
		print(message)
		return

	if ui.has_method("show_message"):
		ui.show_message(message)


func get_debug_data() -> Dictionary:
	return {
		"radius": radius,
		"life": snapped(lifetime_timer, 0.1),
		"payload": get_payload().source_name,
		"flare": snapped(flare_timer, 0.1),
		"flare_count": flare_count,
		"hazard_rx": last_hazard_reaction_summary,
	}
