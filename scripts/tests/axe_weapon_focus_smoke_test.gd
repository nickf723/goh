extends Node

const AxeCatalogScript = preload(
	"res://scripts/weapons/axe_weapon_focus_catalog_v1.gd"
)
const ChargeCatalogScript = preload(
	"res://scripts/weapons/weapon_charge_attack_catalog_v2.gd"
)
const FocusControllerScript = preload(
	"res://scripts/weapons/weapon_staff_axe_focus_controller_v1.gd"
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
	_validate_axe_charge()
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


func _validate_axe_charge() -> void:
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


func _validate_controller_contract() -> void:
	var controller: Node = FocusControllerScript.new()
	if controller == null:
		failures.append("Staff/Axe focus controller could not instantiate")
		return
	for method_name: String in [
		"get_axe_momentum_ratio",
		"get_axe_focus_debug_data",
		"get_staff_focus_v3_debug_data",
	]:
		if not controller.has_method(method_name):
			failures.append("Focus controller is missing " + method_name)
	controller.free()


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
	rig.queue_free()


func _validate_live_scenes() -> void:
	if CombatPlayerScene == null:
		failures.append("Combat player failed to preload")
	if SkeletalScene == null:
		failures.append("Focused skeletal scene failed to preload")
	if DojoScene == null:
		failures.append("Arsenal dojo failed to preload")
