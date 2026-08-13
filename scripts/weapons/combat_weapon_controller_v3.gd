extends "res://scripts/weapons/combat_weapon_controller_v2.gd"
class_name CombatWeaponControllerV3

const MechanicalIdentityScript = preload(
	"res://scripts/weapons/weapon_mechanical_identity_v1.gd"
)
const BoomerangPathScript = preload(
	"res://scripts/weapons/boomerang_path_solver_v2.gd"
)


func _prepare_combat_flair_attack(
	attack: WeaponAttackDefinition
) -> WeaponAttackDefinition:
	var resolved: WeaponAttackDefinition = super._prepare_combat_flair_attack(attack)
	if resolved == null or equipped_weapon == null:
		return resolved
	return MechanicalIdentityScript.configure_attack(resolved, equipped_weapon.weapon_class)


func find_targets(attack: WeaponAttackDefinition) -> Array[Node]:
	if attack == null or equipped_weapon == null:
		return super.find_targets(attack)
	if equipped_weapon.weapon_class != "boomerang" or not attack.extra_tags.has("boomerang_throw"):
		return super.find_targets(attack)
	if (
		attack.extra_tags.has("boomerang_hook_throw")
		or attack.extra_tags.has("boomerang_s_curve_throw")
		or attack.extra_tags.has("boomerang_orbit_throw")
	):
		return BoomerangPathScript.find_targets(self, attack)
	return super.find_targets(attack)


func _uses_live_ranged_aim() -> bool:
	if equipped_weapon != null and equipped_weapon.weapon_class == "boomerang":
		return current_attack != null and current_attack.extra_tags.has("boomerang_throw")
	return super._uses_live_ranged_aim()
