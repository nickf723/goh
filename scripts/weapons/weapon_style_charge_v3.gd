extends "res://scripts/weapons/weapon_charge_controller_v2.gd"
class_name WeaponStyleChargeV3

func _apply_chain_momentum_to_attack(_attack: WeaponAttackDefinition) -> void:
	pass

func _update_chain_momentum(_delta: float) -> void:
	chain_momentum_stacks = 0
	chain_momentum_timer = 0.0
	chain_attack_momentum_spent = 0

func get_charge_v3_debug_data() -> Dictionary:
	var data: Dictionary = get_charge_v2_debug_data()
	data["legacy_chain_momentum_disabled"] = true
	data["chain_state_is_head_plus_hold"] = true
	return data
