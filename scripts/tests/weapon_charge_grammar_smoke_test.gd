extends Node

const ChargeCatalogScript = preload("res://scripts/weapons/weapon_charge_attack_catalog_v1.gd")
const SandboxScript = preload("res://scripts/weapons/weapon_sandbox_catalog.gd")
const TrainingChain: WeaponDefinition = preload("res://data/weapons/training_chain.tres")

var failures: Array[String] = []


func _ready() -> void:
	_validate_chain_sustain()
	_validate_axe_release()
	_validate_staff_map_vault()
	if failures.is_empty():
		print("WEAPON_CHARGE_GRAMMAR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WEAPON_CHARGE_GRAMMAR_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _validate_chain_sustain() -> void:
	var profile: Dictionary = ChargeCatalogScript.get_profile("chains", "light")
	if str(profile.get("mode", "")) != ChargeCatalogScript.MODE_SUSTAIN:
		failures.append("Chain Light must resolve a sustained charge profile")
		return
	if float(profile.get("movement_multiplier", 1.0)) >= 1.0:
		failures.append("Iron Orbit must burden normal movement")
	var base: WeaponAttackDefinition = (
		TrainingChain.moveset.get_entry_attack("light")
		if TrainingChain != null and TrainingChain.moveset != null
		else null
	)
	var hold: WeaponAttackDefinition = ChargeCatalogScript.build_hold_attack(
		base,
		"chains",
		"light"
	)
	var pulse: WeaponAttackDefinition = ChargeCatalogScript.build_sustain_pulse(
		base,
		"chains",
		1.0
	)
	if hold == null or not hold.extra_tags.has("chain_charge_orbit"):
		failures.append("Chain Light hold must enter Iron Orbit")
	if pulse == null or not pulse.extra_tags.has("chain_head_authoritative"):
		failures.append("Iron Orbit damage must follow the weighted head")
	if pulse != null and pulse.cone_angle_degrees < 359.0:
		failures.append("Iron Orbit pulse must cover the head's full orbit")


func _validate_axe_release() -> void:
	var profile: Dictionary = ChargeCatalogScript.get_profile("axe", "heavy")
	if str(profile.get("mode", "")) != ChargeCatalogScript.MODE_RELEASE:
		failures.append("Axe Heavy must resolve a charged release profile")
		return
	if str(profile.get("id", "")) != "axe_lever_vault":
		failures.append("Axe Heavy charge must use the lever-vault identity")
	if float(profile.get("movement_multiplier", 1.0)) > 0.35:
		failures.append("Axe charge stance must advance slowly")
	var weapon: WeaponDefinition = SandboxScript.get_weapon("axe")
	var base: WeaponAttackDefinition = (
		weapon.moveset.get_entry_attack("heavy")
		if weapon != null and weapon.moveset != null
		else null
	)
	var hold: WeaponAttackDefinition = ChargeCatalogScript.build_hold_attack(
		base,
		"axe",
		"heavy"
	)
	var release: WeaponAttackDefinition = ChargeCatalogScript.build_release_attack(
		base,
		"axe",
		"heavy",
		1.0
	)
	var plant: WeaponAttackDefinition = ChargeCatalogScript.build_axe_plant_pulse(
		base,
		1.0
	)
	if hold == null or not hold.extra_tags.has("axe_charge_ready"):
		failures.append("Axe charge must hold the axe overhead before release")
	if release == null:
		failures.append("Axe Heavy charge must build a release attack")
		return
	for required_tag: String in [
		"axe_first_plant",
		"axe_lever_vault",
		"axe_diagonal_twist",
		"ground_slam",
	]:
		if not release.extra_tags.has(required_tag):
			failures.append("Levering Guillotine is missing " + required_tag)
	if release.movement_distance > 0.01:
		failures.append("Axe release travel must be owned by its staged motion controller")
	if plant == null or plant.damage_multiplier >= release.damage_multiplier:
		failures.append("The first axe plant must be a smaller setup impact")


func _validate_staff_map_vault() -> void:
	var profile: Dictionary = ChargeCatalogScript.get_profile("staff", "heavy")
	if str(profile.get("mode", "")) != ChargeCatalogScript.MODE_RELEASE:
		failures.append("Staff Heavy must resolve a mounted release profile")
		return
	if str(profile.get("id", "")) != "staff_map_vault":
		failures.append("Staff Heavy charge must own the map-vault identity")
	if float(profile.get("movement_multiplier", 1.0)) > 0.01:
		failures.append("Mounted Staff charge must keep Grace planted")
	var weapon: WeaponDefinition = SandboxScript.get_weapon("staff")
	var base: WeaponAttackDefinition = (
		weapon.moveset.get_entry_attack("heavy")
		if weapon != null and weapon.moveset != null
		else null
	)
	var hold: WeaponAttackDefinition = ChargeCatalogScript.build_hold_attack(
		base,
		"staff",
		"heavy"
	)
	var release: WeaponAttackDefinition = ChargeCatalogScript.build_release_attack(
		base,
		"staff",
		"heavy",
		1.0
	)
	if hold == null or not hold.extra_tags.has("staff_charge_mount"):
		failures.append("Staff Heavy hold must mount Grace on the planted staff")
	if release == null:
		failures.append("Staff Heavy charge must build a traversal release")
		return
	if not release.extra_tags.has("staff_charge_vault"):
		failures.append("Staff release must carry the map-vault tag")
	if not release.extra_tags.has("traversal"):
		failures.append("Staff release must be marked as traversal")
	if release.movement_distance > 0.01:
		failures.append("Staff map leap must be owned by the launch controller")
