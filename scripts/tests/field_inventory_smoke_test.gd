extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const PickupScene: PackedScene = preload("res://scenes/items/world_item_pickup.tscn")
const OilFlask: QuickItemDefinition = preload("res://data/items/oil_flask.tres")
const NoiseMaker: QuickItemDefinition = preload("res://data/items/noise_maker.tres")

var failures: Array[String] = []
var original_inventory: Dictionary
var original_slots: Array[String]
var original_pickups: Dictionary


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_inventory = GameState.get_inventory_snapshot()
	original_slots = GameState.get_quick_item_slots_snapshot()
	original_pickups = GameState.collected_pickups.duplicate(true)
	GameState.reset_inventory_to_defaults(false)
	GameState.add_inventory_item("oil_flask", 2)
	GameState.add_inventory_item("noise_maker", 2)
	GameState.set_quick_item_slot(PlayerQuickItemController.SLOT_LEFT, "oil_flask")
	GameState.set_quick_item_slot(PlayerQuickItemController.SLOT_RIGHT, "noise_maker")

	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "Player"
	add_child(player)
	var controller := player.get_node_or_null("PlayerQuickItemController") as PlayerQuickItemController
	var action_state := player.get_node_or_null("PlayerActionState") as PlayerActionState
	if controller != null:
		controller.set_process(false)
	if action_state != null:
		action_state.set_process(false)

	assert_true(controller != null, "Player owns inventory-backed quick belt")
	if controller != null:
		assert_equal(controller.get_slot_item(PlayerQuickItemController.SLOT_UP).item_id, "healing_flask", "Up keeps Healing Flask")
		assert_equal(controller.get_slot_item(PlayerQuickItemController.SLOT_LEFT).item_id, "oil_flask", "Left loads Oil Flask")
		assert_equal(controller.get_slot_item(PlayerQuickItemController.SLOT_RIGHT).item_id, "noise_maker", "Right loads Noise Maker")
		assert_true(controller.try_use_slot(PlayerQuickItemController.SLOT_LEFT), "Oil Flask begins committed use")
		controller.advance_use(1.0)
		assert_equal(GameState.get_inventory_count("oil_flask"), 1, "successful throw consumes shared Oil stock")
		assert_true(get_tree().get_nodes_in_group("quick_item_delivery").size() > 0, "Oil use launches shared delivery scene")
		assert_true(controller.assign_slot_by_item_id(PlayerQuickItemController.SLOT_DOWN, "oil_flask"), "menu contract can assign owned item")
		assert_equal(GameState.get_quick_item_slot(PlayerQuickItemController.SLOT_DOWN), "oil_flask", "belt assignment persists in GameState")

	GameState.set_inventory_count("noise_maker", 0)
	var pickup := PickupScene.instantiate() as WorldItemPickup
	pickup.item_definition = NoiseMaker
	pickup.quantity = 2
	pickup.pickup_id = "field_inventory_smoke_noise"
	add_child(pickup)
	var pickup_result: Dictionary = pickup.interact()
	assert_equal(GameState.get_inventory_count("noise_maker"), 2, "world pickup adds inventory stock")
	assert_true(str(pickup_result.get("message", "")).contains("Noise Maker"), "pickup reports collected item")
	assert_true(GameState.has_collected_pickup("field_inventory_smoke_noise"), "unique pickup records collection")
	assert_true(pickup.collected, "collected world pickup disables itself")

	GameState.set_inventory_count("healing_flask", 1)
	GameState.set_inventory_count("oil_flask", 1)
	GameState.restore_rest_resources()
	assert_equal(GameState.get_inventory_count("healing_flask"), 3, "rest refills Healing Flask")
	assert_equal(GameState.get_inventory_count("oil_flask"), 1, "rest does not create ordinary consumables")
	assert_equal(GameState.get_inventory_count("noise_maker"), 2, "rest preserves Noise Maker stock")

	var menu_data: Dictionary = FullMenuDirector.build_menu_data()
	var inventory_rows: Array = menu_data.get("inventory_items", [])
	var slot_rows: Array = menu_data.get("quick_item_slots", [])
	assert_true(inventory_rows.size() >= 3, "Field Kit receives owned inventory rows")
	assert_equal(slot_rows.size(), 4, "Field Kit receives four quick-item slots")

	restore_state()
	player.queue_free()
	pickup.queue_free()

	if failures.is_empty():
		print("FIELD_INVENTORY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FIELD_INVENTORY_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func restore_state() -> void:
	GameState.inventory = original_inventory.duplicate(true)
	GameState.quick_item_slots = original_slots.duplicate()
	GameState.collected_pickups = original_pickups.duplicate(true)
	for item_id_variant: Variant in GameState.inventory.keys():
		var item_id: String = str(item_id_variant)
		GameState.inventory_changed.emit(item_id, int(GameState.inventory[item_id_variant]))
	for slot_index: int in range(GameState.quick_item_slots.size()):
		GameState.quick_item_slot_changed.emit(slot_index, GameState.quick_item_slots[slot_index])


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(label + ": expected " + str(expected) + " but got " + str(actual))


func assert_true(value: bool, label: String) -> void:
	if not value:
		failures.append(label + ": expected true")
