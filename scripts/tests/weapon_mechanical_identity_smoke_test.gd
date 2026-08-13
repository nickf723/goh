extends Node

const SandboxScript = preload("res://scripts/weapons/weapon_sandbox_catalog.gd")
const MechanicalIdentityScript = preload("res://scripts/weapons/weapon_mechanical_identity_v1.gd")
const CombatIdentityScript = preload("res://scripts/weapons/weapon_class_combat_identity.gd")
const TrainingChain: WeaponDefinition = preload("res://data/weapons/training_chain.tres")

var failures: Array[String] = []


func _ready() -> void:
	_validate_boomerang_hybrid()
	_validate_gauntlet_boxing()
	_validate_colossal_chain()
	if failures.is_empty():
		print("WEAPON_MECHANICAL_IDENTITY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WEAPON_MECHANICAL_IDENTITY_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _validate_boomerang_hybrid() -> void:
	var weapon: WeaponDefinition = SandboxScript.get_weapon("boomerang")
	if weapon == null or weapon.moveset == null:
		failures.append("Boomerang sandbox weapon is missing")
		return
	var light: WeaponAttackDefinition = _configured(weapon.moveset.get_attack("boomerang_proxy_l1"), "boomerang")
	if light == null:
		failures.append("Boomerang Light is missing")
	else:
		if not light.extra_tags.has("boomerang_melee"):
			failures.append("Boomerang Light must remain in hand as melee")
		if light.extra_tags.has("ranged") or light.extra_tags.has("returning"):
			failures.append("Boomerang Light must not retain projectile tags")
		if light.attack_range > 2.45:
			failures.append("Boomerang Light must use melee reach")
		if CombatIdentityScript.get_geometry_mode("boomerang", light) != CombatIdentityScript.GEOMETRY_ARC:
			failures.append("Boomerang Light must use melee arc geometry")

	var expected_tags: Array[String] = [
		"boomerang_straight_throw",
		"boomerang_hook_throw",
		"boomerang_s_curve_throw",
		"boomerang_orbit_throw",
	]
	for index: int in range(4):
		var attack_id: String = "boomerang_proxy_h" + str(index)
		var heavy: WeaponAttackDefinition = _configured(weapon.moveset.get_attack(attack_id), "boomerang")
		if heavy == null:
			failures.append("Missing Boomerang Heavy branch " + str(index))
			continue
		if not heavy.extra_tags.has("boomerang_throw"):
			failures.append(attack_id + " must release the boomerang")
		if not heavy.extra_tags.has(expected_tags[index]):
			failures.append(attack_id + " is missing its unique throw path")
		if CombatIdentityScript.get_geometry_mode("boomerang", heavy) != CombatIdentityScript.GEOMETRY_RETURNING_RAY:
			failures.append(attack_id + " must use returning projectile geometry")


func _validate_gauntlet_boxing() -> void:
	var weapon: WeaponDefinition = SandboxScript.get_weapon("gauntlets")
	if weapon == null or weapon.moveset == null:
		failures.append("Gauntlet sandbox weapon is missing")
		return
	var light_tags: Array[String] = ["boxing_jab", "boxing_cross", "boxing_hook"]
	for index: int in range(3):
		var attack_id: String = "gauntlets_proxy_l" + str(index + 1)
		var attack: WeaponAttackDefinition = _configured(weapon.moveset.get_attack(attack_id), "gauntlets")
		if attack == null or not attack.extra_tags.has(light_tags[index]):
			failures.append(attack_id + " must map to a real boxing punch")

	var uppercut: WeaponAttackDefinition = _configured(weapon.moveset.get_attack("gauntlets_proxy_h0"), "gauntlets")
	var overhand: WeaponAttackDefinition = _configured(weapon.moveset.get_attack("gauntlets_proxy_h1"), "gauntlets")
	var body_hook: WeaponAttackDefinition = _configured(weapon.moveset.get_attack("gauntlets_proxy_h2"), "gauntlets")
	var finisher: WeaponAttackDefinition = _configured(weapon.moveset.get_attack("gauntlets_proxy_h3"), "gauntlets")
	if uppercut == null or not uppercut.extra_tags.has("boxing_uppercut") or not uppercut.extra_tags.has("launcher"):
		failures.append("Gauntlet neutral Heavy must be a launching uppercut")
	if overhand == null or not overhand.extra_tags.has("boxing_overhand") or overhand.extra_tags.has("launcher"):
		failures.append("Gauntlet Heavy branch one must be a grounded overhand")
	if body_hook == null or not body_hook.extra_tags.has("boxing_body_hook") or body_hook.extra_tags.has("launcher"):
		failures.append("Gauntlet Heavy branch two must be a grounded body hook")
	if finisher == null or not finisher.extra_tags.has("boxing_finisher") or not finisher.extra_tags.has("launcher"):
		failures.append("Gauntlet final Heavy must be the champion uppercut")


func _validate_colossal_chain() -> void:
	if TrainingChain == null or TrainingChain.moveset == null:
		failures.append("Training Chain is missing")
		return
	var source_light: WeaponAttackDefinition = TrainingChain.moveset.get_attack("chain_l1")
	var source_heavy: WeaponAttackDefinition = TrainingChain.moveset.get_attack("chain_h0")
	var light: WeaponAttackDefinition = _configured(source_light, "chains")
	var heavy: WeaponAttackDefinition = _configured(source_heavy, "chains")
	if light == null or heavy == null:
		failures.append("Chain entry attacks are missing")
		return
	if not light.extra_tags.has("chain_ground_drag") or not light.extra_tags.has("chain_area_sweep"):
		failures.append("Chain Light must drag and resolve as a wide sweep")
	if not heavy.extra_tags.has("chain_ground_drag") or not heavy.extra_tags.has("chain_ground_blast"):
		failures.append("Chain Heavy slam must drag and resolve as a ground blast")
	if source_light != null and light.startup_time <= source_light.startup_time:
		failures.append("Colossal Chain Light must have a larger anticipation delay")
	if source_heavy != null and heavy.damage_multiplier <= source_heavy.damage_multiplier:
		failures.append("Colossal Chain Heavy must gain damage for its commitment")
	if heavy.cone_angle_degrees < 359.0:
		failures.append("Colossal Chain slam must threaten a full radial area")
	if heavy.movement_distance > 0.1:
		failures.append("Colossal Chain Heavy must keep Grace planted")


func _configured(source: WeaponAttackDefinition, weapon_class: String) -> WeaponAttackDefinition:
	if source == null:
		return null
	var copy: WeaponAttackDefinition = source.duplicate(true) as WeaponAttackDefinition
	if copy == null:
		return null
	return MechanicalIdentityScript.configure_attack(copy, weapon_class)
