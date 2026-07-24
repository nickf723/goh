extends Node

const PlayerActionStateScript: Script = preload("res://scripts/player/player_action_state.gd")
const QuickItemControllerScript: Script = preload("res://scripts/player/player_quick_item_controller.gd")
const QuickItemDefinitionScript: Script = preload("res://scripts/items/quick_item_definition.gd")
const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")

var failures: Array[String] = []
var original_snapshot: Dictionary


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_snapshot = GameState.get_stat_snapshot()
	set_resource_pair("health", 2, 5)
	set_resource_pair("stamina", 5, 5)
	set_resource_pair("mana", 5, 5)
	set_resource_pair("stance", 5, 5)

	var actor: CharacterBody3D = CharacterBody3D.new()
	actor.name = "QuickItemTestPlayer"
	add_child(actor)

	var action_state: PlayerActionState = PlayerActionStateScript.new() as PlayerActionState
	action_state.name = "PlayerActionState"
	actor.add_child(action_state)
	action_state.set_process(false)

	var flask: QuickItemDefinition = QuickItemDefinitionScript.new() as QuickItemDefinition
	flask.item_id = "test_healing_flask"
	flask.display_name = "Test Healing Flask"
	flask.short_label = "FLASK"
	flask.max_charges = 3
	flask.use_duration = 0.9
	flask.movement_multiplier = 0.35
	flask.requires_grounded = false
	flask.restore_resource_id = "health"
	flask.restore_amount = 2

	var controller: PlayerQuickItemController = QuickItemControllerScript.new() as PlayerQuickItemController
	controller.name = "PlayerQuickItemController"
	controller.up_item = flask
	actor.add_child(controller)
	controller.set_process(false)

	assert_equal(controller.get_slot_charges(PlayerQuickItemController.SLOT_UP), 3, "belt initializes flask charges")
	assert_true(controller.try_use_slot(PlayerQuickItemController.SLOT_UP), "damaged player can begin flask use")
	assert_true(action_state.is_using_item, "flask owns committed action state")
	assert_true(not action_state.can_attack(), "flask blocks weapon attacks")
	assert_true(not action_state.can_cast(), "flask blocks casting")
	assert_true(not action_state.can_dodge(), "flask blocks dodge")
	assert_true(not action_state.can_guard(), "flask blocks guard")
	assert_equal(controller.get_movement_multiplier(), 0.35, "flask slows movement during commitment")

	controller.advance_use(0.45)
	assert_equal(GameState.get_stat("health"), 2, "partial use does not heal early")
	assert_equal(controller.get_slot_charges(PlayerQuickItemController.SLOT_UP), 3, "partial use does not consume charge")

	action_state.begin_stagger(0.3)
	controller.advance_use(0.01)
	assert_true(not controller.is_using_item(), "stagger interrupts flask")
	assert_equal(GameState.get_stat("health"), 2, "interrupted flask does not heal")
	assert_equal(controller.get_slot_charges(PlayerQuickItemController.SLOT_UP), 3, "interrupted flask preserves charge")

	action_state.reset_for_respawn()
	assert_true(controller.try_use_slot(PlayerQuickItemController.SLOT_UP), "flask can be retried after recovery")
	controller.advance_use(1.0)
	assert_true(not controller.is_using_item(), "completed flask exits item action")
	assert_equal(GameState.get_stat("health"), 4, "completed flask restores health")
	assert_equal(controller.get_slot_charges(PlayerQuickItemController.SLOT_UP), 2, "completed flask consumes one charge")

	GameState.restore_rest_resources()
	assert_equal(controller.get_slot_charges(PlayerQuickItemController.SLOT_UP), 3, "rest refills flask charges")
	assert_equal(GameState.get_stat("health"), 5, "rest restores health")
	assert_true(not controller.try_use_slot(PlayerQuickItemController.SLOT_UP), "full-health player cannot waste flask")

	assert_input_contract()
	assert_player_scene_contract()

	actor.queue_free()
	restore_snapshot()

	if failures.is_empty():
		print("QUICK_ITEM_BELT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("QUICK_ITEM_BELT_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_input_contract() -> void:
	var expected: Array[Dictionary] = [
		{"action": "quick_item_up", "button": JOY_BUTTON_DPAD_UP},
		{"action": "quick_item_left", "button": JOY_BUTTON_DPAD_LEFT},
		{"action": "quick_item_right", "button": JOY_BUTTON_DPAD_RIGHT},
		{"action": "quick_item_down", "button": JOY_BUTTON_DPAD_DOWN},
	]
	for row: Dictionary in expected:
		var action_name: StringName = StringName(str(row["action"]))
		assert_true(InputMap.has_action(action_name), str(action_name) + " action exists")
		assert_true(action_has_joy_button(action_name, int(row["button"])), str(action_name) + " has directional D-pad button")
	assert_true(action_has_key(&"quick_item_up", KEY_H), "H mirrors Quick Item Up")


func assert_player_scene_contract() -> void:
	var player: Node = PlayerScene.instantiate()
	var controller: Node = player.get_node_or_null("PlayerQuickItemController")
	if controller == null:
		failures.append("reusable Player scene is missing PlayerQuickItemController")
	else:
		var item: Variant = controller.get("up_item")
		if not item is QuickItemDefinition:
			failures.append("Player Quick Item Up is missing its Healing Flask definition")
		elif (item as QuickItemDefinition).item_id != "healing_flask":
			failures.append("Player Quick Item Up must equip healing_flask")
	if player.get_node_or_null("QuickItemBeltUI") == null:
		failures.append("reusable Player scene is missing QuickItemBeltUI")
	player.queue_free()


func action_has_joy_button(action_name: StringName, button: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false


func action_has_key(action_name: StringName, keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.physical_keycode == keycode or key_event.keycode == keycode:
				return true
	return false


func set_resource_pair(resource_name: String, current: int, maximum: int) -> void:
	GameState.set_stat("max_" + resource_name, maximum)
	GameState.set_stat(resource_name, current)


func restore_snapshot() -> void:
	GameState.stats = original_snapshot.duplicate(true)
	for stat_variant: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_variant)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_variant]))


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(label + ": expected " + str(expected) + " but got " + str(actual))


func assert_true(value: bool, label: String) -> void:
	if not value:
		failures.append(label + ": expected true")
