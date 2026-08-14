extends Node

const ChargeCatalogScript = preload("res://scripts/weapons/weapon_charge_attack_catalog_v1.gd")
const SandboxScript = preload("res://scripts/weapons/weapon_sandbox_catalog.gd")
const TrainingChain: WeaponDefinition = preload("res://data/weapons/training_chain.tres")

var failures: Array[String] = []

func _ready() -> void:
	_validate_chain_sustain()
	_validate_axe_release()
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
	var base: WeaponAttackDefinition = TrainingChain.moveset.get_entry_attack("light") if TrainingChain != null and TrainingChain.moveset != null else null
	var hold: WeaponAttackDefinition = ChargeCatalogScript.build_hold_attack(base, "chains", "light")
	var pulse: WeaponAttackDefinition = ChargeCatalogScript.build_sustain_pulse(base, "chains", 1.0)
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
	var weapon: WeaponDefinition = SandboxScript.get_weapon("axe")
	var base: WeaponAttackDefinition = weapon.moveset.get_entry_attack("heavy") if weapon != null and weapon.moveset != null else null
	var release: WeaponAttackDefinition = ChargeCatalogScript.build_release_attack(base, "axe", "heavy", 1.0)
	if release == null:
		failures.append("Axe Heavy charge must build a release attack")
		return
	if release.display_name != "Vaulting Guillotine":
		failures.append("Axe Heavy charge must resolve Vaulting Guillotine")
	if not release.extra_tags.has("axe_vault_slam") or not release.extra_tags.has("ground_slam"):
		failures.append("Vaulting Guillotine must carry vault and ground-slam semantics")
