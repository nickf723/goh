extends Node

const AxeCatalogScript = preload(
	"res://scripts/weapons/axe_weapon_focus_catalog_v1.gd"
)
const AxeTechniqueCatalogScript = preload(
	"res://scripts/weapons/axe_weapon_technique_catalog_v2.gd"
)
const ChargeCatalogScript = preload(
	"res://scripts/weapons/weapon_charge_attack_catalog_v2.gd"
)
const FocusControllerScript = preload(
	"res://scripts/weapons/weapon_staff_axe_focus_controller_v2.gd"
)
const DefenseControllerScript = preload(
	"res://scripts/player/player_defense_controller_elemental.gd"
)
const AxeRigScene: PackedScene = preload(
	"res://scenes/weapons/axe_weapon_rig.tscn"
)
const CombatPlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player_combat_v2.tscn"
)
const SkeletalScene: PackedScene = preload(
	"res://scenes/actors/player/grace_humanoid_skeletal_proxy_v2.tscn"
)
const DojoScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_weapon_arsenal_dojo_v1.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	_validate_axe_weapon()
	_validate_axe_heavy_charge()
	_validate_axe_light_counter()
	_validate_axe_aerials()
	_validate_controller_contract()
	_validate_edge_aligned_rig()
	_validate_live_scenes()
	if failures.is_empty():
		print("AXE_WEAPON_FOCUS_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("AXE_WEAPON_FOCUS_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _validate_axe_weapon() -> void:
	var weapon: WeaponDefinition = AxeCatalogScript.build_weapon()
	if weapon == null:
		failures.append("Axe focus catalog did not build a weapon")
		return
	if weapon.weapon_class != "axe":
		failures.append("Focused axe has the wrong class")
	if not bool(weapon.get_meta("axe_focus_v1", false)):
		failures.append("Focused axe is missing authored identity metadata")
	if weapon.visual_accent_color.b <= weapon.visual_accent_color.r:
		failures.append("Dojo axe must use a blue accent")
	var moveset: WeaponMovesetDefinition = weapon.get_moveset()
	if moveset == null:
		failures.append("Focused axe has no moveset")
		return
	for graph_error: String in moveset.validate_graph():
		failures.append("Axe moveset graph: " + graph_error)
	var momentum_builders: int = 0
	var openers: int = 0
	var exploits: int = 0
	for attack: WeaponAttackDefinition in moveset.attacks:
		if attack == null:
			continue
		if attack.extra_tags.has("axe_momentum_builder"):
			momentum_builders += 1
		if attack.extra_tags.has("axe_opener"):
			openers += 1
		if attack.extra_tags.has("axe_exploit"):
			exploits += 1
		if attack.extra_tags.has("axe_overhead") and absf(attack.strike_rotation_degrees.z) < 80.0:
			failures.append(attack.attack_id + " must roll the blade edge into the overhead swing plane")
	if momentum_builders < 3:
		failures.append("Axe Light chain must build momentum across all three beats")
	if openers < 2:
		failures.append("Axe moveset needs multiple ways to create an opening")
	if exploits < 3:
		failures.append("Axe moveset needs multiple opening payoffs")


func _validate_axe_heavy_charge() -> void:
	var profile: Dictionary = ChargeCatalogScript.get_profile("axe", "heavy")
	if float(profile.get("threshold", 1.0)) > 0.2:
		failures.append("Axe Heavy charge must engage quickly")
	if float(profile.get("full_charge", 2.0)) > 1.0:
		failures.append("Axe Heavy must reach full charge in under one second")
	var weapon: WeaponDefinition = AxeCatalogScript.build_weapon()
	var base: WeaponAttackDefinition = weapon.moveset.get_entry_attack("heavy")
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
	if release == null or release.startup_time > 0.82:
		failures.append("Levering Guillotine release must use the faster timeline")
	if release != null and not release.extra_tags.has("axe_exploit"):
		failures.append("Levering Guillotine final slam must exploit the first plant")
	if plant == null or not plant.extra_tags.has("axe_opener"):
		failures.append("Levering Guillotine first plant must create an opening")


func _validate_axe_light_counter() -> void:
	var profile: Dictionary = ChargeCatalogScript.get_profile("axe", "light")
	if str(profile.get("id", "")) != "axe_counter_guard":
		failures.append("Axe Light charge must resolve Breakwater Catch")
	if str(profile.get("mode", "")) != ChargeCatalogScript.MODE_COUNTER:
		failures.append("Axe Light charge must use counter mode")
	if float(profile.get("movement_multiplier", 1.0)) > 0.01:
		failures.append("Breakwater Catch must plant Grace in place")
	var weapon: WeaponDefinition = AxeCatalogScript.build_weapon()
	var base: WeaponAttackDefinition = weapon.moveset.get_entry_attack("light")
	var hold: WeaponAttackDefinition = ChargeCatalogScript.build_hold_attack(
		base,
		"axe",
		"light"
	)
	if hold == null:
		failures.append("Axe Light charge did not build its guard stance")
	else:
		for tag: String in [
			"weapon_charge_hold",
			"axe_counter_guard",
			"weapon_counter_guard",
		]:
			if not hold.extra_tags.has(tag):
				failures.append("Breakwater Catch is missing " + tag)
	var reversal: WeaponAttackDefinition = (
		AxeTechniqueCatalogScript.build_counter_reversal_attack(1.0)
	)
	if reversal == null:
		failures.append("Perfect-timed axe counter did not build a reversal")
	else:
		if not reversal.extra_tags.has("axe_counter_reversal"):
			failures.append("Counter release is missing reversal semantics")
		if not reversal.extra_tags.has("axe_exploit"):
			failures.append("Counter reversal must exploit the caught attack opening")
		if not reversal.extra_tags.has("axe_counter_perfect"):
			failures.append("Perfect counter timing must receive its perfect tag")
		if absf(reversal.strike_rotation_degrees.z) < 80.0:
			failures.append("Counter reversal must keep the axe edge in plane")


func _validate_axe_aerials() -> void:
	var light_base: WeaponAttackDefinition = WeaponAttackDefinition.new()
	light_base.input_kind = "light"
	light_base.startup_time = 0.18
	light_base.active_time = 0.08
	light_base.recovery_time = 0.28
	light_base.damage_multiplier = 0.9
	light_base.stance_multiplier = 0.9
	light_base.attack_range = 2.8
	light_base.cone_angle_degrees = 110.0
	light_base.extra_tags = ["aerial_light"]
	var aerial_light: WeaponAttackDefinition = (
		AxeTechniqueCatalogScript.configure_aerial_light(light_base)
	)
	if aerial_light == null or not aerial_light.extra_tags.has("axe_aerial_drive"):
		failures.append("Axe Aerial Light must own the forward-drive identity")
	elif not aerial_light.extra_tags.has("axe_momentum_builder"):
		failures.append("Axe Aerial Light must feed the momentum loop")

	var heavy_base: WeaponAttackDefinition = WeaponAttackDefinition.new()
	heavy_base.input_kind = "heavy"
	heavy_base.startup_time = 0.3
	heavy_base.active_time = 0.08
	heavy_base.recovery_time = 0.46
	heavy_base.damage_multiplier = 1.3
	heavy_base.stance_multiplier = 1.4
	heavy_base.attack_range = 2.9
	heavy_base.cone_angle_degrees = 105.0
	heavy_base.extra_tags = ["aerial_heavy", "ground_slam"]
	var aerial_heavy: WeaponAttackDefinition = (
		AxeTechniqueCatalogScript.configure_aerial_heavy(heavy_base)
	)
	if aerial_heavy == null or not aerial_heavy.extra_tags.has("axe_aerial_crash"):
		failures.append("Axe Aerial Heavy must own the crashing-overhead identity")
	else:
		if not aerial_heavy.extra_tags.has("axe_edge_aligned"):
			failures.append("Axe Aerial Heavy must land edge-first")
		if aerial_heavy.extra_tags.has("ground_slam"):
			failures.append("Axe Aerial Heavy must defer radial impact to the landing controller")
		if not aerial_heavy.extra_tags.has("plunging"):
			failures.append("Axe Aerial Heavy must arm the plunge landing")


func _validate_controller_contract() -> void:
	var controller: Node = FocusControllerScript.new()
	if controller == null:
		failures.append("Staff/Axe focus controller could not instantiate")
		return
	for method_name: String in [
		"get_axe_momentum_ratio",
		"get_axe_focus_debug_data",
		"get_axe_focus_v2_debug_data",
		"get_staff_focus_v3_debug_data",
		"resolve_incoming_weapon_counter",
		"is_axe_counter_guard_charging",
	]:
		if not controller.has_method(method_name):
			failures.append("Focus controller is missing " + method_name)
	controller.free()
	var defense: Node = DefenseControllerScript.new()
	if defense == null or not defense.has_method("_resolve_weapon_counter_contract"):
		failures.append("Player defense lost the weapon counter contract")
	if defense != null:
		defense.free()


func _validate_edge_aligned_rig() -> void:
	var rig: Node3D = AxeRigScene.instantiate() as Node3D
	if rig == null:
		failures.append("Axe rig failed to instantiate")
		return
	add_child(rig)
	var weapon: WeaponDefinition = AxeCatalogScript.build_weapon()
	rig.call("configure_weapon", weapon, null)
	var overhead: WeaponAttackDefinition = weapon.moveset.get_attack("axe_h0")
	rig.call("begin_attack", overhead, 1.0)
	rig.call("update_attack_pose", overhead, overhead.startup_time, 1.0)
	if absf(rig.rotation_degrees.z) < 80.0:
		failures.append("Axe rig overhead contact must keep the blade edge rolled into plane")
	if not rig.has_method("get_support_grip_influence"):
		failures.append("Axe rig must expose its heavy leverage grip contract")
	var counter_hold: WeaponAttackDefinition = ChargeCatalogScript.build_hold_attack(
		weapon.moveset.get_entry_attack("light"),
		"axe",
		"light"
	)
	rig.call("begin_attack", counter_hold, 1.0)
	if float(rig.call("get_support_grip_influence")) < 0.9:
		failures.append("Breakwater Catch must use a firm two-handed grip")
	rig.queue_free()


func _validate_live_scenes() -> void:
	if CombatPlayerScene == null:
		failures.append("Combat player failed to preload")
	if SkeletalScene == null:
		failures.append("Focused skeletal scene failed to preload")
	if DojoScene == null:
		failures.append("Arsenal dojo failed to preload")
