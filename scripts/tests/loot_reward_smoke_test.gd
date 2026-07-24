extends Node

const EnemyLootTable: LootTable = preload("res://data/loot/survival_enemy_supplies.tres")
const CrateScene: PackedScene = preload("res://scenes/items/breakable_supply_container.tscn")
const ChestScene: PackedScene = preload("res://scenes/items/reward_choice_chest.tscn")

var failures: Array[String] = []
var original_inventory: Dictionary


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_inventory = GameState.get_inventory_snapshot()
	GameState.set_inventory_count("healing_flask", 0)
	GameState.set_inventory_count("oil_flask", 0)
	GameState.set_inventory_count("noise_maker", 0)

	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 723
	var rolled: Array[Dictionary] = EnemyLootTable.roll_loot(random)
	assert_equal(rolled.size(), 1, "enemy table resolves one weighted stack")
	if not rolled.is_empty():
		assert_true(["oil_flask", "noise_maker"].has(str(rolled[0].get("item_id", ""))), "enemy table resolves an authored supply")
		assert_equal(int(rolled[0].get("quantity", 0)), 1, "enemy supply quantity is authored")

	var source: Node3D = Node3D.new()
	source.name = "LootSource"
	add_child(source)
	var dropper: LootDropper = LootDropper.new()
	dropper.loot_table = EnemyLootTable
	dropper.drop_on_health_depleted = false
	dropper.auto_collect_drops = false
	dropper.fixed_seed = 723
	dropper.scatter_radius = 0.0
	source.add_child(dropper)
	var spawned: Array[WorldItemPickup] = dropper.drop_now()
	assert_equal(spawned.size(), 1, "LootDropper converts a result into a world pickup")
	assert_true(dropper.has_dropped, "LootDropper prevents duplicate defeat rewards")
	if not spawned.is_empty():
		var pickup: WorldItemPickup = spawned[0]
		var item_id: String = pickup.item_definition.item_id
		var before_count: int = GameState.get_inventory_count(item_id)
		var result: Dictionary = pickup.interact()
		assert_true(str(result.get("message", "")).contains("Collected"), "runtime drop uses normal pickup interaction")
		assert_equal(GameState.get_inventory_count(item_id), before_count + 1, "runtime drop enters shared inventory")

	var crate: BreakableSupplyContainer = CrateScene.instantiate() as BreakableSupplyContainer
	add_child(crate)
	var crate_receiver: Node = crate.get_node_or_null("HitReceiver")
	assert_true(crate_receiver != null, "supply crate owns a HitReceiver")
	if crate_receiver != null:
		crate_receiver.call("receive_hit", 2)
	assert_true(crate.broken, "health depletion breaks the supply crate")
	assert_true(crate.loot_dropper != null and crate.loot_dropper.has_dropped, "broken crate resolves its loot table")

	var chest: RewardChoiceChest = ChestScene.instantiate() as RewardChoiceChest
	add_child(chest)
	assert_true(chest.locked, "reward chest begins locked")
	chest.unlock_chest()
	var open_result: Dictionary = chest.interact()
	assert_true(str(open_result.get("message", "")).contains("REWARD REVEALED"), "unlocked chest reveals choices")
	assert_equal(chest.choice_pickups.size(), 3, "reward chest creates three world-space choices")
	if not chest.choice_pickups.is_empty():
		var chosen: WorldItemPickup = chest.choice_pickups[0]
		var chosen_id: String = chosen.item_definition.item_id
		GameState.set_inventory_count(chosen_id, 0)
		var chosen_quantity: int = chosen.quantity
		chosen.interact()
		assert_true(chest.claimed, "collecting one reward claims the chest")
		assert_equal(GameState.get_inventory_count(chosen_id), chosen_quantity, "chosen reward enters inventory")
		assert_equal(chest.choice_pickups.size(), 0, "unchosen rewards are removed")

	restore_inventory()
	for pickup_node: Node in get_tree().get_nodes_in_group("world_item_pickup"):
		pickup_node.queue_free()
	source.queue_free()
	crate.queue_free()
	chest.queue_free()

	if failures.is_empty():
		print("LOOT_REWARD_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("LOOT_REWARD_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func restore_inventory() -> void:
	GameState.inventory = original_inventory.duplicate(true)
	for item_id_variant: Variant in GameState.inventory.keys():
		var item_id: String = str(item_id_variant)
		GameState.inventory_changed.emit(item_id, int(GameState.inventory[item_id_variant]))


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(label + ": expected " + str(expected) + " but got " + str(actual))


func assert_true(value: bool, label: String) -> void:
	if not value:
		failures.append(label + ": expected true")
