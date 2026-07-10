extends Resource
class_name EnemyAttackDefinition

@export var attack_class: EnemyAttackClassDefinition

# When true, timing/shape and payload details come from attack_class.
# Leave these off when a specific species attack needs custom one-off tuning.
@export var use_class_identity: bool = false
@export var use_class_timing: bool = true
@export var use_class_payload: bool = false

@export var display_name: String = "Enemy Attack"

@export var payload: DamagePayload

@export var range: float = 1.5
@export var cone_angle_degrees: float = 110.0

@export var windup_time: float = 0.35
@export var recovery_time: float = 0.45
@export var cooldown: float = 1.0

@export var show_miss_message: bool = false


func get_display_name() -> String:
	if use_class_identity and attack_class != null and display_name == "Enemy Attack":
		return attack_class.display_name

	return display_name


func get_range() -> float:
	if use_class_timing and attack_class != null:
		return attack_class.range

	return range


func get_cone_angle_degrees() -> float:
	if use_class_timing and attack_class != null:
		return attack_class.cone_angle_degrees

	return cone_angle_degrees


func get_windup_time() -> float:
	if use_class_timing and attack_class != null:
		return attack_class.windup_time

	return windup_time


func get_recovery_time() -> float:
	if use_class_timing and attack_class != null:
		return attack_class.recovery_time

	return recovery_time


func get_cooldown() -> float:
	if use_class_timing and attack_class != null:
		return attack_class.cooldown

	return cooldown


func should_show_miss_message() -> bool:
	if use_class_timing and attack_class != null:
		return attack_class.show_miss_message

	return show_miss_message


func get_payload() -> DamagePayload:
	if use_class_payload and attack_class != null:
		return attack_class.make_payload(get_display_name())

	if payload != null:
		return payload.duplicate(true) as DamagePayload

	if attack_class != null:
		return attack_class.make_payload(get_display_name())

	var fallback_payload: DamagePayload = DamagePayload.new()
	fallback_payload.amount = 1
	fallback_payload.stance_damage = 1
	fallback_payload.element = "neutral"
	fallback_payload.source_name = get_display_name()
	fallback_payload.hit_type = "melee"
	fallback_payload.tags = ["physical", "melee", "enemy_attack"]

	return fallback_payload


func get_attack_class_summary() -> String:
	if attack_class == null:
		return "no attack class"

	return attack_class.get_summary()


func get_debug_notes() -> String:
	if attack_class != null and attack_class.debug_notes != "":
		return attack_class.debug_notes

	return ""
