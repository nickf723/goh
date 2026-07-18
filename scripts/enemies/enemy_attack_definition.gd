extends Resource
class_name EnemyAttackDefinition

# Keep this as a generic Resource so Godot does not need to resolve the new
# EnemyAttackClassDefinition class before this script can parse.
@export var attack_class: Resource

# When true, timing/shape and payload details come from attack_class.
# Leave these off when a specific species attack needs custom one-off tuning.
@export var use_class_identity: bool = false
@export var use_class_timing: bool = true
@export var use_class_payload: bool = false

@export var display_name: String = "Enemy Attack"
@export var role_tags: Array[String] = ["enemy_attack", "melee"]

@export var payload: DamagePayload

@export var range: float = 1.5
@export var cone_angle_degrees: float = 110.0

@export var windup_time: float = 0.35
@export var active_time: float = 0.10
@export var recovery_time: float = 0.45
@export var cooldown: float = 1.0

@export_group("Phase Movement")
@export var windup_move_speed_multiplier: float = 0.0
@export var active_move_speed_multiplier: float = 0.0
@export var recovery_move_speed_multiplier: float = 0.0

@export_group("Interrupts")
@export var interruptible_during_windup: bool = true
@export var interruptible_during_active: bool = false
@export var interruptible_during_recovery: bool = false

@export_group("")
@export var show_miss_message: bool = false


func get_display_name() -> String:
	if use_class_identity and has_attack_class() and display_name == "Enemy Attack":
		return get_class_string("display_name", display_name)

	return display_name


func get_role_tags() -> Array[String]:
	var merged_tags: Array[String] = []
	append_unique_strings(merged_tags, role_tags)

	if has_attack_class():
		var class_tags: Variant = attack_class.get("role_tags")
		if class_tags is Array:
			for tag_value in class_tags:
				var tag: String = str(tag_value)
				if tag != "" and not merged_tags.has(tag):
					merged_tags.append(tag)

	return merged_tags


func get_range() -> float:
	if use_class_timing and has_attack_class():
		return get_class_float("range", range)

	return range


func get_cone_angle_degrees() -> float:
	if use_class_timing and has_attack_class():
		return get_class_float("cone_angle_degrees", cone_angle_degrees)

	return cone_angle_degrees


func get_windup_time() -> float:
	if use_class_timing and has_attack_class():
		return get_class_float("windup_time", windup_time)

	return windup_time


func get_active_time() -> float:
	if use_class_timing and has_attack_class():
		return get_class_float("active_time", active_time)

	return active_time


func get_recovery_time() -> float:
	if use_class_timing and has_attack_class():
		return get_class_float("recovery_time", recovery_time)

	return recovery_time


func get_cooldown() -> float:
	if use_class_timing and has_attack_class():
		return get_class_float("cooldown", cooldown)

	return cooldown


func get_windup_move_speed_multiplier() -> float:
	if use_class_timing and has_attack_class():
		return get_class_float("windup_move_speed_multiplier", windup_move_speed_multiplier)

	return windup_move_speed_multiplier


func get_active_move_speed_multiplier() -> float:
	if use_class_timing and has_attack_class():
		return get_class_float("active_move_speed_multiplier", active_move_speed_multiplier)

	return active_move_speed_multiplier


func get_recovery_move_speed_multiplier() -> float:
	if use_class_timing and has_attack_class():
		return get_class_float("recovery_move_speed_multiplier", recovery_move_speed_multiplier)

	return recovery_move_speed_multiplier


func get_interruptible_during_windup() -> bool:
	if use_class_timing and has_attack_class():
		return get_class_bool("interruptible_during_windup", interruptible_during_windup)

	return interruptible_during_windup


func get_interruptible_during_active() -> bool:
	if use_class_timing and has_attack_class():
		return get_class_bool("interruptible_during_active", interruptible_during_active)

	return interruptible_during_active


func get_interruptible_during_recovery() -> bool:
	if use_class_timing and has_attack_class():
		return get_class_bool("interruptible_during_recovery", interruptible_during_recovery)

	return interruptible_during_recovery


func should_show_miss_message() -> bool:
	if use_class_timing and has_attack_class():
		return get_class_bool("show_miss_message", show_miss_message)

	return show_miss_message


func get_payload() -> DamagePayload:
	if use_class_payload and has_attack_class():
		var class_payload: DamagePayload = get_class_payload()

		if class_payload != null:
			return class_payload

	if payload != null:
		return payload.duplicate(true) as DamagePayload

	if has_attack_class():
		var fallback_class_payload: DamagePayload = get_class_payload()

		if fallback_class_payload != null:
			return fallback_class_payload

	var fallback_payload: DamagePayload = DamagePayload.new()
	fallback_payload.amount = 1
	fallback_payload.stance_damage = 1
	fallback_payload.element = "neutral"
	fallback_payload.source_name = get_display_name()
	fallback_payload.hit_type = "melee"
	fallback_payload.tags = ["physical", "melee", "enemy_attack"]

	return fallback_payload


func get_attack_class_summary() -> String:
	if not has_attack_class():
		return "no attack class"

	if attack_class.has_method("get_summary"):
		return str(attack_class.call("get_summary"))

	return get_class_string("attack_class_id", "attack class")


func get_debug_notes() -> String:
	if not has_attack_class():
		return ""

	return get_class_string("debug_notes", "")


func has_attack_class() -> bool:
	return attack_class != null


func get_class_value(property_name: String, fallback: Variant) -> Variant:
	if not has_attack_class():
		return fallback

	var value: Variant = attack_class.get(property_name)

	if value == null:
		return fallback

	return value


func get_class_string(property_name: String, fallback: String) -> String:
	return str(get_class_value(property_name, fallback))


func get_class_float(property_name: String, fallback: float) -> float:
	return float(get_class_value(property_name, fallback))


func get_class_bool(property_name: String, fallback: bool) -> bool:
	return bool(get_class_value(property_name, fallback))


func get_class_payload() -> DamagePayload:
	if not has_attack_class():
		return null

	if not attack_class.has_method("make_payload"):
		return null

	var payload_variant: Variant = attack_class.call("make_payload", get_display_name())

	if payload_variant is DamagePayload:
		return payload_variant as DamagePayload

	return null


func append_unique_strings(target: Array[String], source: Array[String]) -> void:
	for value: String in source:
		if value == "":
			continue

		if target.has(value):
			continue

		target.append(value)
