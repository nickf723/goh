extends Resource
class_name WeaponAttackDefinition

@export var attack_id: String = "attack"
@export var display_name: String = "Attack"
@export_enum("light", "heavy") var input_kind: String = "light"

@export_group("Timing")
@export var startup_time: float = 0.16
@export var active_time: float = 0.08
@export var recovery_time: float = 0.24
@export var combo_timeout: float = 0.55
@export_range(0.0, 1.0, 0.01) var cancel_window_start_normalized: float = 0.62
@export var allow_spell_cancel: bool = false
@export var allow_dodge_cancel: bool = true

@export_group("Cost and Payload")
@export var stamina_cost: int = 0
@export var payload: DamagePayload
@export var damage_multiplier: float = 1.0
@export var stance_multiplier: float = 1.0
@export var knockback_multiplier: float = 1.0
@export var knockback_up_add: float = 0.0
@export var extra_tags: Array[String] = []

@export_group("Geometry")
@export var attack_range: float = 2.4
@export var cone_angle_degrees: float = 90.0
@export var attack_center_forward_offset: float = 1.15
@export var max_targets: int = 3
@export var movement_distance: float = 0.0
@export var movement_duration: float = 0.12

@export_group("Combo Graph")
@export var next_light_attack_id: String = ""
@export var next_heavy_attack_id: String = ""

@export_group("Feedback")
@export var hit_stop_duration: float = 0.055
@export var hit_stop_time_scale: float = 0.05
@export var trail_color: Color = Color(0.9, 0.95, 1.0, 0.78)
@export var trail_start_scale: Vector3 = Vector3(0.35, 0.75, 1.0)
@export var trail_end_scale: Vector3 = Vector3(0.9, 1.35, 1.0)

@export_group("Presentation Pose")
@export var windup_rotation_degrees: Vector3 = Vector3(0.0, -55.0, 0.0)
@export var strike_rotation_degrees: Vector3 = Vector3(0.0, 65.0, 0.0)
@export var recovery_rotation_degrees: Vector3 = Vector3.ZERO
@export var windup_offset: Vector3 = Vector3.ZERO
@export var strike_offset: Vector3 = Vector3.ZERO
@export var recovery_offset: Vector3 = Vector3.ZERO

@export_group("Character Control Pose")
# Optional authored whole-body pose profile. Empty keeps the legacy weapon-only
# presentation, allowing existing weapons to migrate one moveset at a time.
@export var character_pose_id: String = ""


func get_startup_duration(attack_speed: float = 1.0) -> float:
	return startup_time / max(attack_speed, 0.05)


func get_active_duration(attack_speed: float = 1.0) -> float:
	return active_time / max(attack_speed, 0.05)


func get_recovery_duration(attack_speed: float = 1.0) -> float:
	return recovery_time / max(attack_speed, 0.05)


func get_total_duration(attack_speed: float = 1.0) -> float:
	return (
		get_startup_duration(attack_speed)
		+ get_active_duration(attack_speed)
		+ get_recovery_duration(attack_speed)
	)


func get_cancel_window_start(attack_speed: float = 1.0) -> float:
	return get_total_duration(attack_speed) * clampf(cancel_window_start_normalized, 0.0, 1.0)


func get_next_attack_id(requested_input: String) -> String:
	if requested_input == "heavy":
		return next_heavy_attack_id
	return next_light_attack_id


func build_payload(weapon: WeaponDefinition) -> DamagePayload:
	var resolved_payload: DamagePayload

	if payload != null:
		resolved_payload = payload.duplicate(true) as DamagePayload
	elif weapon != null:
		resolved_payload = weapon.get_light_payload()
	else:
		resolved_payload = DamagePayload.new()
		resolved_payload.tags = ["physical", "melee", "weapon"]

	var base_damage: int = resolved_payload.amount
	var base_stance_damage: int = resolved_payload.stance_damage

	if weapon != null:
		base_damage = weapon.damage
		base_stance_damage = weapon.stance_damage
		resolved_payload.source_name = weapon.display_name + " • " + display_name
	else:
		resolved_payload.source_name = display_name

	resolved_payload.amount = max(0, roundi(float(base_damage) * max(damage_multiplier, 0.0)))
	resolved_payload.stance_damage = max(0, roundi(float(base_stance_damage) * max(stance_multiplier, 0.0)))
	if weapon != null:
		resolved_payload.critical_multiplier = maxf(weapon.critical_multiplier, 1.0)
	resolved_payload.knockback_strength *= max(knockback_multiplier, 0.0)
	resolved_payload.knockback_up_strength += knockback_up_add
	resolved_payload.hit_type = "melee"

	append_payload_tag(resolved_payload, "weapon")
	append_payload_tag(resolved_payload, "melee")
	append_payload_tag(resolved_payload, input_kind)

	for tag: String in extra_tags:
		append_payload_tag(resolved_payload, tag)

	return resolved_payload


func append_payload_tag(resolved_payload: DamagePayload, tag: String) -> void:
	if resolved_payload == null or tag == "":
		return
	if not resolved_payload.tags.has(tag):
		resolved_payload.tags.append(tag)


func get_debug_summary() -> String:
	return (
		attack_id
		+ " ["
		+ input_kind
		+ "] "
		+ str(snapped(get_total_duration(), 0.01))
		+ "s → L:"
		+ (next_light_attack_id if next_light_attack_id != "" else "-")
		+ " H:"
		+ (next_heavy_attack_id if next_heavy_attack_id != "" else "-")
	)
