extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const RuviaAvatar: PlayableAvatarDefinition = preload(
	"res://data/avatars/ruvia_incarnation_prototype.tres"
)
const RuviaWeapon: WeaponDefinition = preload(
	"res://data/weapons/ruvia_ember_halberd_prototype.tres"
)
const WeaponPoseCatalogRouterScript = preload(
	"res://scripts/weapons/weapon_pose_catalog_router.gd"
)
const RuviaHalberdPoseCatalogScript = preload(
	"res://scripts/weapons/ruvia_halberd_pose_catalog.gd"
)
const CombatFootworkCatalogScript = preload(
	"res://scripts/weapons/combat_footwork_catalog.gd"
)

const EXPECTED_ATTACK_IDS: Array[String] = [
	"ruvia_halberd_l1",
	"ruvia_halberd_l2",
	"ruvia_halberd_l3",
	"ruvia_halberd_l4",
	"ruvia_halberd_l5",
	"ruvia_halberd_h0",
	"ruvia_halberd_h1",
	"ruvia_halberd_h2",
	"ruvia_halberd_h3",
	"ruvia_halberd_h4",
]

var failures: Array[String] = []
var original_health: int = 0
var original_max_health: int = 0
var original_stamina: int = 0
var original_max_stamina: int = 0


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_health = GameState.get_stat("health")
	original_max_health = GameState.get_stat("max_health")
	original_stamina = GameState.get_stat("stamina")
	original_max_stamina = GameState.get_stat("max_stamina")
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_stamina", 100)
	GameState.set_stat("stamina", 100)

	_validate_catalogs()
	_validate_attack_graph()
	_validate_pose_samples()

	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "RuviaHalberdTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	await _validate_live_player(player)
	_restore_state()
	player.queue_free()
	floor.queue_free()
	_finish()


func _validate_catalogs() -> void:
	for failure: String in WeaponPoseCatalogRouterScript.validate_profiles():
		_expect(false, failure)
	var moveset: WeaponMovesetDefinition = RuviaWeapon.get_moveset()
	_expect(moveset != null, "Ruvia weapon owns a dedicated moveset")
	if moveset == null:
		return
	for graph_error: String in moveset.validate_graph():
		_expect(false, graph_error)
	_expect(
		moveset.moveset_id == "ruvia_ember_halberd",
		"Dedicated Ember Halberd moveset replaces borrowed spear forms"
	)
	_expect(
		moveset.display_name == "Ruvia's Ember Halberd Forms",
		"Moveset exposes Ruvia's authored combat identity"
	)


func _validate_attack_graph() -> void:
	var moveset: WeaponMovesetDefinition = RuviaWeapon.get_moveset()
	if moveset == null:
		return
	var attack_ids: Array[String] = moveset.get_attack_ids()
	_expect(attack_ids.size() == 10, "Halberd graph contains ten authored attacks")
	for expected_id: String in EXPECTED_ATTACK_IDS:
		_expect(attack_ids.has(expected_id), "Halberd graph contains " + expected_id)
	_expect(
		moveset.entry_light_attack_id == "ruvia_halberd_l1",
		"Cinder Sweep is the Light entry"
	)
	_expect(
		moveset.entry_heavy_attack_id == "ruvia_halberd_h0",
		"Furnace Drop is the neutral Heavy entry"
	)
	var expected_names: Dictionary = {
		"ruvia_halberd_l1": "Cinder Sweep",
		"ruvia_halberd_l2": "Backdraft Return",
		"ruvia_halberd_l3": "Haft Check",
		"ruvia_halberd_l4": "Rising Brand",
		"ruvia_halberd_l5": "Ember Wheel",
		"ruvia_halberd_h0": "Furnace Drop",
		"ruvia_halberd_h1": "Scorching Thrust",
		"ruvia_halberd_h2": "Reaping Hook",
		"ruvia_halberd_h3": "Wildfire Cleave",
		"ruvia_halberd_h4": "Solar Descent",
	}
	for attack_index: int in range(moveset.attacks.size()):
		var attack: WeaponAttackDefinition = moveset.attacks[attack_index]
		if attack == null:
			_expect(false, "Halberd graph contains no null attacks")
			continue
		_expect(
			str(expected_names.get(attack.attack_id, "")) == attack.display_name,
			attack.attack_id + " keeps its authored display name"
		)
		_expect(
			RuviaHalberdPoseCatalogScript.has_profile(attack.character_pose_id),
			attack.display_name + " owns a bespoke two-handed pose"
		)
		_expect(
			CombatFootworkCatalogScript.has_profile(attack.footwork_profile_id),
			attack.display_name + " resolves planted lower-body footwork"
		)


func _validate_pose_samples() -> void:
	var moveset: WeaponMovesetDefinition = RuviaWeapon.get_moveset()
	if moveset == null:
		return
	var attack_speed: float = RuviaWeapon.attack_speed
	for attack_index: int in range(moveset.attacks.size()):
		var attack: WeaponAttackDefinition = moveset.attacks[attack_index]
		if attack == null:
			continue
		var startup: float = attack.get_startup_duration(attack_speed)
		var active: float = attack.get_active_duration(attack_speed)
		var recovery: float = attack.get_recovery_duration(attack_speed)
		var sample_times: Array[float] = [
			startup * 0.75,
			startup + active * 0.65,
			startup + active + recovery * 0.45,
		]
		for sample_time: float in sample_times:
			var sample: Dictionary = WeaponPoseCatalogRouterScript.sample_attack(
				attack,
				sample_time,
				attack_speed
			)
			_expect(not sample.is_empty(), attack.display_name + " produces a pose sample")
			_expect(bool(sample.get("two_handed", false)), attack.display_name + " is two-handed")
			_expect(
				_vector_is_finite(sample.get("body", Vector3.ZERO)),
				attack.display_name + " body pose remains finite"
			)
			_expect(
				_vector_is_finite(sample.get("left_arm", Vector3.ZERO)),
				attack.display_name + " guide arm remains finite"
			)
			_expect(
				_vector_is_finite(sample.get("right_arm", Vector3.ZERO)),
				attack.display_name + " drive arm remains finite"
			)
			_expect(
				_vector_is_finite(sample.get("support_grip_position", Vector3.ZERO)),
				attack.display_name + " support grip remains on a finite shaft point"
			)

	var thrust: WeaponAttackDefinition = moveset.get_attack("ruvia_halberd_h1")
	if thrust != null:
		var thrust_startup: float = thrust.get_startup_duration(attack_speed)
		var thrust_active: float = thrust.get_active_duration(attack_speed)
		var windup_sample: Dictionary = WeaponPoseCatalogRouterScript.sample_attack(
			thrust,
			thrust_startup * 0.92,
			attack_speed
		)
		var strike_sample: Dictionary = WeaponPoseCatalogRouterScript.sample_attack(
			thrust,
			thrust_startup + thrust_active * 0.82,
			attack_speed
		)
		var windup_grip: Vector3 = windup_sample.get(
			"support_grip_position",
			Vector3.ZERO
		)
		var strike_grip: Vector3 = strike_sample.get(
			"support_grip_position",
			Vector3.ZERO
		)
		_expect(
			windup_grip.distance_to(strike_grip) > 0.32,
			"Scorching Thrust visibly slides the guide hand along the shaft"
		)


func _validate_live_player(player: CharacterBody3D) -> void:
	var manager: PlayerAvatarManager = (
		player.get_node_or_null("AvatarManager") as PlayerAvatarManager
	)
	var weapon: WeaponController = (
		player.get_node_or_null("WeaponController") as WeaponController
	)
	var animator: PlayerWeaponControlAnimator = (
		player.get_node_or_null("PlayerWeaponControlAnimator") as PlayerWeaponControlAnimator
	)
	var visual: GraceIncarnationMotionVisual = (
		player.get_node_or_null("GraceVisualV1") as GraceIncarnationMotionVisual
	)
	var wire: AvatarWireSkeletonRenderer = (
		player.get_node_or_null(
			"GraceVisualV1/WireSkeletonRenderer"
		) as AvatarWireSkeletonRenderer
	)
	_expect(manager != null, "Shared player exposes AvatarManager")
	_expect(weapon != null, "Shared player exposes WeaponController")
	_expect(animator != null, "Shared player exposes weapon control animator")
	_expect(visual != null, "Shared player exposes incarnation motion visual")
	_expect(wire != null, "Shared player exposes avatar wire renderer")
	if manager == null or weapon == null or animator == null or visual == null or wire == null:
		return

	_expect(manager.incarnate(RuviaAvatar, true), "Debug incarnation activates Ruvia")
	_expect(weapon.equipped_weapon == RuviaWeapon, "Ruvia equips the Ember Halberd")
	_expect(
		weapon.runtime_weapon_rig is RuviaEmberHalberdRig,
		"Ember Halberd installs its attack-aware runtime rig"
	)
	if not weapon.runtime_weapon_rig is RuviaEmberHalberdRig:
		return
	var rig: RuviaEmberHalberdRig = (
		weapon.runtime_weapon_rig as RuviaEmberHalberdRig
	)
	var rig_ready: Dictionary = rig.get_debug_data()
	_expect(bool(rig_ready.get("configured", false)), "Halberd rig receives weapon ownership")
	_expect(bool(rig_ready.get("two_handed", false)), "Halberd rig declares two-handed control")
	_expect(
		int(rig_ready.get("blade_material_count", 0)) >= 1,
		"Halberd rig owns ember blade materials"
	)

	_validate_payload_identity(rig)

	player.set_physics_process(false)
	manager.set_process(false)
	weapon.set_process(false)
	animator.set_process(false)
	visual.set_process(false)
	wire.set_process(false)

	var moveset: WeaponMovesetDefinition = RuviaWeapon.get_moveset()
	if moveset == null:
		return
	for attack_index: int in range(moveset.attacks.size()):
		var attack: WeaponAttackDefinition = moveset.attacks[attack_index]
		if attack == null:
			continue
		GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
		_expect(weapon.start_attack(attack), attack.display_name + " starts on the live player")
		if weapon.current_attack != attack:
			continue
		weapon.current_attack_elapsed = (
			attack.get_startup_duration(weapon.get_attack_speed())
			+ attack.get_active_duration(weapon.get_attack_speed()) * 0.7
		)
		visual.sample_animation_pose(1.0 / 60.0)
		animator.sample_now()
		var control: Dictionary = animator.get_debug_data()
		_expect(bool(control.get("two_handed", false)), attack.display_name + " routes two-handed control")
		_expect(bool(control.get("support_hand_locked", false)), attack.display_name + " locks the guide hand")
		_expect(
			float(control.get("support_hand_error", 99.0)) < 0.025,
			attack.display_name + " guide hand reaches the shaft"
		)
		_expect(wire.has_finite_pose(), attack.display_name + " keeps the wire skeleton finite")
		_expect(
			wire.get_joint_world_position("left_hand").distance_to(
				wire.get_joint_world_position("right_hand")
			) > 0.18,
			attack.display_name + " maintains readable hand spacing"
		)
		weapon.cancel_current_attack("halberd_smoke_test")

	var final_rig_debug: Dictionary = rig.get_debug_data()
	_expect(
		str(final_rig_debug.get("rig_id", "")) == "ruvia_ember_halberd",
		"Runtime diagnostics identify the Ember Halberd"
	)
	manager.dismiss_avatar("halberd_smoke_test")


func _validate_payload_identity(rig: RuviaEmberHalberdRig) -> void:
	var moveset: WeaponMovesetDefinition = RuviaWeapon.get_moveset()
	if moveset == null:
		return
	var blade_attack: WeaponAttackDefinition = moveset.get_attack("ruvia_halberd_l1")
	var haft_attack: WeaponAttackDefinition = moveset.get_attack("ruvia_halberd_l3")
	var solar_attack: WeaponAttackDefinition = moveset.get_attack("ruvia_halberd_h4")
	if blade_attack != null:
		var blade_payload: DamagePayload = blade_attack.build_payload(RuviaWeapon)
		rig.modify_attack_payload(blade_payload, blade_attack)
		_expect(blade_payload.element == "fire", "Blade forms remain Fire attacks")
		_expect(blade_payload.status_effect == "burning", "Blade forms apply Burning")
		_expect(blade_payload.tags.has("two_handed"), "Blade payload records two-handed control")
	if haft_attack != null:
		var haft_payload: DamagePayload = haft_attack.build_payload(RuviaWeapon)
		rig.modify_attack_payload(haft_payload, haft_attack)
		_expect(haft_payload.element == "neutral", "Haft Check remains physical")
		_expect(haft_payload.status_effect == "", "Haft Check does not apply Burning")
		_expect(not haft_payload.tags.has("fire"), "Haft Check removes inherited Fire tags")
	if solar_attack != null:
		var solar_payload: DamagePayload = solar_attack.build_payload(RuviaWeapon)
		rig.modify_attack_payload(solar_payload, solar_attack)
		_expect(solar_payload.element == "fire", "Solar Descent remains Fire")
		_expect(solar_payload.status_duration >= 2.8, "Solar Descent strengthens Burning duration")
		_expect(solar_payload.status_strength >= 1.4, "Solar Descent strengthens Burning intensity")
		_expect(solar_payload.tags.has("divine_finisher"), "Solar Descent records divine finisher identity")


func _make_floor() -> StaticBody3D:
	var floor: StaticBody3D = StaticBody3D.new()
	floor.name = "RuviaHalberdFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(18.0, 0.2, 18.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _vector_is_finite(value: Variant) -> bool:
	return value is Vector3 and (value as Vector3).is_finite()


func _restore_state() -> void:
	GameState.set_stat("max_health", original_max_health)
	GameState.set_stat("health", original_health)
	GameState.set_stat("max_stamina", original_max_stamina)
	GameState.set_stat("stamina", original_stamina)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("RUVIA_HALBERD_COMBAT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	push_error(
		"RUVIA_HALBERD_COMBAT_SMOKE_TEST: FAILED: "
		+ ", ".join(failures)
	)
	get_tree().quit(1)
