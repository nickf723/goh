extends Resource
class_name SummonDefinition

@export var summon_id: String = "new_summon"
@export var species_id: String = ""
@export var unlock_id: String = ""
@export var display_name: String = "Summon"
@export var summon_scene: PackedScene
@export var maximum_active: int = 1
@export var presence_cost: int = 1
@export var mana_cost: int = 3
@export var defeat_cooldown: float = 8.0
@export var summon_offset: Vector3 = Vector3(1.8, 0.2, -1.5)
@export var roles: Array[String] = ["companion"]
@export var supported_familiar_roles: Array[String] = []
@export var supported_technique_ids: Array[String] = []
@export var transformation_supported: bool = false


func get_debug_data() -> Dictionary:
	return {
		"id": summon_id,
		"species_id": species_id,
		"unlock_id": unlock_id,
		"name": display_name,
		"maximum_active": maximum_active,
		"presence_cost": presence_cost,
		"mana_cost": mana_cost,
		"defeat_cooldown": defeat_cooldown,
		"roles": roles,
		"supported_familiar_roles": supported_familiar_roles,
		"supported_technique_ids": supported_technique_ids,
		"transformation_supported": transformation_supported,
	}
