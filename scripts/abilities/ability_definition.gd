extends Resource
class_name AbilityDefinition

enum AbilityCategory {
	PROJECTILE,
	INSTANT,
	SUMMON,
	TRANSFORMATION,
	UTILITY,
}

@export var display_name: String = "New Ability"
@export var description: String = ""
@export var element: String = "neutral"
@export var category: AbilityCategory = AbilityCategory.PROJECTILE

@export var mana_cost: int = 1
@export var stamina_cost: int = 0
@export var focus_cost: int = 0

@export var ability_scene: PackedScene

# Legacy field. We are keeping it for now so old resources do not explode.
@export var payload: DamagePayload

# New universal payload field.
# Use this for DamagePayload, DetectionPayload, future HealPayload, TriggerPayload, etc.
@export var action_payload: Resource


func get_action_payload() -> Resource:
	if action_payload != null:
		return action_payload

	if payload != null:
		return payload

	return null
