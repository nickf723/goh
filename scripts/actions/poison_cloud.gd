extends Node3D
class_name PoisonCloud

const TARGET_LAYER: int = 1
const HAZARD_LAYER: int = 2

@export var radius: float = 3.0
@export var lifetime: float = 6.0
@export var tick_interval: float = 0.35
@export var spawn_distance: float = 3.5
@export var spawn_height: float = 0.1
@export var visual_height_scale: float = 0.45
@export var show_debug_prints: bool = true
@export var payload: DamagePayload

@export var maximum_spread_radius: float = 5.5
@export var spread_radius_bonus: float = 1.15
@export var spread_lifetime_bonus: float = 1.25
@export var maximum_spread_count: int = 2

@export var ignition_radius_bonus: float = 1.25
@export var ignition_bonus_damage: int = 2
@export var ignition_burn_duration: float = 2.0
@export var ignition_burn_strength: float = 1.0

var runtime_payload: DamagePayload
var source_actor: Node3D
var lifetime_timer: float = 0.0
var tick_timer: float = 0.0
var spread_count: int = 0
var has_ignited: bool = false

@onready var hit_area: Area3D = get_node_or_null("HitArea")
@onready var cloud_visual: MeshInstance3D = get_node_or_null("CloudVisual")
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
	apply_cloud_tick()

	if show_debug_prints:
		print("Poison Cloud blooms at ", global_position)


func _process(delta: float) -> void:
	lifetime_timer -= delta
	tick_timer -= delta

	if tick_timer <= 0.0:
		tick_timer = tick_interval
		apply_cloud_tick()

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
	if cloud_visual == null:
		return

	cloud_visual.scale = Vector3(radius, radius * visual_height_scale, radius)


func update_visual_pulse() -> void:
	if cloud_visual == null:
		return

	var age: float = lifetime - lifetime_timer
	var pulse_speed: float = 3.0
	var pulse_size: float = 0.04
	var height_scale: float = visual_height_scale

	if has_ignited:
		pulse_speed = 12.0
		pulse_size = 0.18
		height_scale = visual_height_scale * 1.35

	var pulse: float = 1.0 + sin(age * pulse_speed) * pulse_size
	cloud_visual.scale = Vector3(radius * pulse, radius * height_scale, radius * pulse)


func apply_cloud_tick() -> void:
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
		if hazard_has_any_tag(hazard, ["fire", "flame", "burning"]):
			var fire_payload: DamagePayload = get_hazard_payload_or_fallback(hazard, "fire")
			react_to_payload(fire_payload, get_hazard_position(hazard))

	for target: Node in targets:
		apply_poison_to_target(target)


func apply_poison_to_target(target: Node) -> void:
	var status_receiver: Node = get_component(target, "StatusReceiver")

	if status_receiver == null:
		return

	var cloud_payload: DamagePayload = get_payload()
	var status_name: String = cloud_payload.status_effect
	var status_duration: float = cloud_payload.status_duration
	var status_strength: float = cloud_payload.status_strength

	if status_name == "":
		status_name = "poisoned"

	if status_duration <= 0.0:
		status_duration = 1.5

	if status_strength <= 0.0:
		status_strength = 1.0

	if status_receiver.has_method("sustain_status"):
		status_receiver.sustain_status(
			status_name,
			status_duration,
			status_strength,
			cloud_payload.source_name
		)
	elif status_receiver.has_method("apply_status"):
		status_receiver.apply_status(
			status_name,
			status_duration,
			status_strength,
			cloud_payload.source_name
		)


func react_to_payload(incoming_payload: DamagePayload, source_position: Vector3 = Vector3.ZERO) -> void:
	if incoming_payload == null:
		return

	if payload_has_any_tag(incoming_payload, ["fire", "flame", "burning"]) or incoming_payload.element == "fire":
		trigger_toxic_ignition(source_position)
		return

	if payload_has_any_tag(incoming_payload, ["air", "wind", "gust", "force"]) or incoming_payload.element == "air":
		spread_cloud(source_position)
		return


func trigger_toxic_ignition(_source_position: Vector3 = Vector3.ZERO) -> void:
	if has_ignited:
		return

	has_ignited = true
	radius = min(radius + ignition_radius_bonus, maximum_spread_radius + ignition_radius_bonus)
	lifetime_timer = min(lifetime_timer, 0.65)
	configure_area()
	apply_toxic_ignition_damage()
	show_reaction_message("Toxic Ignition! Poison gas flashes into burning venom.")

	if show_debug_prints:
		print("PoisonCloud reaction: Toxic Ignition")


func spread_cloud(_source_position: Vector3 = Vector3.ZERO) -> void:
	if spread_count >= maximum_spread_count:
		show_reaction_message("Wind tugs at the poison cloud, but it is already fully spread.")
		return

	spread_count += 1
	radius = min(radius + spread_radius_bonus, maximum_spread_radius)
	lifetime_timer += spread_lifetime_bonus
	configure_area()
	show_reaction_message("Cloud Spread! Wind blooms the poison cloud wider.")

	if show_debug_prints:
		print("PoisonCloud reaction: Cloud Spread. Radius now ", radius)


func apply_toxic_ignition_damage() -> void:
	if hit_area == null:
		return

	var targets: Array[Node] = []

	for body: Node in hit_area.get_overlapping_bodies():
		var body_target: Node = find_payload_target(body)

		if body_target != null and not targets.has(body_target):
			targets.append(body_target)

	for area: Area3D in hit_area.get_overlapping_areas():
		var area_target: Node = find_payload_target(area)

		if area_target != null and not targets.has(area_target):
			targets.append(area_target)

	var reaction_payload: DamagePayload = DamagePayload.new()
	reaction_payload.amount = ignition_bonus_damage
	reaction_payload.stance_damage = ignition_bonus_damage
	reaction_payload.element = "poison"
	reaction_payload.source_name = "Toxic Ignition"
	reaction_payload.hit_type = "reaction"
	reaction_payload.status_effect = "burning"
	reaction_payload.status_duration = ignition_burn_duration
	reaction_payload.status_strength = ignition_burn_strength
	reaction_payload.knockback_strength = 2.5
	reaction_payload.knockback_up_strength = 0.2
	reaction_payload.tags = ["poison", "fire", "explosion", "reaction", "hazard", "magic"]

	for target: Node in targets:
		apply_reaction_payload_to_target(target, reaction_payload)


func apply_reaction_payload_to_target(target: Node, reaction_payload: DamagePayload) -> void:
	var payload_receiver: Node = get_component(target, "PayloadReceiver")
	var result: Dictionary = {}

	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		result = payload_receiver.receive_payload(reaction_payload)
		show_result(result)
		return

	var hit_receiver: Node = get_component(target, "HitReceiver")

	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		result = hit_receiver.receive_payload(reaction_payload)
		show_result(result)


func get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload

	if payload != null:
		return payload

	var fallback_payload: DamagePayload = DamagePayload.new()
	fallback_payload.amount = 1
	fallback_payload.stance_damage = 0
	fallback_payload.element = "poison"
	fallback_payload.source_name = "Poison Cloud"
	fallback_payload.hit_type = "status"
	fallback_payload.status_effect = "poisoned"
	fallback_payload.status_duration = 1.5
	fallback_payload.status_strength = 1.0
	fallback_payload.tags = ["poison", "gas", "cloud", "hazard", "status"]
	return fallback_payload


func get_hazard_tags() -> Array[String]:
	return ["poison", "gas", "cloud", "hazard"]


func find_status_target(node: Node) -> Node:
	var current: Node = node

	while current != null:
		if get_component(current, "StatusReceiver") != null:
			return current

		current = current.get_parent()

	return null


func find_payload_target(node: Node) -> Node:
	var current: Node = node

	while current != null:
		if get_component(current, "PayloadReceiver") != null:
			return current

		if get_component(current, "HitReceiver") != null:
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


func get_hazard_payload_or_fallback(hazard: Node, fallback_element: String) -> DamagePayload:
	if hazard != null and hazard.has_method("get_payload"):
		var hazard_payload: Variant = hazard.call("get_payload")

		if hazard_payload is DamagePayload:
			return hazard_payload as DamagePayload

	var fallback_payload: DamagePayload = DamagePayload.new()
	fallback_payload.element = fallback_element
	fallback_payload.source_name = fallback_element.capitalize() + " Hazard"
	fallback_payload.tags = [fallback_element, "hazard", "reaction"]
	return fallback_payload


func get_hazard_position(hazard: Node) -> Vector3:
	if hazard is Node3D:
		return (hazard as Node3D).global_position

	return Vector3.ZERO


func show_reaction_message(message: String) -> void:
	show_result({"message": message, "objective": ""})


func show_result(result: Dictionary) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui == null:
		if result.has("message") and result["message"] != "":
			print(result["message"])
		return

	if result.has("message") and result["message"] != "":
		ui.show_message(result["message"])

	if result.has("objective") and result["objective"] != "":
		ui.set_objective(result["objective"])


func get_debug_data() -> Dictionary:
	return {
		"radius": radius,
		"life": snapped(lifetime_timer, 0.1),
		"payload": get_payload().source_name,
		"spread": spread_count,
		"ignited": has_ignited,
	}
