extends Node


const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_time_scale: float = 1.0


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_time_scale = Engine.time_scale
	_prepare_stats()

	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "DivineSpecialInputTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var controller: PlayerDivineSpecialController = player.get_node_or_null(
		"DivineSpecialController"
	) as PlayerDivineSpecialController
	var weapon: SafeWeaponController = player.get_node_or_null(
		"WeaponController"
	) as SafeWeaponController
	var action_state: PlayerActionState = player.get_node_or_null(
		"PlayerActionState"
	) as PlayerActionState
	var router: Node = player.get_node_or_null("DivineSpecialInputRouter")
	var radial_menu: Node = player.get_node_or_null("DivineSpecialRadialMenu")

	_expect(controller != null, "Player retains the Divine Special controller")
	_expect(weapon != null, "Player uses the safe weapon controller")
	_expect(action_state != null, "Player retains the shared action state")
	_expect(router != null, "Divine Special input router installs automatically")
	_expect(radial_menu != null, "Divine Special radial menu installs automatically")
	if (
		controller == null
		or weapon == null
		or action_state == null
		or router == null
		or radial_menu == null
	):
		_finish(player, floor)
		return

	router.set("force_debug_catalog_access", true)
	controller.passive_recharge_enabled = false

	_validate_controller_isolation(router)
	_validate_startup_conversion_and_refund(controller, weapon, router)
	_validate_unavailable_chord_preserves_attack(controller, weapon, router)
	_validate_sequential_shoulders_remain_combo_input(controller, weapon, router)
	_validate_radial_selection_and_cancel(
		controller,
		action_state,
		router,
		radial_menu
	)
	await _validate_single_release_activation(controller, router)

	_finish(player, floor)


func _validate_controller_isolation(router: Node) -> void:
	router.call("handle_shoulder_button", 0, 9, true, 1000)
	router.call("handle_shoulder_button", 1, 10, true, 1050)
	_expect(
		not bool(router.call("is_chord_active")),
		"Controller 1 L cannot combine with controller 2 R"
	)
	router.call("handle_shoulder_button", 0, 9, false, 1060)
	router.call("handle_shoulder_button", 1, 10, false, 1060)


func _validate_startup_conversion_and_refund(
	controller: PlayerDivineSpecialController,
	weapon: SafeWeaponController,
	router: Node
) -> void:
	controller.force_full_charge("input_refund_test")
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	var stamina_before: int = GameState.get_stat("stamina")
	weapon.try_light_attack()
	var stamina_after_attack: int = GameState.get_stat("stamina")
	_expect(weapon.current_attack != null, "L still starts Light immediately")
	_expect(
		stamina_after_attack < stamina_before,
		"Immediate Light startup spends its authored stamina"
	)

	router.call("handle_shoulder_button", 0, 9, true, 2000)
	var chord_handled: bool = bool(
		router.call("handle_shoulder_button", 0, 10, true, 2050)
	)
	_expect(chord_handled, "Near-simultaneous L + R becomes a Divine Special chord")
	_expect(weapon.current_attack == null, "The converted startup attack is cancelled")
	_expect(
		GameState.get_stat("stamina") == stamina_before,
		"The converted startup attack refunds its exact stamina cost"
	)
	_expect(
		bool(router.call("cancel_active_chord", 0, "refund_test_cleanup")),
		"Cancelling the recognized chord succeeds"
	)
	_release_shoulders(router, 0, 2070)


func _validate_unavailable_chord_preserves_attack(
	controller: PlayerDivineSpecialController,
	weapon: SafeWeaponController,
	router: Node
) -> void:
	controller.set_charge(0.0, "input_empty_test")
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	weapon.try_light_attack()
	var active_attack: WeaponAttackDefinition = weapon.current_attack
	var stamina_after_attack: int = GameState.get_stat("stamina")
	router.call("handle_shoulder_button", 0, 9, true, 3000)
	var chord_handled: bool = bool(
		router.call("handle_shoulder_button", 0, 10, true, 3050)
	)
	_expect(not chord_handled, "An empty meter does not swallow the shoulder input")
	_expect(
		weapon.current_attack == active_attack,
		"An unavailable Divine Special preserves the ordinary Light attack"
	)
	_expect(
		GameState.get_stat("stamina") == stamina_after_attack,
		"Rejected chord does not fabricate a stamina refund"
	)
	weapon.cancel_current_attack("empty_chord_test_cleanup")
	_release_shoulders(router, 0, 3070)


func _validate_sequential_shoulders_remain_combo_input(
	controller: PlayerDivineSpecialController,
	weapon: SafeWeaponController,
	router: Node
) -> void:
	controller.force_full_charge("sequential_shoulder_test")
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	weapon.try_light_attack()
	router.call("handle_shoulder_button", 0, 9, true, 4000)
	var chord_handled: bool = bool(
		router.call("handle_shoulder_button", 0, 10, true, 4200)
	)
	weapon.try_heavy_attack()
	_expect(
		not chord_handled,
		"Shoulders separated beyond the chord window remain ordinary inputs"
	)
	_expect(
		weapon.current_attack != null and weapon.queued_input == WeaponController.INPUT_HEAVY,
		"Sequential L then R remains a Light-to-Heavy combo branch"
	)
	weapon.cancel_current_attack("sequential_test_cleanup")
	_release_shoulders(router, 0, 4220)


func _validate_radial_selection_and_cancel(
	controller: PlayerDivineSpecialController,
	action_state: PlayerActionState,
	router: Node,
	radial_menu: Node
) -> void:
	controller.select_special_by_id("ruvia_caldera_drop", true)
	controller.force_full_charge("radial_test")
	var charge_before: float = controller.divine_charge
	var time_scale_before: float = Engine.time_scale
	router.call("handle_shoulder_button", 0, 9, true, 5000)
	router.call("handle_shoulder_button", 0, 10, true, 5050)
	_expect(
		bool(router.call("open_radial_for_device", 0)),
		"Holding L + R opens the Divine Special radial"
	)
	_expect(bool(radial_menu.call("is_menu_open")), "Radial surface becomes visible")
	_expect(action_state.is_focus_menu_open, "Radial applies the shared menu action lock")
	_expect(Engine.time_scale <= 0.3501, "Radial modestly slows the battlefield")
	_expect(
		bool(router.call("update_selection_from_vector", Vector2.RIGHT, 0)),
		"Right stick direction selects another unlocked Special"
	)
	_expect(
		controller.get_selected_special(true).special_id == "ruvia_wildfire_procession",
		"Right-stick selection updates the shared Divine Special selection"
	)
	_expect(
		bool(router.call("cancel_active_chord", 0, "radial_cancel_test")),
		"B-style cancellation closes the radial"
	)
	_expect(not bool(radial_menu.call("is_menu_open")), "Cancelled radial is hidden")
	_expect(not action_state.is_focus_menu_open, "Cancellation restores ordinary control")
	_expect(
		is_equal_approx(Engine.time_scale, time_scale_before),
		"Cancellation restores the previous time scale"
	)
	_expect(
		is_equal_approx(controller.divine_charge, charge_before),
		"Opening and cancelling the radial consumes no Divine Charge"
	)
	_release_shoulders(router, 0, 5080)


func _validate_single_release_activation(
	controller: PlayerDivineSpecialController,
	router: Node
) -> void:
	controller.select_special_by_id("ruvia_hearth_first_flame", true)
	controller.force_full_charge("single_release_test")
	var activations_before: int = controller.total_activations
	router.call("handle_shoulder_button", 0, 9, true, 6000)
	router.call("handle_shoulder_button", 0, 10, true, 6050)
	_expect(
		bool(router.call("finish_active_chord", 0, false, "test_release")),
		"Releasing the recognized chord activates the selected Special"
	)
	_expect(
		controller.total_activations == activations_before + 1,
		"Chord release activates exactly once"
	)
	_expect(
		not bool(router.call("finish_active_chord", 0, false, "duplicate_release")),
		"A duplicate release cannot activate again"
	)
	_expect(
		controller.total_activations == activations_before + 1,
		"Duplicate release leaves the activation count unchanged"
	)
	_release_shoulders(router, 0, 6070)
	if controller.active_effect != null:
		controller.cancel_active_special("single_release_test_cleanup")
		await get_tree().process_frame


func _release_shoulders(router: Node, device: int, now_msec: int) -> void:
	router.call("handle_shoulder_button", device, 9, false, now_msec)
	router.call("handle_shoulder_button", device, 10, false, now_msec)


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 20)
	GameState.set_stat("mana", 20)
	GameState.set_stat("max_stamina", 100)
	GameState.set_stat("stamina", 100)
	GameState.set_stat("max_stance", 20)
	GameState.set_stat("stance", 20)


func _make_floor() -> StaticBody3D:
	var floor: StaticBody3D = StaticBody3D.new()
	floor.name = "DivineSpecialInputTestFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(30.0, 0.2, 30.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _restore_stats() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(
			stat_id,
			int(GameState.stats[stat_value])
		)


func _finish(player: Node, floor: Node) -> void:
	Engine.time_scale = original_time_scale
	_restore_stats()
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(floor):
		floor.queue_free()
	if failures.is_empty():
		print("DIVINE_SPECIAL_INPUT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("DIVINE_SPECIAL_INPUT_SMOKE_TEST: " + failure)
	get_tree().quit(1)
