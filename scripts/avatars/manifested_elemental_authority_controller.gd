extends "res://scripts/player/player_elemental_authority_controller.gd"
class_name ManifestedElementalAuthorityController


func _ready() -> void:
	super._ready()
	add_to_group("manifested_avatar_elemental_authority")


func get_modified_mana_cost(_ability: AbilityDefinition) -> int:
	return 0


func _pay_authority_cost(
	_ability: AbilityDefinition,
	_required_mana: int
) -> bool:
	return true


func _refund_authority_cost(_mana_cost: int) -> void:
	pass


func _show_message(_text: String) -> void:
	pass
