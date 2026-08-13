extends Node

const DojoScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_weapon_arsenal_dojo_v1.tscn"
)

var failures: Array[String] = []
var dojo: Node


func _ready() -> void:
	GameState.reset_run()
	dojo = DojoScene.instantiate()
	add_child(dojo)
	for _index: int in range(8):
		await get_tree().process_frame
	for _index: int in range(2):
		await get_tree().physics_frame
	await _validate_continuity_player()
	_validate_grounded_target_response()
	_validate_dojo_readability_settings()
	if dojo != null and is_instance_valid(dojo):
		dojo.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_continuity_player() -> void:
	var player: CharacterBody3D = dojo.get_node_or_null("Player") as CharacterBody3D
	var controller: CombatWeaponControllerV2 = dojo.get_node_or_null(
		"Player/WeaponController"
	) as CombatWeaponControllerV2
	var visual: GraceWireMotionVisualCombatV2 = dojo.get_node_or_null(
		"Player/GraceVisualV1"
	) as GraceWireMotionVisualCombatV2
	_expect(player != null, "combat feel dojo resolves player")
	_expect(controller != null, "combat feel dojo keeps CombatWeaponControllerV2")
	_expect(visual != null, "combat feel dojo uses continuous Grace visual")
	if player == null or controller == null or visual == null:
		return

	var sword_pedestal: SandboxWeaponPedestal = dojo.get_node_or_null(
		"SwordPedestal"
	) as SandboxWeaponPedestal
	_expect(
		sword_pedestal != null and sword_pedestal.weapon != null,
		"Sword pedestal supplies calibration weapon"
	)
	if sword_pedestal == null or sword_pedestal.weapon == null:
		return
	controller.equip_weapon(sword_pedestal.weapon)
	var attack: WeaponAttackDefinition = (
		sword_pedestal.weapon.get_moveset().get_entry_attack("light")
	)
	_expect(attack != null, "Sword Light entry resolves")
	if attack == null:
		return

	player.velocity = Vector3(2.8, 0.0, -3.2)
	_expect(controller.start_attack(attack), "Sword Light starts under continuity visual")
	await get_tree().process_frame
	visual.sample_animation_pose(1.0 / 60.0)
	var active_debug: Dictionary = visual.get_animation_debug_data()
	_expect(bool(active_debug.get("combat_continuity", false)), "Grace reports combat continuity layer")
	_expect(str(active_debug.get("continuity_attack", "none")) != "none", "continuity layer tracks active attack")

	var speed: float = controller.get_attack_speed()
	controller.current_attack_elapsed = (
		attack.get_startup_duration(speed)
		+ attack.get_active_duration(speed)
		+ attack.get_recovery_duration(speed) * 0.55
	)
	visual.sample_animation_pose(1.0 / 60.0)
	var recovery_debug: Dictionary = visual.get_animation_debug_data()
	_expect(
		str(recovery_debug.get("continuity_attack", "none")) != "none",
		"continuity layer remains authoritative through recovery"
	)

	controller.finish_current_attack()
	visual.sample_animation_pose(1.0 / 60.0)
	var settle_debug: Dictionary = visual.get_animation_debug_data()
	_expect(
		float(settle_debug.get("continuity_settle_remaining", 0.0)) > 0.0,
		"finished attack leaves a residual settle instead of snapping to neutral"
	)


func _validate_grounded_target_response() -> void:
	var target: CombatTrainingTarget = dojo.get_node_or_null(
		"TrainingTargets/CenterTarget"
	) as CombatTrainingTarget
	_expect(target != null, "combat feel dojo resolves center training target")
	if target == null:
		return
	var sword_pedestal: SandboxWeaponPedestal = dojo.get_node_or_null(
		"SwordPedestal"
	) as SandboxWeaponPedestal
	if sword_pedestal == null or sword_pedestal.weapon == null:
		return
	var attack: WeaponAttackDefinition = (
		sword_pedestal.weapon.get_moveset().get_entry_attack("light")
	)
	if attack == null:
		return
	var payload: DamagePayload = attack.build_payload(sword_pedestal.weapon)
	target.receive_weapon_impact(payload, Vector3.FORWARD, attack)
	var debug_data: Dictionary = target.get_debug_data()
	_expect(
		str(debug_data.get("grounded_impact_kind", "none")) == "light",
		"training target distinguishes grounded Light impact"
	)
	var recoil: Vector3 = debug_data.get(
		"grounded_recoil_rotation",
		Vector3.ZERO
	) as Vector3
	_expect(recoil.length() > 0.01, "grounded hit produces local visual recoil")
	_expect(
		target.grounded_knockback_scale < 1.0,
		"grounded target damps systemic planar displacement"
	)


func _validate_dojo_readability_settings() -> void:
	var controller: WeaponController = dojo.get_node_or_null(
		"Player/WeaponController"
	) as WeaponController
	_expect(controller != null, "readability check resolves weapon controller")
	if controller == null:
		return
	_expect(controller.sweep_start_alpha <= 0.35, "dojo slash trail alpha is reduced for motion readability")
	var debug_data: Dictionary = dojo.call("get_debug_data")
	_expect(bool(debug_data.get("combat_feel_pass_01", false)), "dojo reports combat feel calibration pass")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("GRACE_COMBAT_FEEL_PASS_01_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GRACE_COMBAT_FEEL_PASS_01_SMOKE_TEST: " + failure)
	get_tree().quit(1)
