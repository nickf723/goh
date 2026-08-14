extends "res://scripts/weapons/weapon_charge_actions_v2.gd"
class_name WeaponChargeActionsV3


func start_attack(attack: WeaponAttackDefinition) -> bool:
	if attack != null and attack.extra_tags.has("weapon_charge_release"):
		attack.footwork_profile_id = ""
		attack.movement_distance = 0.0
		attack.movement_duration = 0.0
	return super.start_attack(attack)


func get_charge_actions_v3_debug_data() -> Dictionary:
	return {
		"charge_release_owns_motion": true,
		"ordinary_footwork_bypassed": true,
	}
