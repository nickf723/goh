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
	player.name = "ControllerSelectionQuirksTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	var control_router: Node = player.get_node_or_null("PlayerControlRouter")
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	var divine_router: Node = player.get_node_or_null("DivineSpecialInputRouter")
	var divine_controller: PlayerDivineSpecialController = player.get_node_or_null(
		"DivineSpecialController"
	) as PlayerDivineSpecialController
	var radial_menu: Node = player.get_node_or_null("DivineSpecialRadialMenu")

	_expect(control_router != null, "Contextual control router installs")
	_expect(ability_caster != null, "Ability caster remains available")
	_expect(divine_router != null, "Divine Special router installs")
	_expect(divine_controller != null, "Divine Special controller remains available")
	_expect(radial_menu != null, "Divine Special radial remains available")
	if (
		control_router == null
		or ability_caster == null
		or divine_router == null
		or divine_controller == null
		or radial_menu == null
	):
		_finish(player, floor)
		return

	divine_router.set("force_debug_catalog_access", true)
	divine_controller.passive_recharge_enabled = false
	_validate_focus_dpad_navigation(control_router, ability_caster)
	_validate_divine_selection_while_charging(
		divine_router,
		divine_controller,
		radial_menu
	)
	await _validate_ready_tap_activation(divine_router, divine_controller)
	_finish(player, floor)


func _validate_focus_dpad_navigation(
	control_router: Node,
	ability_caster: Node
) -> void:
	_expect(
		bool(control_router.call("handle_focus_action", true)),
		"Holding Focus opens the full spell menu"
	)
	var element_before: int = int(ability_caster.get("focus_element_index"))
	var right_event: InputEventJoypadButton = InputEventJoypadButton.new()
	right_event.button_index = JOY_BUTTON_DPAD_RIGHT
	right_event.pressed = true
	_expect(
		bool(control_router.call("_handle_focus_dpad", right_event)),
		"D-pad Right is handled inside Focus"
	)
	var element_after_right: int = int(ability_caster.get("focus_element_index"))
	_expect(
		element_after_right != element_before,
		"D-pad Right navigates the Focus element menu"
	)
	var left_event: InputEventJoypadButton = InputEventJoypadButton.new()
	left_event.button_index = JOY_BUTTON_DPAD_LEFT
	left_event.pressed = true
	_expect(
		bool(control_router.call("_handle_focus_dpad", left_event)),
		"D-pad Left is handled inside Focus"
	)
	_expect(
		int(ability_caster.get("focus_element_index")) == element_before,
		"D-pad Left returns to the previous Focus element"
	)
	control_router.call("handle_focus_action", false)


func _validate_divine_selection_while_charging(
	divine_router: Node,
	controller: PlayerDivineSpecialController,
	radial_menu: Node
) -> void:
	controller.select_special_by_id("ruvia_caldera_drop", true)
	controller.set_charge(24.0, "selection_while_charging_test")
	var charge_before: float = controller.divine_charge
	var activations_before: int = controller.total_activations
	divine_router.call("handle_special_button", 0, true, 1000)
	_expect(
		bool(divine_router.call("is_gesture_active", 0)),
		"D-pad Down can begin selection while Divine Charge is incomplete"
	)
	_expect(
		bool(divine_router.call("open_radial_for_device", 0)),
		"The Divine radial opens while charge is rebuilding"
	)
	_expect(bool(radial_menu.call("is_menu_open")), "Charging radial becomes visible")
	_expect(
		bool(divine_router.call(
			"update_selection_from_vector",
			Vector2.RIGHT,
			0
		)),
		"Right stick changes the selected charging Special"
	)
	var selected_after_change: DivineSpecialDefinition = controller.get_selected_special(true)
	_expect(
		selected_after_change != null
		and selected_after_change.special_id == "ruvia_wildfire_procession",
		"The changed Divine Special is stored immediately"
	)
	_expect(
		bool(divine_router.call("handle_special_button", 0, false, 1400)),
		"Releasing a held Divine radial closes it cleanly"
	)
	_expect(
		controller.total_activations == activations_before,
		"Changing a Divine Special does not activate it"
	)
	_expect(
		is_equal_approx(controller.divine_charge, charge_before),
		"Changing a Divine Special consumes no charge"
	)
	_expect(
		not bool(radial_menu.call("is_menu_open")),
		"Selection release closes the Divine radial"
	)

	divine_router.call("handle_special_button", 0, true, 1500)
	_expect(
		bool(divine_router.call("handle_special_button", 0, false, 1540)),
		"A not-ready Divine tap is still consumed by the Divine input"
	)
	_expect(
		controller.total_activations == activations_before,
		"A not-ready tap cannot activate the selected Special"
	)


func _validate_ready_tap_activation(
	divine_router: Node,
	controller: PlayerDivineSpecialController
) -> void:
	controller.select_special_by_id("ruvia_hearth_first_flame", true)
	controller.force_full_charge("ready_tap_test")
	var activations_before: int = controller.total_activations
	divine_router.call("handle_special_button", 0, true, 2000)
	divine_router.call("handle_special_button", 0, false, 2050)
	_expect(
		controller.total_activations == activations_before + 1,
		"A quick ready D-pad Down tap still activates exactly once"
	)
	if controller.active_effect != null:
		controller.cancel_active_special("selection quirks test cleanup")
		await get_tree().process_frame


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
	floor.name = "ControllerSelectionQuirksTestFloor"
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
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))


func _finish(player: Node, floor: Node) -> void:
	Engine.time_scale = original_time_scale
	_restore_stats()
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(floor):
		floor.queue_free()
	if failures.is_empty():
		print("CONTROLLER_SELECTION_QUIRKS_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CONTROLLER_SELECTION_QUIRKS_SMOKE_TEST: " + failure)
	get_tree().quit(1)
