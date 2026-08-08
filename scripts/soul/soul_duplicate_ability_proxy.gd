extends Node3D
class_name SoulDuplicateAbilityProxy

var current_ability: AbilityDefinition = null
var mirrored_direction: Vector3 = Vector3.FORWARD


func set_mirrored_ability(
	ability: AbilityDefinition,
	direction: Vector3 = Vector3.FORWARD
) -> void:
	current_ability = ability
	mirrored_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD


func get_current_ability() -> AbilityDefinition:
	return current_ability


func get_player_cast_origin(player: Node3D) -> Vector3:
	if player == null:
		return global_position
	var hand: Node3D = player.find_child("RightHandAnchor", true, false) as Node3D
	if hand != null:
		return hand.global_position
	return player.global_position + Vector3.UP * 0.9


func get_cast_direction(_player: Node3D, _origin: Vector3) -> Vector3:
	return mirrored_direction


func get_debug_data() -> Dictionary:
	return {
		"soul_duplicate_ability_proxy": true,
		"spell_id": current_ability.get_spell_id() if current_ability != null else "none",
		"direction": mirrored_direction,
	}
