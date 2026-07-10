extends Resource
class_name EnemyAttackClassDefinition

@export var attack_class_id: String = "melee"
@export var display_name: String = "Melee Attack"
@export var role_tags: Array[String] = ["enemy_attack", "melee"]

@export_enum(
	"melee",
	"lunge",
	"projectile",
	"area",
	"grab",
	"support",
	"summon",
	"other"
)
var delivery_style: String = "melee"

@export var range: float = 1.5
@export var cone_angle_degrees: float = 110.0

@export var windup_time: float = 0.35
@export var recovery_time: float = 0.45
@export var cooldown: float = 1.0
@export var show_miss_message: bool = false

@export var payload_amount: int = 1
@export var payload_stance_damage: int = 1
@export var payload_element: String = "neutral"
@export var payload_source_name: String = ""
@export var payload_hit_type: String = "melee"

@export var payload_status_effect: String = ""
@export var payload_status_duration: float = 0.0
@export var payload_status_strength: float = 1.0

@export var payload_knockback_strength: float = 0.0
@export var payload_knockback_up_strength: float = 0.0
@export var payload_tags: Array[String] = ["physical", "melee", "enemy_attack"]

@export var debug_notes: String = ""


func make_payload(source_override: String = "") -> DamagePayload:
	var damage_payload: DamagePayload = DamagePayload.new()
	damage_payload.amount = payload_amount
	damage_payload.stance_damage = payload_stance_damage
	damage_payload.element = payload_element
	damage_payload.source_name = get_payload_source_name(source_override)
	damage_payload.hit_type = payload_hit_type
	damage_payload.status_effect = payload_status_effect
	damage_payload.status_duration = payload_status_duration
	damage_payload.status_strength = payload_status_strength
	damage_payload.knockback_strength = payload_knockback_strength
	damage_payload.knockback_up_strength = payload_knockback_up_strength
	damage_payload.tags = get_payload_tags()
	return damage_payload


func get_payload_source_name(source_override: String = "") -> String:
	if source_override != "":
		return source_override

	if payload_source_name != "":
		return payload_source_name

	return display_name


func get_payload_tags() -> Array[String]:
	var merged_tags: Array[String] = []

	append_unique_strings(merged_tags, payload_tags)
	append_unique_strings(merged_tags, role_tags)

	if not merged_tags.has(delivery_style):
		merged_tags.append(delivery_style)

	if not merged_tags.has(attack_class_id):
		merged_tags.append(attack_class_id)

	return merged_tags


func get_summary() -> String:
	return attack_class_id + " / " + delivery_style


func append_unique_strings(target: Array[String], source: Array[String]) -> void:
	for value: String in source:
		if value == "":
			continue

		if target.has(value):
			continue

		target.append(value)
