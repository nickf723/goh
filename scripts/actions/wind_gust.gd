extends Node3D
class_name WindGust

const TARGET_LAYER: int = 1
const HAZARD_LAYER: int = 2

@export var radius: float = 4.2
@export var cone_angle_degrees: float = 80.0
@export var lifetime: float = 0.45
@export var spawn_distance: float = 1.25
@export var spawn_height: float = 1.0
@export var visual_forward_scale: float = 2.2
@export var visual_side_scale: float = 1.2
@export var show_debug_prints: bool = true
@export var payload: DamagePayload

var runtime_payload: DamagePayload
var source_actor: Node3D
var direction: Vector3 = Vector3.FORWARD
var lifetime_timer: float = 0.0
var has_applied: bool = false
var hit_targets: Array[Node] = []
var stirred_hazards: Array[Node] = []

@onready var gust_area: Area3D = get_node_or_null("GustArea")
@onready var gust_visual: MeshInstance3D = get_node_or_null("GustVisual")
@onready var collision_shape: CollisionShape3D = get_node_or_null("GustArea/CollisionShape3D")


func _ready() -> void:
	add_to_group("debuggable")
	lifetime_timer = lifetime
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

	direction = cast_direction
	direction.y = 0.0

	if direction.length() <= 0.01 and player != null:
		direction = -player.global_transform.basis.z
		direction.y = 0.0

	if direction.length() <= 0.01:
		direction = Vector3.FORWARD

	direction = direction.normalized()

	if player != null:
		global_position = player.global_position + direction * spawn_distance + Vector3.UP * spawn_height

	look_at(global_position + direction, Vector3.UP)
	configure_area()
	configure_visual()
	apply_gust_once()

	if show_debug_prints:
		print("Wind Gust bursts forward from ", global_position)


func _process(delta: float) -> void:
	lifetime_timer -= delta
	update_visual_pulse()

	if lifetime_timer <= 0.0:
		queue_free()


func configure_area() -> void:
	if gust_area == null:
		gust_area = Area3D.new()
		gust_area.name = "GustArea"
		add_child(gust_area)

	gust_area.monitoring = true
	gust_area.monitorable = true
	gust_area.collision_layer = HAZARD_LAYER
	gust_area.collision_mask = TARGET_LAYER | HAZARD_LAYER

	if collision_shape == null:
		collision_shape = gust_area.get_node_or_null("CollisionShape3D") as CollisionShape3D

	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		gust_area.add_child(collision_shape)

	var sphere_shape: SphereShape3D = collision_shape.shape as SphereShape3D

	if sphere_shape == null:
		sphere_shape = SphereShape3D.new()
		collision_shape.shape = sphere_shape

	sphere_shape.radius = radius


func configure_visual() -> void:
	if gust_visual == null:
		return

	gust_visual.scale = Vector3(visual_side_scale, visual_side_scale * 0.45, visual_forward_scale)


func update_visual_pulse() -> void:
	if gust_visual == null:
		return

	var progress: float = 1.0 - clamp(lifetime_timer / max(lifetime, 0.01), 0.0, 1.0)
	var bloom: float = 1.0 + progress * 0.55
	var fade_squash: float = 1.0 - progress * 0.25
	gust_visual.scale = Vector3(
		visual_side_scale * bloom,
		visual_side_scale * 0.45 * fade_squash,
		visual_forward_scale * bloom
	)


func apply_gust_once() -> void:
	if has_applied:
		return

	has_applied = true

	if gust_area == null:
		return

	await get_tree().physics_frame

	var targets: Array[Node] = []
	var hazards: Array[Node] = []

	for body: Node in gust_area.get_overlapping_bodies():
		var body_target: Node = find_payload_target(body)

		if body_target != null and not targets.has(body_target):
			targets.append(body_target)

	for area: Area3D in gust_area.get_overlapping_areas():
		var area_target: Node = find_payload_target(area)

		if area_target != null and not targets.has(area_target):
			targets.append(area_target)

		var hazard_target: Node = find_hazard_target(area)

		if hazard_target != null and not hazards.has(hazard_target):
			hazards.append(hazard_target)

	for target: Node in targets:
		if is_target_in_cone(target):
			apply_wind_to_target(target)

	for hazard: Node in hazards:
		if is_target_in_cone(hazard):
			apply_wind_to_hazard(hazard)


func is_target_in_cone(target: Node) -> bool:
	if target == null:
		return false

	if source_actor != null and target == source_actor:
		return false

	var target_position: Vector3 = get_target_position(target)
	var to_target: Vector3 = target_position - global_position
	to_target.y = 0.0

	if to_target.length() <= 0.01:
		return true

	if to_target.length() > radius:
		return false

	var angle: float = rad_to_deg(direction.angle_to(to_target.normalized()))
	return angle <= cone_angle_degrees * 0.5


func apply_wind_to_target(target: Node) -> void:
	if hit_targets.has(target):
		return

	hit_targets.append(target)

	var wind_payload: DamagePayload = get_payload()
	var payload_receiver: Node = get_component(target, "PayloadReceiver")
	var result: Dictionary = {}

	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		result = payload_receiver.receive_payload(wind_payload)
	else:
		var hit_receiver: Node = get_component(target, "HitReceiver")

		if hit_receiver != null and hit_receiver.has_method("receive_payload"):
			result = hit_receiver.receive_payload(wind_payload)
		else:
			result = {
				"message": "Wind Gust buffets " + target.name + ", but nothing receives the payload.",
				"objective": ""
			}

	show_result(result)


func apply_wind_to_hazard(hazard: Node) -> void:
	if hazard == null:
		return

	if stirred_hazards.has(hazard):
		return

	stirred_hazards.append(hazard)

	if hazard.has_method("react_to_payload"):
		hazard.call("react_to_payload", get_payload(), global_position)
		show_result({
			"message": "Wind Gust stirs " + get_hazard_label(hazard) + ".",
			"objective": ""
		})


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


func get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload

	if payload != null:
		return payload

	var fallback_payload: DamagePayload = DamagePayload.new()
	fallback_payload.amount = 0
	fallback_payload.stance_damage = 1
	fallback_payload.element = "air"
	fallback_payload.source_name = "Wind Gust"
	fallback_payload.hit_type = "magic"
	fallback_payload.knockback_strength = 6.5
	fallback_payload.knockback_up_strength = 0.4
	fallback_payload.tags = ["air", "wind", "force", "gust", "magic"]
	return fallback_payload


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
		if current == self:
			return null

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


func get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return target.global_position

	var parent: Node = target.get_parent()

	if parent is Node3D:
		return (parent as Node3D).global_position

	return Vector3.ZERO


func get_hazard_label(hazard: Node) -> String:
	if hazard == null:
		return "hazard"

	if hazard.has_method("get_hazard_tags"):
		var tags: Array = hazard.call("get_hazard_tags")

		if tags.size() > 0:
			return str(tags[0]).capitalize() + " Hazard"

	return hazard.name


func get_debug_data() -> Dictionary:
	return {
		"radius": radius,
		"angle": cone_angle_degrees,
		"life": snapped(lifetime_timer, 0.1),
		"hits": hit_targets.size(),
		"hazards": stirred_hazards.size(),
	}
