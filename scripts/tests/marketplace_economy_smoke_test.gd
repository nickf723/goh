extends Node

var failures: Array[String] = []


func _ready() -> void:
	var original_currency: int = GameState.get_currency()
	var original_potions: int = GameState.get_inventory_count("healing_potion")
	GameState.set_currency(100)
	GameState.set_inventory_count("healing_potion", 0)
	var merchant := MerchantTradingPost.new()
	add_child(merchant)
	await get_tree().process_frame
	_expect(merchant.buy_item("healing_potion"), "Purchase succeeds with funds and capacity")
	_expect(GameState.get_currency() == 76, "Purchase spends the listed price")
	_expect(GameState.get_inventory_count("healing_potion") == 1, "Purchase grants the item")
	_expect(int(merchant.stock.get("healing_potion", 0)) == 2, "Purchase reduces limited stock")
	_expect(merchant.sell_item("healing_potion"), "Owned item can be sold")
	_expect(GameState.get_currency() == 86, "Sale grants the listed value")
	_expect(merchant.buyback.size() == 1, "Sold item enters buyback")
	_expect(merchant.buyback_item(0), "Buyback restores the sold item")
	_expect(GameState.get_currency() == 76, "Buyback uses the original sale price")
	GameState.set_inventory_count("healing_potion", original_potions)
	GameState.set_currency(original_currency)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("MARKETPLACE ECONOMY SMOKE TEST PASSED")
	else:
		push_error("MARKETPLACE ECONOMY SMOKE TEST FAILED: " + ", ".join(failures))
