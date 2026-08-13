extends Node

const SwordWeapon: WeaponDefinition = preload("res://data/weapons/practice_sword.tres")
const SkeletalGraceScene: PackedScene = preload(
	"res://scenes/actors/player/grace_humanoid_skeletal_proxy_v1.tscn"
)
const WeaponTechniqueCatalogScript = preload(
	"res://scripts/weapons/weapon_technique_catalog.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	_validate_combo_graph()
	_validate_arc_discipline()
	_validate_context_vocabulary()
	await _validate_skeletal_language()
	_finish()


func _validate_combo_graph() -> void:
	var moveset: WeaponMovesetDefinition = SwordWeapon.get_moveset()
	_expect(moveset != null, "practice Sword resolves moveset")
	if moveset == null:
		return
	_expect(moveset.validate_graph().is_empty(), "practice Sword combo graph validates")

	var expected_light: Dictionary = {
		"sword_l1": "sword_l2",
		"sword_l2": "sword_l3",
		"sword_l3": "sword_l4",
		"sword_l4": "sword_reprise",
	}
	var expected_heavy: Dictionary = {
		"sword_l1": "sword_h1",
		"sword_l2": "sword_h2",
		"sword_l3": "sword_h3",
		"sword_l4": "sword_h4",
	}
	for attack_id_variant: Variant in expected_light.keys():
		var attack_id: String = str(attack_id_variant)
		var attack: WeaponAttackDefinition = moveset.get_attack(attack_id)
		_expect(attack != null, attack_id + " resolves")
		if attack == null:
			continue
		_expect(
			attack.next_light_attack_id == str(expected_light[attack_id]),
			attack_id + " continues the authored Light chain"
		)
		_expect(
			attack.next_heavy_attack_id == str(expected_heavy[attack_id]),
			attack_id + " branches to its depth-specific Heavy"
		)


func _validate_arc_discipline() -> void:
	var moveset: WeaponMovesetDefinition = SwordWeapon.get_moveset()
	if moveset == null:
		return
	for attack_id: String in ["sword_l1", "sword_l2", "sword_l3"]:
		var attack: WeaponAttackDefinition = moveset.get_attack(attack_id)
		if attack == null:
			continue
		_expect(
			absf(attack.windup_rotation_degrees.y) <= 60.0,
			attack_id + " windup stays inside front working envelope"
		)
		_expect(
			absf(attack.strike_rotation_degrees.y) <= 60.0,
			attack_id + " strike stays inside front working envelope"
		)
		_expect(
			absf(attack.windup_rotation_degrees.x) <= 18.0,
			attack_id + " avoids excessive blade elevation in windup"
		)
		_expect(
			absf(attack.strike_rotation_degrees.x) <= 18.0,
			attack_id + " avoids excessive blade elevation at contact"
		)

	var circular: WeaponAttackDefinition = moveset.get_attack("sword_l4")
	if circular != null:
		_expect(absf(circular.windup_rotation_degrees.y) <= 85.0, "Circular Cut windup does not reach behind Grace")
		_expect(absf(circular.strike_rotation_degrees.y) <= 105.0, "Circular Cut stays exaggerated but bounded")
		_expect(circular.cone_angle_degrees <= 180.0, "Circular Cut is a broad front-space attack, not a full orbit")

	var orbit: WeaponAttackDefinition = moveset.get_attack("sword_h4")
	if orbit != null:
		_expect(absf(orbit.windup_rotation_degrees.y) <= 100.0, "Orbit Finisher windup remains readable")
		_expect(absf(orbit.strike_rotation_degrees.y) <= 125.0, "Orbit Finisher exaggeration stays bounded")
		_expect(orbit.cone_angle_degrees <= 250.0, "Orbit Finisher does not silently return to a full 360 sweep")

	var thrust: WeaponAttackDefinition = moveset.get_attack("sword_h3")
	if thrust != null:
		_expect(absf(thrust.windup_rotation_degrees.x) <= 8.0, "Driving Thrust keeps the blade near level")
		_expect(absf(thrust.strike_rotation_degrees.x) <= 8.0, "Driving Thrust contact stays near level")


func _validate_context_vocabulary() -> void:
	var moveset: WeaponMovesetDefinition = SwordWeapon.get_moveset()
	if moveset == null:
		return
	var base_light: WeaponAttackDefinition = moveset.get_entry_attack("light")
	var base_heavy: WeaponAttackDefinition = moveset.get_entry_attack("heavy")
	_expect(base_light != null and base_heavy != null, "Sword resolves Light and Heavy entries")
	if base_light == null or base_heavy == null:
		return

	var dash_light: WeaponAttackDefinition = WeaponTechniqueCatalogScript.build_dash_attack(
		base_light,
		"sword",
		WeaponTechniqueCatalogScript.CONTEXT_DASH_LIGHT
	)
	var dash_heavy: WeaponAttackDefinition = WeaponTechniqueCatalogScript.build_dash_attack(
		base_heavy,
		"sword",
		WeaponTechniqueCatalogScript.CONTEXT_DASH_HEAVY
	)
	_expect(dash_light != null and dash_heavy != null, "Sword resolves both dash attacks")
	if dash_light != null and dash_heavy != null:
		_expect(dash_light.attack_id != dash_heavy.attack_id, "Dash Light and Heavy have distinct ids")
		_expect(dash_light.display_name == "Passing Cut", "Sword Dash Light is Passing Cut")
		_expect(dash_heavy.display_name == "Rush Break", "Sword Dash Heavy is Rush Break")
		_expect(dash_light.character_pose_id == "sword_dash_light", "Dash Light owns an authored pose")
		_expect(dash_heavy.character_pose_id == "sword_dash_heavy", "Dash Heavy owns an authored pose")

	var aerial_light: WeaponAttackDefinition = WeaponTechniqueCatalogScript.build_aerial_attack(
		base_light,
		"sword",
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_LIGHT
	)
	var aerial_heavy: WeaponAttackDefinition = WeaponTechniqueCatalogScript.build_aerial_attack(
		base_heavy,
		"sword",
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_HEAVY
	)
	_expect(aerial_light != null and aerial_heavy != null, "Sword resolves both aerial attacks")
	if aerial_light != null and aerial_heavy != null:
		_expect(aerial_light.attack_id != aerial_heavy.attack_id, "Aerial Light and Heavy have distinct ids")
		_expect(aerial_light.display_name == "Comet Slash", "Sword Aerial Light is Comet Slash")
		_expect(aerial_heavy.display_name == "Falling Edge", "Sword Aerial Heavy is Falling Edge")
		_expect(aerial_light.character_pose_id == "sword_aerial_light", "Aerial Light owns an authored pose")
		_expect(aerial_heavy.character_pose_id == "sword_aerial_heavy", "Aerial Heavy owns an authored pose")
		_expect(aerial_heavy.extra_tags.has("plunging"), "Aerial Heavy keeps descending-impact semantics")


func _validate_skeletal_language() -> void:
	var rig: Node = SkeletalGraceScene.instantiate()
	add_child(rig)
	await get_tree().process_frame
	var data: Dictionary = {}
	if rig != null and rig.has_method("get_debug_data"):
		data = rig.call("get_debug_data") as Dictionary
	_expect(bool(data.get("sword_combo_polish", false)), "active skeleton reports Sword combo polish")
	_expect(bool(data.get("sword_working_envelope", false)), "active skeleton reports bounded Sword working envelope")
	if rig != null and is_instance_valid(rig):
		rig.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("SWORD_COMBAT_LANGUAGE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SWORD_COMBAT_LANGUAGE_SMOKE_TEST: " + failure)
	get_tree().quit(1)
