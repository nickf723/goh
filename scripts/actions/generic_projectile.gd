extends Node3D
class_name GenericProjectile

const CombatFeedback = preload("res://scripts/combat/combat_feedback.gd")
const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export var speed: float = 18.0
@export var max_lifetime: float = 2.6
@export var destroy_on_hit: bool = true
@export var hit_limit: int = 1
@export var ignore_source_for_seconds: float = 0.15
@export var rotate_to_direction: bool = true
@export var show_debug_prints: bool = false
@export var show_miss_feedback: bool = true
@export var trail_interval: float = 0.045

@export var payload: DamagePayload

var runtime_payload: DamagePayload
var source_actor: Node
var direction: Vector3 = Vector3.FORWARD
var lifetime_timer: float = 0.0
var ignore_timer: float = 0.0
var is_launched: bool = false
var hit_count: int = 0
var hit_targets: Dictionary = {}
var elapsed: float = 0.0
var trail_timer: float = 0.0
var configured_element: String = ""

@onready var hit_area: Area3D = get_node_or_null("HitArea")
@onready var element_visual_root: Node3D = get_node_or_null("ElementVisualRoot") as Node3D


func _ready() -> void:
	lifetime_timer = max_lifetime
	ignore_timer = ignore_source_for_seconds

	if hit_area != null:
		hit_area.body_entered.connect(_on_body_entered)
		hit_area.area_entered.connect(_on_area_entered)

	configure_element_visual()


func _process(delta: float) -> void:
	elapsed += delta
	ElementVisuals.animate_projectile_visual(element_visual_root, get_element(), elapsed)

	if not is_launched:
		return

	if ignore_timer > 0.0:
		ignore_timer -= delta

	lifetime_timer -= delta

	if lifetime_timer <= 0.0:
		if show_miss_feedback and hit_count <= 0:
			CombatFeedback.show_miss_feedback(self, global_position)
		queue_free()
		return

	global_position += direction * speed * delta
	update_element_trail(delta)


func update_element_trail(delta: float) -> void:
	trail_timer -= delta

	if trail_timer > 0.0:
		return

	trail_timer = max(trail_interval, 0.02)
	ElementVisuals.spawn_trail_sample(
		get_tree(),
		global_position - direction * 0.16,
		get_element(),
		direction
	)


func set_payload(new_payload: Resource) -> void:
	if new_payload is DamagePayload:
		runtime_payload = new_payload as DamagePayload
		configure_element_visual()


func set_source_actor(new_source_actor: Node) -> void:
	source_actor = new_source_actor


func get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload

	if payload != null:
		return payload

	var fallback_payload: DamagePayload = DamagePayload.new()
	fallback_payload.amount = 1
	fallback_payload.stance_damage = 1
	fallback_payload.element = "neutral"
	fallback_payload.source_name = "Generic Projectile"
	fallback_payload.hit_type = "projectile"
	fallback_payload.tags = ["magic", "projectile"]
	return fallback_payload


func get_element() -> String:
	var active_payload: DamagePayload = get_payload()

	if active_payload == null or active_payload.element == "":
		return "neutral"

	return active_payload.element.to_lower()


func configure_element_visual() -> void:
	if not is_node_ready():
		return

	var element: String = get_element()

	if element == configured_element and element_visual_root != null and element_visual_root.get_child_count() > 0:
		return

	configured_element = element
	ElementVisuals.configure_projectile_visual(element_visual_root, configured_element)


func launch(cast_direction: Vector3) -> void:
	if cast_direction.length() > 0.01:
		direction = cast_direction.normalized()
	else:
		direction = Vector3.FORWARD

	is_launched = true
	configure_element_visual()

	if rotate_to_direction:
		look_at(global_position + direction, Vector3.UP)


func _on_body_entered(body: Node3D) -> void:
	try_hit(body)


func _on_area_entered(area: Area3D) -> void:
	try_hit(area)


func try_hit(raw_target: Node) -> void:
	var target: Node = find_payload_target(raw_target)

	if target == null:
		return

	if should_ignore_target(target):
		return

	var target_id: int = target.get_instance_id()

	if hit_targets.has(target_id):
		return

	hit_targets[target_id] = true
	var impact_position: Vector3 = global_position
	var result: Dictionary = send_payload_to_target(target, get_payload())

	ElementVisuals.spawn_impact(get_tree(), impact_position, get_element(), 1.0)

	if result.has("message") and result["message"] != "":
		show_message(str(result["message"]))

	hit_count += 1

	if destroy_on_hit and hit_count >= hit_limit:
		queue_free()


func should_ignore_target(target: Node) -> bool:
	if source_actor == null:
		return false

	if ignore_timer <= 0.0:
		return false

	if target == source_actor:
		return true

	if source_actor.is_ancestor_of(target):
		return true

	return false


func find_payload_target(start_node: Node) -> Node:
	var current: Node = start_node

	while current != null:
		if is_payload_target(current):
			return current

		current = current.get_parent()

	return null


func is_payload_target(node: Node) -> bool:
	if node.get_node_or_null("PayloadReceiver") != null:
		return true

	if node.get_node_or_null("HitReceiver") != null:
		return true

	if node.has_method("receive_damage_payload"):
		return true

	if node.has_method("receive_magic_hit"):
		return true

	return false


func send_payload_to_target(target: Node, damage_payload: DamagePayload) -> Dictionary:
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")

	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return payload_receiver.receive_payload(damage_payload)

	if target.has_method("receive_damage_payload"):
		return target.receive_damage_payload(damage_payload)

	var hit_receiver: Node = target.get_node_or_null("HitReceiver")

	if hit_receiver != null:
		if hit_receiver.has_method("receive_payload"):
			return hit_receiver.receive_payload(damage_payload)

		if hit_receiver.has_method("receive_hit"):
			return hit_receiver.receive_hit(damage_payload.amount)

	if target.has_method("receive_magic_hit"):
		return target.receive_magic_hit(damage_payload.amount)

	return {
		"message": damage_payload.source_name + " hits " + target.name + ", but nothing happens.",
		"objective": ""
	}


func show_message(text: String) -> void:
	if show_debug_prints:
		print(text)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
