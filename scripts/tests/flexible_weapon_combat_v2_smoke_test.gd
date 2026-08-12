extends Node

const DojoScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_weapon_arsenal_dojo_v1.tscn"
)
const WhipRigScene: PackedScene = preload("res://scenes/weapons/whip_weapon_rig.tscn")
const ChainRigScene: PackedScene = preload("res://scenes/weapons/chain_weapon_rig.tscn")
const FlailRigScene: PackedScene = preload("res://scenes/weapons/flail_weapon_rig.tscn")

var failures: Array[String] = []
var dojo: Node


func _ready() -> void:
	GameState.reset_run()
	await _validate_rig_scenes()
	dojo = DojoScene.instantiate()
	add_child(dojo)
	for _index: int in range(8):
		await get_tree().process_frame
	for _index: int in range(3):
		await get_tree().physics_frame
	_validate_dojo_controller()
	await _validate_flexible_contacts()
	if dojo != null and is_instance_valid(dojo):
		dojo.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_rig_scenes() -> void:
	var whip: WhipWeaponRigV3 = WhipRigScene.instantiate() as WhipWeaponRigV3
	var chain: ChainWeaponRigV3 = ChainRigScene.instantiate() as ChainWeaponRigV3
	var flail: FlailWeaponRigV2 = FlailRigScene.instantiate() as FlailWeaponRigV2
	_expect(whip != null, "whip scene uses controlled WhipWeaponRigV3")
	_expect(chain != null, "chain scene uses controlled ChainWeaponRigV3")
	_expect(flail != null, "flail scene uses simplified FlailWeaponRigV2")
	for rig: Node in [whip, chain, flail]:
		if rig != null:
			add_child(rig)
	for _index: int in range(2):
		await get_tree().process_frame
	if whip != null:
		_expect(whip.line != null, "whip owns deterministic rendered line")
		_expect(whip.line.get_contact_samples(true).size() > whip.segment_count, "whip contact samples cover rendered body")
		_expect(bool(whip.get_debug_data().get("controlled_line", false)), "whip reports controlled-line authority")
	if chain != null:
		_expect(chain.line != null, "chain owns deterministic rendered line")
		_expect(chain.line.get_contact_samples(true).size() > chain.segment_count, "chain contact samples cover rendered body")
		_expect(bool(chain.get_debug_data().get("controlled_line", false)), "chain reports controlled-line authority")
	if flail != null:
		_expect(flail.line != null, "flail owns deterministic short chain")
		_expect(flail.segment_count == 7, "flail uses a small fixed segment count")
		_expect(bool(flail.get_debug_data().get("simplified_physics", false)), "flail reports simplified physics")
		_expect(bool(flail.get_debug_data().get("head_lag_only", false)), "flail keeps physics flavor only in weighted head lag")
	for rig: Node in [whip, chain, flail]:
		if rig != null and is_instance_valid(rig):
			rig.queue_free()


func _validate_dojo_controller() -> void:
	_expect(dojo != null, "simplified-flex dojo instantiates")
	if dojo == null:
		return
	var controller: CombatWeaponControllerV2 = dojo.get_node_or_null(
		"Player/WeaponController"
	) as CombatWeaponControllerV2
	_expect(controller != null, "dojo keeps CombatWeaponControllerV2 ranged fixes")
	if controller == null:
		return
	var floor_node: Node = dojo.get_node_or_null("Floor")
	_expect(floor_node != null, "dojo floor resolves")
	if floor_node != null:
		_expect(controller.find_payload_target(floor_node) == null, "floor cannot nominate sibling target")
	var bow_pedestal: SandboxWeaponPedestal = dojo.get_node_or_null("BowPedestal") as SandboxWeaponPedestal
	_expect(bow_pedestal != null and bow_pedestal.weapon != null, "bow remains available")
	if bow_pedestal != null and bow_pedestal.weapon != null:
		controller.equip_weapon(bow_pedestal.weapon)
		var bow_attack: WeaponAttackDefinition = bow_pedestal.weapon.get_moveset().get_entry_attack("light")
		var baseline: Vector3 = controller.resolve_attack_forward(bow_attack)
		Input.action_press("move_right", 1.0)
		var strafing: Vector3 = controller.resolve_attack_forward(bow_attack)
		Input.action_release("move_right")
		_expect(baseline.dot(strafing) > 0.995, "strafing still does not steer projectile aim")


func _validate_flexible_contacts() -> void:
	if dojo == null:
		return
	var player: CharacterBody3D = dojo.get_node_or_null("Player") as CharacterBody3D
	var controller: CombatWeaponControllerV2 = dojo.get_node_or_null(
		"Player/WeaponController"
	) as CombatWeaponControllerV2
	var center_target: Node = dojo.get_node_or_null("TrainingTargets/CenterTarget")
	if player == null or controller == null or center_target == null:
		failures.append("flex contact test resolves player/controller/target")
		return
	player.global_position = Vector3(0.0, 1.0, 0.7)
	player.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	await get_tree().physics_frame

	for weapon_class: String in ["whip", "chains", "flail"]:
		var pedestal: SandboxWeaponPedestal = dojo.get_node_or_null(
			weapon_class.capitalize() + "Pedestal"
		) as SandboxWeaponPedestal
		_expect(pedestal != null and pedestal.weapon != null, weapon_class + " pedestal supplies weapon")
		if pedestal == null or pedestal.weapon == null:
			continue
		controller.equip_weapon(pedestal.weapon)
		await get_tree().process_frame
		var rig: Node3D = controller.runtime_weapon_rig
		_expect(rig != null, weapon_class + " equips controlled runtime rig")
		if rig == null:
			continue
		var attack: WeaponAttackDefinition = pedestal.weapon.get_moveset().get_entry_attack("light")
		_expect(controller.start_attack(attack), weapon_class + " starts light attack")
		var active_attack: WeaponAttackDefinition = controller.current_attack
		if active_attack == null:
			continue
		var startup: float = active_attack.get_startup_duration(controller.get_attack_speed())
		if rig.has_method("update_attack_pose"):
			rig.call("update_attack_pose", active_attack, startup + 0.001, controller.get_attack_speed())
		var targets: Array[Node] = controller.find_targets(active_attack)
		_expect(targets.has(center_target), weapon_class + " visible active line can contact nearby center target")
		var debug_data: Dictionary = rig.call("get_debug_data") if rig.has_method("get_debug_data") else {}
		if weapon_class == "flail":
			_expect(bool(debug_data.get("simplified_physics", false)), "flail uses simplified head-lag physics")
		else:
			_expect(bool(debug_data.get("full_line_contact", false)), weapon_class + " rendered line owns hit contact")
		controller.cancel_current_attack("simplified_flex_smoke")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("FLEXIBLE_WEAPON_COMBAT_V2_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FLEXIBLE_WEAPON_COMBAT_V2_SMOKE_TEST: " + failure)
	get_tree().quit(1)
