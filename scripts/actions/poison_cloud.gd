extends Node3D
class_name PoisonCloud

@export var radius: float = 3.0
@export var lifetime: float = 6.0
@export var tick_interval: float = 0.35
@export var spawn_distance: float = 3.5
@export var spawn_height: float = 0.1
@export var visual_height_scale: float = 0.45
@export var show_debug_prints: bool = true
@export var payload: DamagePayload

var runtime_payload: DamagePayload
var source_actor: Node3D
var lifetime_timer: float = 0.0
var tick_timer: float = 0.0

@onready var hit_area: Area3D = get_node_or_null("HitArea")
@onready var cloud_visual: MeshInstance3D = get_node_or_null("CloudVisual")
@onready var collision_shape: CollisionShape3D = get_node_or_null("HitArea/CollisionShape3D")


func _ready() -> void:
	add_to_group("debuggable")
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
	hit_area.monitorable = false
	hit_area.collision_layer = 0
	hit_area.collision_mask = 1

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
	var pulse: float = 1.0 + sin(age * 3.0) * 0.04
	cloud_visual.scale = Vector3(radius * pulse, radius * visual_height_scale, radius * pulse)


func apply_cloud_tick() -> void:
	if hit_area == null:
		return

	var targets: Array[Node] = []

	for body: Node in hit_area.get_overlapping_bodies():
		var body_target: Node = find_status_target(body)

		if body_target != null and not targets.has(body_target):
			targets.append(body_target)

	for area: Area3D in hit_area.get_overlapping_areas():
		var area_target: Node = find_status_target(area)

		if area_target != null and not targets.has(area_target):
			targets.append(area_target)

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
	fallback_payload.tags = ["poison", "cloud", "hazard", "status"]
	return fallback_payload


func find_status_target(node: Node) -> Node:
	var current: Node = node

	while current != null:
		if get_component(current, "StatusReceiver") != null:
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


func get_debug_data() -> Dictionary:
	return {
		"radius": radius,
		"life": snapped(lifetime_timer, 0.1),
		"payload": get_payload().source_name,
	}
