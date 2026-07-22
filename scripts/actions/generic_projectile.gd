extends Node3D
class_name GenericProjectile

const CombatFeedback = preload("res://scripts/combat/combat_feedback.gd")
const ChargedFireboltImpactFeedback = preload("res://scripts/combat/charged_firebolt_impact_feedback.gd")
const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
const SpellModifiers = preload("res://scripts/abilities/spell_modifier_registry.gd")
const AirflowMathScript = preload("res://scripts/airflow/airflow_math.gd")

@export var speed: float = 18.0
@export var max_lifetime: float = 2.6
@export var destroy_on_hit: bool = true
@export var hit_limit: int = 1
@export var ignore_source_for_seconds: float = 0.15
@export var rotate_to_direction: bool = true
@export var show_debug_prints: bool = false
@export var show_miss_feedback: bool = true
@export var trail_interval: float = 0.045

@export_group("Airflow")
@export var respond_to_airflow: bool = true
@export var aerodynamic_mass_kg: float = 0.32
@export var aerodynamic_drag_coefficient: float = 0.72
@export var aerodynamic_cross_section_area: float = 0.055
@export var aerodynamic_force_scale: float = 2.4
@export var maximum_airflow_acceleration: float = 14.0

@export var payload: DamagePayload

var runtime_payload: DamagePayload
var source_actor: Node
var direction: Vector3 = Vector3.FORWARD
var motion_velocity: Vector3 = Vector3.ZERO
var airflow_manager: Node = null
var last_air_velocity: Vector3 = Vector3.ZERO
var lifetime_timer: float = 0.0
var ignore_timer: float = 0.0
var is_launched: bool = false
var hit_count: int = 0
var hit_targets: Dictionary = {}
var elapsed: float = 0.0
var trail_timer: float = 0.0
var configured_element: String = ""
var runtime_impact_radius: float = 1.0
var applied_projectile_modifier_ids: Dictionary = {}

@onready var hit_area: Area3D = get_node_or_null("HitArea")
@onready var element_visual_root: Node3D = get_node_or_null("ElementVisualRoot") as Node3D


func _ready() -> void:
	lifetime_timer = max_lifetime
	ignore_timer = ignore_source_for_seconds
	apply_payload_projectile_modifiers(get_payload())
	resolve_airflow_manager()

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

	update_airflow_motion(delta)
	global_position += motion_velocity * delta
	update_element_trail(delta)


func update_airflow_motion(delta: float) -> void:
	if motion_velocity.length() <= 0.001:
		motion_velocity = direction * speed
	last_air_velocity = Vector3.ZERO
	if respond_to_airflow:
		var manager: Node = resolve_airflow_manager()
		if manager != null and manager.has_method("sample_total_airflow"):
			var sampled_value: Variant = manager.call("sample_total_airflow", global_position)
			if sampled_value is Vector3:
				last_air_velocity = sampled_value as Vector3
				var acceleration: Vector3 = AirflowMathScript.compute_drag_acceleration(
					last_air_velocity,
					motion_velocity,
					max(aerodynamic_mass_kg, 0.01),
					aerodynamic_drag_coefficient,
					aerodynamic_cross_section_area,
					1.225,
					aerodynamic_force_scale,
					maximum_airflow_acceleration
				)
				motion_velocity += acceleration * max(delta, 0.0)
	if motion_velocity.length() > 0.001:
		direction = motion_velocity.normalized()
		if rotate_to_direction:
			look_at(global_position + direction, Vector3.UP)


func resolve_airflow_manager() -> Node:
	if airflow_manager != null and is_instance_valid(airflow_manager):
		return airflow_manager
	if get_tree() != null:
		airflow_manager = get_tree().get_first_node_in_group("airflow_manager")
	return airflow_manager


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
		apply_payload_projectile_modifiers(runtime_payload)
		configure_element_visual()


func apply_payload_projectile_modifiers(active_payload: DamagePayload) -> void:
	if active_payload == null:
		return

	for modifier_variant: Variant in SpellModifiers.get_projectile_modifiers_for_payload(active_payload):
		if not (modifier_variant is Dictionary):
			continue

		var modifier: Dictionary = modifier_variant as Dictionary
		var modifier_id: String = str(modifier.get("id", ""))

		if modifier_id != "" and applied_projectile_modifier_ids.has(modifier_id):
			continue

		apply_projectile_modifier(modifier)
		if modifier_id != "":
			applied_projectile_modifier_ids[modifier_id] = true


func apply_projectile_modifier(modifier: Dictionary) -> void:
	if modifier.has("destroy_on_hit"):
		destroy_on_hit = bool(modifier.get("destroy_on_hit", destroy_on_hit))

	if modifier.has("hit_limit"):
		hit_limit = max(hit_limit, int(modifier.get("hit_limit", hit_limit)))

	if modifier.has("min_speed"):
		speed = max(speed, float(modifier.get("min_speed", speed)))

	if modifier.has("speed_bonus"):
		speed += float(modifier.get("speed_bonus", 0.0))

	if modifier.has("min_lifetime"):
		max_lifetime = max(max_lifetime, float(modifier.get("min_lifetime", max_lifetime)))

	if modifier.has("trail_interval"):
		trail_interval = min(trail_interval, float(modifier.get("trail_interval", trail_interval)))

	if modifier.has("impact_radius"):
		runtime_impact_radius = max(runtime_impact_radius, float(modifier.get("impact_radius", runtime_impact_radius)))

	if lifetime_timer > 0.0:
		lifetime_timer = max(lifetime_timer, max_lifetime)


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

	motion_velocity = direction * speed
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
	var active_payload: DamagePayload = get_payload()
	var result: Dictionary = send_payload_to_target(target, active_payload)

	if not ChargedFireboltImpactFeedback.play_if_charged_firebolt(self, target, active_payload, impact_position, direction):
		ElementVisuals.spawn_impact(get_tree(), impact_position, get_element(), get_impact_radius())

	var effect_messages: Array[String] = SpellModifiers.apply_on_hit_effects(
		self,
		target,
		active_payload,
		impact_position,
		direction,
		hit_targets
	)

	var messages: Array[String] = []
	if result.has("message") and result["message"] != "":
		messages.append(str(result["message"]))

	for effect_message: String in effect_messages:
		if effect_message == "":
			continue
		messages.append(effect_message)

	if messages.size() > 0:
		show_message("\n".join(messages))

	hit_count += 1

	if destroy_on_hit and hit_count >= hit_limit:
		queue_free()


func get_impact_radius() -> float:
	return runtime_impact_radius


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


func get_airflow_debug_data() -> Dictionary:
	return {
		"responds_to_airflow": respond_to_airflow,
		"motion_velocity": motion_velocity,
		"air_velocity": last_air_velocity,
		"air_speed": snapped(last_air_velocity.length(), 0.01),
	}
