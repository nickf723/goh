extends Resource
class_name EnemyAttackDefinition

@export var display_name: String = "Enemy Attack"

@export var payload: DamagePayload

@export var range: float = 1.5
@export var cone_angle_degrees: float = 110.0

@export var windup_time: float = 0.35
@export var recovery_time: float = 0.45
@export var cooldown: float = 1.0

@export var show_miss_message: bool = false


func get_payload() -> DamagePayload:
	if payload != null:
		return payload.duplicate(true) as DamagePayload

	var fallback_payload: DamagePayload = DamagePayload.new()
	fallback_payload.amount = 1
	fallback_payload.stance_damage = 1
	fallback_payload.element = "neutral"
	fallback_payload.source_name = display_name
	fallback_payload.hit_type = "melee"
	fallback_payload.tags = ["physical", "melee", "enemy_attack"]

	return fallback_payload
