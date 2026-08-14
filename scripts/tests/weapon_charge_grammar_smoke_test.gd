extends Node

const ChargeCatalogScript = preload(
	"res://scripts/weapons/weapon_charge_attack_catalog_v1.gd"
)
const SettledChargeCatalogScript = preload(
	"res://scripts/weapons/weapon_charge_attack_catalog_v2.gd"
)
const StaffFocusCatalogScript = preload(
	"res://scripts/weapons/staff_weapon_focus_catalog_v1.gd"
)
const SandboxScript = preload("res://scripts/weapons/weapon_sandbox_catalog.gd")
const TrainingChain: WeaponDefinition = preload("res://data/weapons/training_chain.tres")

var failures: Array[String] = []


func _ready() -> void:
	_validate_chain_sustain()
	_validate_axe_release()
	_validate_staff_ground_charges()
	_validate_staff_moveset()
	_validate_staff_aerial_vault()
	if failures.is_empty():
		print("WEAPON_CHARGE_GRAMMAR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WEAPON_CHARGE_GRAMMAR_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _validate_hold_timing(hold: WeaponAttackDefinition, label: String) -> void:
	if hold == null:
		return
	if hold.startup_time > 0.22:
		failures.append(label + " held pose must settle quickly")
	if hold.active_time < 30.0:
		failures.append(label + " must remain held while the input stays down")
	if hold.footwork_profile_id != "":
		failures.append(label + " must not inherit ordinary attack footwork")


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
	var hold: WeaponAttackDefinition = SettledChargeCatalogScript.build_hold_attack(
		base,
		"chains",
		"light"
	)
	var pulse: WeaponAttackDefinition = SettledChargeCatalogScript.build_sustain_pulse(
		base,
		"chains",
		1.0
	)
	_validate_hold_timing(hold, "Iron Orbit")
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
	var hold: WeaponAttackDefinition = SettledChargeCatalogScript.build_hold_attack(
		base,
		"axe",
		"heavy"
	)
	var release: WeaponAttackDefinition = SettledChargeCatalogScript.build_release_attack(
		base,
		"axe",
		"heavy",
		1.0
	)
	var plant: WeaponAttackDefinition = SettledChargeCatalogScript.build_axe_plant_pulse(
		base,
		1.0
	)
	_validate_hold_timing(hold, "Guillotine Ready")
	if hold == null or not hold.extra_tags.has("axe_charge_ready"):
		failures.append("Axe charge must hold the axe overhead before release")
	if release == null:
		failures.append("Axe Heavy charge must build a release attack")
		return
	for required_tag: String in [
		"axe_first_plant",
		"axe_lever_vault",
		"axe_diagonal_twist",
		"forward_ground_slam",
		"ground_impact",
	]:
		if not release.extra_tags.has(required_tag):
			failures.append("Levering Guillotine is missing " + required_tag)
	if release.extra_tags.has("ground_slam"):
		failures.append("Levering Guillotine must not collapse into a radial slam hitbox")
	if release.movement_distance > 0.01:
		failures.append("Axe release travel must be owned by its staged motion controller")
	if plant == null or plant.damage_multiplier >= release.damage_multiplier:
		failures.append("The first axe plant must be a smaller setup impact")


func _validate_staff_ground_charges() -> void:
	var staff: WeaponDefinition = SandboxScript.get_weapon("staff")
	StaffFocusCatalogScript.apply_to_weapon(staff)
	if staff == null or staff.moveset == null:
		failures.append("Focused Staff weapon or moveset is missing")
		return
	var light_base: WeaponAttackDefinition = staff.moveset.get_entry_attack("light")
	var heavy_base: WeaponAttackDefinition = staff.moveset.get_entry_attack("heavy")

	var light_profile: Dictionary = ChargeCatalogScript.get_profile("staff", "light")
	if str(light_profile.get("id", "")) != "staff_returning_throw":
		failures.append("Staff Light charge must own the returning-throw identity")
	if str(light_profile.get("mode", "")) != ChargeCatalogScript.MODE_RELEASE:
		failures.append("Staff Light charge must release a projectile attack")
	var light_hold: WeaponAttackDefinition = SettledChargeCatalogScript.build_hold_attack(
		light_base,
		"staff",
		"light"
	)
	var light_release: WeaponAttackDefinition = SettledChargeCatalogScript.build_release_attack(
		light_base,
		"staff",
		"light",
		1.0
	)
	_validate_hold_timing(light_hold, "Returning Comet Ready")
	if light_hold == null or not light_hold.extra_tags.has("staff_throw_charge"):
		failures.append("Staff Light hold must enter the low throw-ready pose")
	if light_release == null:
		failures.append("Staff Light charge must build Returning Comet")
	else:
		if not light_release.extra_tags.has("staff_returning_throw"):
			failures.append("Returning Comet is missing its returning staff tag")
		if not light_release.extra_tags.has("projectile"):
			failures.append("Returning Comet must use moving projectile contacts")
		if light_release.attack_range < 9.0:
			failures.append("Full-charge Returning Comet must travel substantial range")

	var heavy_profile: Dictionary = ChargeCatalogScript.get_profile("staff", "heavy")
	if str(heavy_profile.get("id", "")) != "staff_angel_ring":
		failures.append("Grounded Staff Heavy charge must own Whirling Bastion")
	if str(heavy_profile.get("mode", "")) != ChargeCatalogScript.MODE_SUSTAIN:
		failures.append("Whirling Bastion must be an ongoing concentrated attack")
	if float(heavy_profile.get("movement_multiplier", 1.0)) > 0.01:
		failures.append("Whirling Bastion must plant Grace in place")
	var heavy_hold: WeaponAttackDefinition = SettledChargeCatalogScript.build_hold_attack(
		heavy_base,
		"staff",
		"heavy"
	)
	var heavy_pulse: WeaponAttackDefinition = SettledChargeCatalogScript.build_sustain_pulse(
		heavy_base,
		"staff",
		1.0
	)
	_validate_hold_timing(heavy_hold, "Whirling Bastion")
	if heavy_hold == null or not heavy_hold.extra_tags.has("staff_angel_ring"):
		failures.append("Staff Heavy hold must enter the front spinning guard")
	if heavy_pulse == null:
		failures.append("Whirling Bastion must generate repeated front contacts")
	else:
		if heavy_pulse.cone_angle_degrees >= 180.0:
			failures.append("Whirling Bastion must stay front-facing rather than radial")
		if heavy_pulse.damage_multiplier >= 0.75:
			failures.append("Whirling Bastion contacts must favor pressure over burst damage")


func _validate_staff_moveset() -> void:
	var staff: WeaponDefinition = SandboxScript.get_weapon("staff")
	StaffFocusCatalogScript.apply_to_weapon(staff)
	if staff == null or staff.moveset == null:
		return
	for error: String in staff.moveset.validate_graph():
		failures.append("Focused Staff graph: " + error)
	if staff.moveset.attacks.size() != 7:
		failures.append("Focused Staff must provide three Lights and four Heavy branches")
	for attack: WeaponAttackDefinition in staff.moveset.attacks:
		if attack == null:
			continue
		if absf(attack.strike_rotation_degrees.x) > 18.0:
			failures.append(attack.attack_id + " points too far vertically at contact")
	var thrust: WeaponAttackDefinition = staff.moveset.get_attack("staff_l3")
	var finisher: WeaponAttackDefinition = staff.moveset.get_attack("staff_h3")
	if thrust == null or not thrust.extra_tags.has("thrust"):
		failures.append("Staff Light three must be a real passing thrust")
	if finisher == null or not finisher.extra_tags.has("multi_hit_2"):
		failures.append("Spinning Ward must preserve its double-contact identity")


func _validate_staff_aerial_vault() -> void:
	var descent: WeaponAttackDefinition = StaffFocusCatalogScript.build_aerial_descent_attack()
	var bend: WeaponAttackDefinition = StaffFocusCatalogScript.build_aerial_bend_attack()
	var launch: WeaponAttackDefinition = StaffFocusCatalogScript.build_aerial_launch_attack(1.0)
	var drop: WeaponAttackDefinition = StaffFocusCatalogScript.build_aerial_overheld_drop_attack()
	if descent == null or not descent.extra_tags.has("staff_vault_descent"):
		failures.append("Aerial Heavy must begin with a descending staff plant")
	if bend == null or not bend.extra_tags.has("staff_vault_bend"):
		failures.append("Aerial Heavy must expose a held bending state")
	if launch == null:
		failures.append("Aerial Heavy timed release must build a launch attack")
	else:
		if not launch.extra_tags.has("staff_vault_launch"):
			failures.append("Timed Aerial Heavy release is missing the vault-launch tag")
		if not launch.extra_tags.has("traversal"):
			failures.append("Staff vault launch must be marked as traversal")
	if drop == null or not drop.extra_tags.has("staff_vault_overheld_drop"):
		failures.append("Overheld Aerial Heavy must resolve to a failed drop")
