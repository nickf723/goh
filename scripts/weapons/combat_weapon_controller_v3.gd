extends "res://scripts/weapons/combat_weapon_controller_v2.gd"
class_name CombatWeaponControllerV3

const MechanicalIdentityScript = preload(
	"res://scripts/weapons/weapon_mechanical_identity_v1.gd"
)


func _prepare_combat_flair_attack(
	attack: WeaponAttackDefinition
) -> WeaponAttackDefinition:
	var resolved: WeaponAttackDefinition = super._prepare_combat_flair_attack(attack)
	if resolved == null or equipped_weapon == null:
		return resolved
	return MechanicalIdentityScript.configure_attack(resolved, equipped_weapon.weapon_class)
