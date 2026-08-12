extends Node

const DojoScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_weapon_arsenal_dojo_v1.tscn"
)
const WhipRigScene: PackedScene = preload(
	"res://scenes/weapons/whip_weapon_rig.tscn"
)
const ChainRigScene: PackedScene = preload(
	"res://scenes/weapons/chain_weapon_rig.tscn"
)
const FlailRigScene: PackedScene = preload(
	"res://scenes/weapons/flail_weapon_rig.tscn"
)
const FlexibleContactSampler = preload(
	"res://scripts/weapons/flexible_weapon_contact_sampler.gd"
)

var failures: Array[String] = []
var dojo: Node


func _ready() -> void:
	GameState.reset_run()
	_validate_rig_scenes()
	dojo = DojoScene.instantiate()
	add_child(dojo)
	for _index: int in range(8):
		await get_tree().process_frame
	for _index: int in range(3):
		await get_tree().physics_frame
	await _validate_dojo_controller()
	await _validate_flexible_runtime_rigs()
	if dojo != null and is_instance_valid(dojo):
		dojo.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_rig_scenes() -> void:
	var whip: WhipWeaponRigV2 = WhipRigScene.instantiate() as WhipWeaponRigV2
	var chain: ChainWeaponRigV2 = ChainRigScene.instantiate() as ChainWeaponRigV2
	var flail: FlailWeaponRig3D = FlailRigScene.instantiate() as FlailWeaponRig3D
	_expect(whip != null, "whip scene uses WhipWeaponRigV2")
	_expect(chain != null, "chain scene uses ChainWeaponRigV2")
	_expect(flail != null, "flail scene uses FlailWeaponRig3D")
	if whip != null:
		add_child(whip)
	if chain != null:
		add_child(chain)
	if flail != null:
		add_child(flail)
	for _index: int in range(3):
		await get_tree().physics_frame
	if whip != null:
		_expect(whip.tether != null, "whip owns a simulated tether")
		if whip.tether != null:
			var samples: Array[Dictionary] = FlexibleContactSampler.sample_tether(
				whip.tether,
				1.0 / 60.0,
				0.18,
				true
			)
			_expect(samples.size() > whip.tether.segment_count, "whip contact sampler covers line segments and midpoints")
			_expect(whip.tether.verlet_damping <= 0.92, "whip tether uses stabilized damping")
	if chain != null:
		_expect(chain.tether != null, "chain owns a simulated tether")
		if chain.tether != null:
			var samples: Array[Dictionary] = FlexibleContactSampler.sample_tether(
				chain.tether,
				1.0 / 60.0,
				0.04,
				true
			)
			_expect(samples.size() > chain.tether.segment_count, "chain contact sampler covers the full line")
			_expect(chain.tether.verlet_damping <= 0.93, "chain tether uses stabilized damping")
	if flail != null:
		_expect(flail.tether != null, "flail owns a simulated tether")
		_expect(flail.chain_length < 2.2, "flail uses a short chain")
		_expect(flail.tip_mass >= 2.5, "flail uses a head-heavy mass")
		if flail.tether != null:
			_expect(flail.tether.segment_count == 9, "flail uses dedicated short-chain segmentation")
	for rig: Node in [whip, chain, flail]:
		if rig != null and is_instance_valid(rig):
			rig.queue_free()


func _validate_dojo_controller() -> void:
	_expect(dojo != null, "combat v2 dojo instantiates")
	if dojo == null:
		return
	var controller: CombatWeaponControllerV2 = (
		dojo.get_node_or_null("Player/WeaponController") as CombatWeaponControllerV2
	)
	_expect(controller != null, "dojo player uses CombatWeaponControllerV2")
	if controller == null:
		return
	var floor_node: Node = dojo.get_node_or_null("Floor")
	_expect(floor_node != null, "dojo floor resolves for ancestry regression")
	if floor_node != null:
		_expect(
			controller.find_payload_target(floor_node) == null,
			"floor collider cannot resolve to an unrelated sibling combat target"
		)
	var bow_pedestal: SandboxWeaponPedestal = dojo.get_node_or_null(
		"BowPedestal"
	) as SandboxWeaponPedestal
	_expect(bow_pedestal != null and bow_pedestal.weapon != null, "bow pedestal supplies ranged proxy")
	if bow_pedestal == null or bow_pedestal.weapon == null:
		return
	controller.equip_weapon(bow_pedestal.weapon)
	var bow_attack: WeaponAttackDefinition = bow_pedestal.weapon.get_moveset().get_entry_attack("light")
	var baseline: Vector3 = controller.resolve_attack_forward(bow_attack)
	Input.action_press("move_right", 1.0)
	var strafing: Vector3 = controller.resolve_attack_forward(bow_attack)
	Input.action_release("move_right")
	_expect(baseline.length() > 0.9 and strafing.length() > 0.9, "ranged aim produces normalized headings")
	_expect(
		baseline.dot(strafing) > 0.995,
		"strafing input does not steer ranged aim away from the combat aim"
	)
	var debug_data: Dictionary = controller.get_combat_v2_debug_data()
	_expect(bool(debug_data.get("safe_ancestry_target_resolution", false)), "combat v2 reports safe collider ancestry")
	_expect(bool(debug_data.get("per_contact_payload_hook", false)), "combat v2 exposes per-contact payload hook")


func _validate_flexible_runtime_rigs() -> void:
	if dojo == null:
		return
	var controller: CombatWeaponControllerV2 = (
		dojo.get_node_or_null("Player/WeaponController") as CombatWeaponControllerV2
	)
	if controller == null:
		return
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
		_expect(rig != null, weapon_class + " equips a runtime flexible rig")
		if rig == null:
			continue
		if weapon_class == "whip":
			_expect(rig is WhipWeaponRigV2, "whip equips line-contact v2 rig")
		elif weapon_class == "chains":
			_expect(rig is ChainWeaponRigV2, "chains equip full-line v2 rig")
		else:
			_expect(rig is FlailWeaponRig3D, "flail equips physical weighted-head rig")
		var attack: WeaponAttackDefinition = pedestal.weapon.get_moveset().get_entry_attack("light")
		_expect(controller.start_attack(attack), weapon_class + " starts a flexible weapon attack")
		for _index: int in range(3):
			await get_tree().physics_frame
		var rig_debug: Dictionary = rig.call("get_debug_data") if rig.has_method("get_debug_data") else {}
		if weapon_class == "flail":
			_expect(bool(rig_debug.get("physics_flail", false)), "flail debug contract reports real physics")
		else:
			_expect(bool(rig_debug.get("body_contact_enabled", false)), weapon_class + " reports body contact authority")
		controller.cancel_current_attack("flexible_v2_smoke")


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
