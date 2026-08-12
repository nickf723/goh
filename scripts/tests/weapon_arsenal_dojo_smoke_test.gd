extends Node

const DojoScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_weapon_arsenal_dojo_v1.tscn"
)
const WeaponSandboxCatalogScript = preload(
	"res://scripts/weapons/weapon_sandbox_catalog.gd"
)
const WeaponClassMotionCatalogScript = preload(
	"res://scripts/weapons/weapon_class_motion_catalog.gd"
)
const WeaponPoseCatalogRouterScript = preload(
	"res://scripts/weapons/weapon_pose_catalog_router.gd"
)
const CombatFootworkCatalogScript = preload(
	"res://scripts/weapons/combat_footwork_catalog.gd"
)
const PracticeSword: WeaponDefinition = preload("res://data/weapons/practice_sword.tres")
const TrainingHammer: WeaponDefinition = preload("res://data/weapons/training_hammer.tres")

var failures: Array[String] = []
var dojo: Node


func _ready() -> void:
	GameState.reset_run()
	_validate_catalogs()
	_validate_motion_fallback_contract()
	dojo = DojoScene.instantiate()
	add_child(dojo)
	for _index: int in range(8):
		await get_tree().process_frame
	await get_tree().physics_frame
	_validate_dojo_runtime()
	await _validate_player_integration()
	if dojo != null and is_instance_valid(dojo):
		dojo.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_catalogs() -> void:
	var classes: Array[String] = WeaponSandboxCatalogScript.get_all_weapon_classes()
	_expect(classes.size() == 16, "sandbox exposes all sixteen weapon classes")
	var unique: Dictionary = {}
	for weapon_class: String in classes:
		unique[weapon_class] = true
		var weapon: WeaponDefinition = WeaponSandboxCatalogScript.get_weapon(weapon_class)
		_expect(weapon != null, "sandbox builds " + weapon_class)
		if weapon == null:
			continue
		_expect(weapon.weapon_class == weapon_class, weapon_class + " preserves class id")
		_expect(weapon.get_moveset() != null, weapon_class + " owns a moveset")
		if weapon.get_moveset() != null:
			_expect(
				weapon.get_moveset().validate_graph().is_empty(),
				weapon_class + " moveset graph validates"
			)
		if WeaponSandboxCatalogScript.get_status_label(weapon_class) == "PROXY":
			_expect(weapon.runtime_rig_scene != null, weapon_class + " proxy has a readable runtime silhouette")
	_expect(unique.size() == 16, "sandbox class list has no duplicates")

	for failure: String in WeaponSandboxCatalogScript.validate_catalog():
		failures.append("sandbox catalog: " + failure)
	for failure: String in WeaponClassMotionCatalogScript.validate_profiles():
		failures.append("class motion: " + failure)


func _validate_motion_fallback_contract() -> void:
	var sword_attack: WeaponAttackDefinition = PracticeSword.get_moveset().get_entry_attack("light")
	_expect(sword_attack != null, "practice sword light entry exists")
	if sword_attack != null:
		var original_pose: String = sword_attack.character_pose_id
		var original_footwork: String = sword_attack.footwork_profile_id
		var resolved_sword: WeaponAttackDefinition = WeaponClassMotionCatalogScript.prepare_attack(
			sword_attack,
			"sword"
		)
		_expect(resolved_sword == sword_attack, "authored sword attack remains authoritative")
		_expect(resolved_sword.character_pose_id == original_pose, "authored sword pose id is preserved")
		_expect(resolved_sword.footwork_profile_id == original_footwork, "authored sword footwork id is preserved")

	var hammer_attack: WeaponAttackDefinition = TrainingHammer.get_moveset().get_entry_attack("light")
	_expect(hammer_attack != null, "training hammer light entry exists")
	if hammer_attack == null:
		return
	var original_hammer_pose: String = hammer_attack.character_pose_id
	var resolved_hammer: WeaponAttackDefinition = WeaponClassMotionCatalogScript.prepare_attack(
		hammer_attack,
		"hammer"
	)
	_expect(resolved_hammer != null, "hammer fallback resolves")
	if resolved_hammer == null:
		return
	_expect(resolved_hammer != hammer_attack, "fallback duplicates rather than mutating authored attack resource")
	_expect(hammer_attack.character_pose_id == original_hammer_pose, "hammer source resource stays untouched")
	_expect(
		WeaponClassMotionCatalogScript.has_profile(resolved_hammer.character_pose_id),
		"hammer receives a class-specific body pose"
	)
	_expect(
		WeaponPoseCatalogRouterScript.has_profile(resolved_hammer.character_pose_id),
		"pose router recognizes hammer class motion"
	)
	_expect(
		CombatFootworkCatalogScript.has_profile(resolved_hammer.footwork_profile_id),
		"hammer receives a valid temporary footwork proxy"
	)
	var sample: Dictionary = WeaponPoseCatalogRouterScript.sample_attack(
		resolved_hammer,
		resolved_hammer.get_startup_duration() * 0.75,
		1.0
	)
	_expect(not sample.is_empty(), "hammer class motion produces a body sample")
	_expect(bool(sample.get("fallback_class_motion", false)), "hammer sample identifies fallback class motion")


func _validate_dojo_runtime() -> void:
	_expect(dojo != null, "arsenal dojo instantiates")
	if dojo == null:
		return
	_expect(dojo.is_in_group("weapon_arsenal_dojo"), "dojo joins weapon_arsenal_dojo group")
	var data: Dictionary = dojo.call("get_debug_data")
	_expect(int(data.get("class_count", 0)) == 16, "dojo builds sixteen weapon pedestals")
	_expect(dojo.get_node_or_null("SwordPedestal") != null, "dojo contains Sword pedestal")
	_expect(dojo.get_node_or_null("ShurikenPedestal") != null, "dojo contains Shuriken pedestal")
	_expect(dojo.get_node_or_null("TrainingTargets/CenterTarget") != null, "dojo contains neutral comparison target")
	_expect(dojo.get_node_or_null("TrainingTargets/RangeTarget") != null, "dojo contains range comparison target")
	_expect(dojo.get_node_or_null("LiveEnemies") != null, "dojo owns optional live sparring root")


func _validate_player_integration() -> void:
	if dojo == null:
		return
	var player: CharacterBody3D = dojo.get_node_or_null("Player") as CharacterBody3D
	var controller: SafeWeaponController = (
		dojo.get_node_or_null("Player/WeaponController") as SafeWeaponController
	)
	_expect(player != null, "dojo uses canonical player")
	_expect(controller != null, "dojo uses SafeWeaponController")
	if player == null or controller == null:
		return
	var hammer: WeaponDefinition = WeaponSandboxCatalogScript.get_weapon("hammer")
	controller.equip_weapon(hammer)
	var attack: WeaponAttackDefinition = hammer.get_moveset().get_entry_attack("light")
	_expect(controller.start_attack(attack), "SafeWeaponController starts hammer attack")
	await get_tree().process_frame
	_expect(controller.current_attack != null, "hammer attack remains active after start")
	if controller.current_attack != null:
		_expect(
			WeaponClassMotionCatalogScript.has_profile(controller.current_attack.character_pose_id),
			"SafeWeaponController applies hammer class pose before attack execution"
		)
		_expect(
			CombatFootworkCatalogScript.has_profile(controller.current_attack.footwork_profile_id),
			"SafeWeaponController applies valid fallback footwork before combat motion"
		)
	controller.cancel_current_attack("smoke_test")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("WEAPON_ARSENAL_DOJO_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WEAPON_ARSENAL_DOJO_SMOKE_TEST: " + failure)
	get_tree().quit(1)
