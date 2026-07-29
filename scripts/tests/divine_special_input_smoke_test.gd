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
	player.name = "ControllerGrammarTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var divine_controller: PlayerDivineSpecialController = player.get_node_or_null(
		"DivineSpecialController"
	) as PlayerDivineSpecialController
	var weapon: SafeWeaponController = player.get_node_or_null(
		"WeaponController"
	) as SafeWeaponController
	var action_state: PlayerActionState = player.get_node_or_null(
		"PlayerActionState"
	) as PlayerActionState
	var divine_router: Node = player.get_node_or_null("DivineSpecialInputRouter")
	var radial_menu: Node = player.get_node_or_null("DivineSpecialRadialMenu")
	var control_router: PlayerControlRouter = player.get_node_or_null(
		"PlayerControlRouter"
	) as PlayerControlRouter
	var bootstrap: WeaponInputBootstrap = player.get_node_or_null(
		"WeaponController/WeaponInputBootstrap"
	) as WeaponInputBootstrap
	var quick_items: PlayerQuickItemController = player.get_node_or_null(
		"PlayerQuickItemController"
	) as PlayerQuickItemController
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")

	_expect(divine_controller != null, "Player retains the Divine Special controller")
	_expect(weapon != null, "Player retains the safe weapon controller")
	_expect(action_state != null, "Player retains the shared action state")
	_expect(divine_router != null, "D-pad Divine Special router installs")
	_expect(radial_menu != null, "Divine Special radial menu installs")
	_expect(control_router != null, "Unified player control router installs")
	_expect(bootstrap != null, "Authoritative input bootstrap remains available")
	_expect(quick_items != null, "Quick-item controller remains available")
	_expect(ability_caster != null, "Ability caster remains available")
	if (
		divine_controller == null
		or weapon == null
		or action_state == null
		or divine_router == null
		or radial_menu == null
		or control_router == null
		or bootstrap == null
		or quick_items == null
		or ability_caster == null
	):
		_finish(player, floor, bootstrap)
		return

	divine_router.set("force_debug_catalog_access", true)
	divine_controller.passive_recharge_enabled = false

	_validate_default_hand_roles(bootstrap)
	_validate_mirrored_hand_roles(bootstrap)
	_validate_focus_hold(control_router, ability_caster)
	_validate_quick_spell_ribbon(control_router, ability_caster)
	_validate_quick_item_tap_and_hold(control_router, quick_items)
	_validate_divine_input_isolation(divine_router)
	_validate_attack_is_not_converted(divine_controller, weapon, divine_router)
	_validate_radial_selection_and_cancel(
		divine_controller,
		action_state,
		divine_router,
		radial_menu
	)
	await _validate_single_release_activation(divine_controller, divine_router)

	_finish(player, floor, bootstrap)


func _validate_default_hand_roles(bootstrap: WeaponInputBootstrap) -> void:
	bootstrap.set_hand_role_preset(
		WeaponInputBootstrap.PRESET_COMBAT_RIGHT_MAGIC_LEFT,
		false
	)
	_expect(
		_action_has_button(&"weapon_light_attack", JOY_BUTTON_RIGHT_SHOULDER),
		"Default R performs Light Attack"
	)
	_expect(
		_action_has_motion(&"weapon_heavy_attack", 5, 1.0),
		"Default ZR performs Heavy Attack"
	)
	_expect(
		_action_has_button(&"spell_menu", JOY_BUTTON_LEFT_SHOULDER),
		"Default L holds Focus"
	)
	_expect(
		_action_has_motion(&"cast_spell", 4, 1.0),
		"Default ZL casts"
	)
	_expect(
		not _action_has_button(&"weapon_light_attack", JOY_BUTTON_LEFT_SHOULDER),
		"Default Light Attack has no legacy L binding"
	)
	_expect(
		not _action_has_button(&"weapon_light_attack", JOY_BUTTON_X),
		"Default Light Attack has no hidden face-button binding"
	)
	_expect(
		_action_has_button(&"quick_item_cycle_use", JOY_BUTTON_DPAD_UP),
		"D-pad Up owns quick items"
	)
	_expect(
		_action_has_button(&"quick_spell_previous", JOY_BUTTON_DPAD_LEFT),
		"D-pad Left owns previous quick spell"
	)
	_expect(
		_action_has_button(&"quick_spell_next", JOY_BUTTON_DPAD_RIGHT),
		"D-pad Right owns next quick spell"
	)
	_expect(
		_action_has_button(&"divine_special", JOY_BUTTON_DPAD_DOWN),
		"D-pad Down owns Divine Specials"
	)


func _validate_mirrored_hand_roles(bootstrap: WeaponInputBootstrap) -> void:
	bootstrap.set_hand_role_preset(
		WeaponInputBootstrap.PRESET_COMBAT_LEFT_MAGIC_RIGHT,
		false
	)
	_expect(
		_action_has_button(&"weapon_light_attack", JOY_BUTTON_LEFT_SHOULDER),
		"Mirrored L performs Light Attack"
	)
	_expect(
		_action_has_motion(&"weapon_heavy_attack", 4, 1.0),
		"Mirrored ZL performs Heavy Attack"
	)
	_expect(
		_action_has_button(&"spell_menu", JOY_BUTTON_RIGHT_SHOULDER),
		"Mirrored R holds Focus"
	)
	_expect(
		_action_has_motion(&"cast_spell", 5, 1.0),
		"Mirrored ZR casts"
	)
	bootstrap.set_hand_role_preset(
		WeaponInputBootstrap.PRESET_COMBAT_RIGHT_MAGIC_LEFT,
		false
	)


func _validate_focus_hold(
	control_router: PlayerControlRouter,
	ability_caster: Node
) -> void:
	_expect(
		control_router.handle_focus_action(true),
		"Focus press is handled by the unified router"
	)
	_expect(
		bool(ability_caster.call("is_focus_spell_menu_open")),
		"Holding the magic bumper opens the full spell library"
	)
	_expect(
		control_router.handle_focus_action(false),
		"Focus release is handled by the unified router"
	)
	_expect(
		not bool(ability_caster.call("is_focus_spell_menu_open")),
		"Releasing the magic bumper closes Focus"
	)


func _validate_quick_spell_ribbon(
	control_router: PlayerControlRouter,
	ability_caster: Node
) -> void:
	var names: Array[String] = control_router.get_quick_spell_names()
	_expect(names.size() == 3, "Quick-spell ribbon exposes three favorites")
	var debug_before: Dictionary = control_router.get_debug_data()
	var indices_variant: Variant = debug_before.get("favorite_indices", [])
	var favorite_indices: Array = indices_variant as Array
	if favorite_indices.size() < 2:
		_expect(false, "Quick-spell ribbon has at least two selectable favorites")
		return
	var cursor_before: int = control_router.get_selected_quick_spell_cursor()
	_expect(
		control_router.cycle_quick_spell(1),
		"D-pad Right advances the quick-spell ribbon"
	)
	var cursor_after: int = control_router.get_selected_quick_spell_cursor()
	_expect(
		cursor_after == wrapi(cursor_before + 1, 0, favorite_indices.size()),
		"Quick-spell cursor wraps through favorites"
	)
	_expect(
		int(ability_caster.get("current_ability_index"))
		== int(favorite_indices[cursor_after]),
		"Quick-spell selection updates the cast spell immediately"
	)
	_expect(
		control_router.cycle_quick_spell(-1),
		"D-pad Left returns to the previous quick spell"
	)


func _validate_quick_item_tap_and_hold(
	control_router: PlayerControlRouter,
	quick_items: PlayerQuickItemController
) -> void:
	var original_item: QuickItemDefinition = quick_items.get_slot_item(0)
	if original_item == null:
		_expect(false, "Test player has a starting quick item")
		return
	quick_items.set_local_slot_item(1, original_item)
	var selected_before: int = control_router.get_selected_quick_item_slot()
	control_router.handle_quick_item_button(0, true)
	control_router.handle_quick_item_button(0, false)
	var selected_after_tap: int = control_router.get_selected_quick_item_slot()
	_expect(
		selected_after_tap != selected_before,
		"A quick D-pad Up tap cycles the selected item"
	)

	GameState.set_stat("health", 50)
	control_router.handle_quick_item_button(0, true)
	control_router.call("_process", 0.31)
	_expect(
		quick_items.active_slot == selected_after_tap,
		"Holding D-pad Up uses the selected item"
	)
	control_router.handle_quick_item_button(0, false)
	_expect(
		control_router.get_selected_quick_item_slot() == selected_after_tap,
		"Releasing after item use does not also cycle"
	)
	if quick_items.is_using_item():
		quick_items.cancel_active_use("controller grammar test cleanup", false)
	quick_items.set_local_slot_item(1, null)


func _validate_divine_input_isolation(divine_router: Node) -> void:
	var divine_controller: PlayerDivineSpecialController = divine_router.get_parent().get_node_or_null(
		"DivineSpecialController"
	) as PlayerDivineSpecialController
	if divine_controller != null:
		divine_controller.force_full_charge("input_isolation_test")
	_expect(
		bool(divine_router.call("handle_special_button", 0, true, 1000)),
		"Controller 1 can own D-pad Down"
	)
	_expect(
		not bool(divine_router.call("handle_special_button", 1, true, 1010)),
		"Controller 2 cannot steal an active Divine gesture"
	)
	divine_router.call("cancel_active_gesture", 0, "isolation_cleanup")


func _validate_attack_is_not_converted(
	divine_controller: PlayerDivineSpecialController,
	weapon: SafeWeaponController,
	divine_router: Node
) -> void:
	divine_controller.force_full_charge("no_conversion_test")
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	weapon.try_light_attack()
	var active_attack: WeaponAttackDefinition = weapon.current_attack
	var stamina_after_attack: int = GameState.get_stat("stamina")
	divine_router.call("handle_special_button", 0, true, 2000)
	_expect(
		not bool(divine_router.call("is_gesture_active")),
		"Divine Special waits for an active weapon attack to finish"
	)
	_expect(
		weapon.current_attack == active_attack,
		"D-pad Down never cancels or converts the current attack"
	)
	_expect(
		GameState.get_stat("stamina") == stamina_after_attack,
		"Rejected Divine input never fabricates a stamina refund"
	)
	weapon.cancel_current_attack("no_conversion_test_cleanup")
	divine_router.call("handle_special_button", 0, false, 2020)


func _validate_radial_selection_and_cancel(
	controller: PlayerDivineSpecialController,
	action_state: PlayerActionState,
	divine_router: Node,
	radial_menu: Node
) -> void:
	controller.select_special_by_id("ruvia_caldera_drop", true)
	controller.force_full_charge("radial_test")
	var charge_before: float = controller.divine_charge
	var time_scale_before: float = Engine.time_scale
	divine_router.call("handle_special_button", 0, true, 3000)
	_expect(
		bool(divine_router.call("open_radial_for_device", 0)),
		"Holding D-pad Down opens the Divine Special radial"
	)
	_expect(bool(radial_menu.call("is_menu_open")), "Radial surface becomes visible")
	_expect(action_state.is_focus_menu_open, "Radial applies the shared menu action lock")
	_expect(Engine.time_scale <= 0.3501, "Radial modestly slows the battlefield")
	_expect(
		bool(divine_router.call("update_selection_from_vector", Vector2.RIGHT, 0)),
		"Right stick direction selects another unlocked Special"
	)
	_expect(
		controller.get_selected_special(true).special_id
		== "ruvia_wildfire_procession",
		"Right-stick selection updates the shared Divine selection"
	)
	_expect(
		bool(divine_router.call("cancel_active_gesture", 0, "radial_cancel_test")),
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


func _validate_single_release_activation(
	controller: PlayerDivineSpecialController,
	divine_router: Node
) -> void:
	controller.select_special_by_id("ruvia_hearth_first_flame", true)
	controller.force_full_charge("single_release_test")
	var activations_before: int = controller.total_activations
	divine_router.call("handle_special_button", 0, true, 4000)
	_expect(
		bool(divine_router.call("handle_special_button", 0, false, 4050)),
		"Tapping D-pad Down activates the selected Special"
	)
	_expect(
		controller.total_activations == activations_before + 1,
		"D-pad release activates exactly once"
	)
	_expect(
		not bool(divine_router.call("finish_active_gesture", 0, false, "duplicate")),
		"A duplicate release cannot activate again"
	)
	_expect(
		controller.total_activations == activations_before + 1,
		"Duplicate release leaves activation count unchanged"
	)
	if controller.active_effect != null:
		controller.cancel_active_special("single_release_test_cleanup")
		await get_tree().process_frame


func _action_has_button(action_name: StringName, button_index: int) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event: InputEvent in InputMap.action_get_events(action_name):
		if (
			event is InputEventJoypadButton
			and (event as InputEventJoypadButton).button_index == button_index
		):
			return true
	return false


func _action_has_motion(
	action_name: StringName,
	axis: int,
	axis_value: float
) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event: InputEvent in InputMap.action_get_events(action_name):
		if not (event is InputEventJoypadMotion):
			continue
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if motion.axis == axis and is_equal_approx(motion.axis_value, axis_value):
			return true
	return false


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
	floor.name = "ControllerGrammarTestFloor"
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


func _finish(
	player: Node,
	floor: Node,
	bootstrap: WeaponInputBootstrap
) -> void:
	Engine.time_scale = original_time_scale
	if bootstrap != null:
		bootstrap.set_hand_role_preset(
			WeaponInputBootstrap.PRESET_COMBAT_RIGHT_MAGIC_LEFT,
			false
		)
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
