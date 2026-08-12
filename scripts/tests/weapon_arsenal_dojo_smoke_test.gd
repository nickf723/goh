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
const WeaponClassCombatIdentityScript = preload(
	"res://scripts/weapons/weapon_class_combat_identity.gd"
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
	_validate_combat_identity_contract()
	dojo = DojoScene.instantiate()
	add_child(dojo)
	for _index: int in range(8):
		await get_tree().process_frame
	await get_tree().physics_frame
	_validate_dojo_runtime()
	await _validate_player_integration()
	await _validate_true_range_and_geometry_runtime()
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


func _validate_combat_identity_contract() -> void:
	var bow: WeaponDefinition = WeaponSandboxCatalogScript.get_weapon("bow")
	var shuriken: WeaponDefinition = WeaponSandboxCatalogScript.get_weapon("shuriken")
	var boomerang: WeaponDefinition = WeaponSandboxCatalogScript.get_weapon("boomerang")
	var lance: WeaponDefinition = WeaponSandboxCatalogScript.get_weapon("lance")
	var mace: WeaponDefinition = WeaponSandboxCatalogScript.get_weapon("mace")
	var halberd: WeaponDefinition = WeaponSandboxCatalogScript.get_weapon("halberd")
	_expect(bow != null and shuriken != null and boomerang != null and lance != null, "ranged/line identity weapons resolve")
	_expect(mace != null and halberd != null, "impact identity weapons resolve")
	if bow != null:
		var attack: WeaponAttackDefinition = bow.get_moveset().get_entry_attack("light")
		_expect(
			WeaponClassCombatIdentityScript.get_geometry_mode("bow", attack)
			== WeaponClassCombatIdentityScript.GEOMETRY_PRECISION_RAY,
			"bow uses a precision ray instead of a melee sphere"
		)
	if shuriken != null:
		var attack: WeaponAttackDefinition = shuriken.get_moveset().get_entry_attack("light")
		_expect(
			WeaponClassCombatIdentityScript.get_geometry_mode("shuriken", attack)
			== WeaponClassCombatIdentityScript.GEOMETRY_FAN_RAYS,
			"shuriken uses a multi-ray fan"
		)
		_expect(WeaponClassCombatIdentityScript.get_fan_angles(attack).size() == 3, "light shuriken throws a three-ray fan")
	if boomerang != null:
		var attack: WeaponAttackDefinition = boomerang.get_moveset().get_entry_attack("light")
		_expect(
			WeaponClassCombatIdentityScript.get_geometry_mode("boomerang", attack)
			== WeaponClassCombatIdentityScript.GEOMETRY_RETURNING_RAY,
			"boomerang owns a returning ranged path"
		)
	if lance != null:
		var attack: WeaponAttackDefinition = lance.get_moveset().get_entry_attack("light")
		_expect(
			WeaponClassCombatIdentityScript.get_geometry_mode("lance", attack)
			== WeaponClassCombatIdentityScript.GEOMETRY_LINE,
			"lance thrust uses a narrow line geometry"
		)
	if mace != null:
		var attack: WeaponAttackDefinition = mace.get_moveset().get_entry_attack("heavy")
		var payload: DamagePayload = attack.build_payload(mace)
		WeaponClassCombatIdentityScript.apply_payload_identity(
			payload, "mace", attack, 1, null, Vector3(0.0, 0.0, 2.0)
		)
		_expect(payload.status_effect == "staggered", "mace heavy authors a dazing stagger")
		_expect(payload.knockback_strength >= 2.6, "mace heavy has real impact force")
	if halberd != null:
		var attack: WeaponAttackDefinition = halberd.get_moveset().get_entry_attack("heavy")
		var payload: DamagePayload = attack.build_payload(halberd)
		var target_offset := Vector3(0.0, 0.0, 3.0)
		WeaponClassCombatIdentityScript.apply_payload_identity(
			payload, "halberd", attack, 1, null, target_offset
		)
		_expect(
			payload.knockback_direction.dot(target_offset.normalized()) < -0.8,
			"halberd heavy pulls inward instead of pushing away"
		)


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


func _validate_true_range_and_geometry_runtime() -> void:
	if dojo == null:
		return
	var player: CharacterBody3D = dojo.get_node_or_null("Player") as CharacterBody3D
	var controller: SafeWeaponController = (
		dojo.get_node_or_null("Player/WeaponController") as SafeWeaponController
	)
	var center_target: Node3D = dojo.get_node_or_null("TrainingTargets/CenterTarget") as Node3D
	if player == null or controller == null or center_target == null:
		failures.append("range regression resolves player/controller/center target")
		return

	var hammer: WeaponDefinition = WeaponSandboxCatalogScript.get_weapon("hammer")
	controller.equip_weapon(hammer)
	var hammer_attack: WeaponAttackDefinition = hammer.get_moveset().get_entry_attack("light")
	player.global_position = Vector3(0.0, 1.0, -11.0)
	player.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	await get_tree().physics_frame
	var far_targets: Array[Node] = controller.find_targets(hammer_attack)
	_expect(
		far_targets.is_empty(),
		"true range blocks Hammer from hitting dojo targets across the room"
	)

	player.global_position = Vector3(0.0, 1.0, 0.7)
	player.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	await get_tree().physics_frame
	var near_targets: Array[Node] = controller.find_targets(hammer_attack)
	_expect(
		near_targets.has(center_target),
		"Hammer finds the center target once Grace is actually within reach"
	)

	var bow: WeaponDefinition = WeaponSandboxCatalogScript.get_weapon("bow")
	controller.equip_weapon(bow)
	var bow_attack: WeaponAttackDefinition = bow.get_moveset().get_entry_attack("light")
	player.global_position = Vector3(0.0, 1.0, 0.7)
	player.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	await get_tree().physics_frame
	var bow_targets: Array[Node] = controller.find_targets(bow_attack)
	_expect(bow_targets.size() <= 1, "Bow precision shot can only resolve the first ray contact")
	if not bow_targets.is_empty():
		_expect(bow_targets[0] == center_target, "Bow ray respects the nearer target instead of damaging through it")


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