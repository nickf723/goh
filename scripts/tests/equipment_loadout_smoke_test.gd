extends Node

var failures: Array[String] = []


func _ready() -> void:
	var original_stats: Dictionary = GameState.get_stat_snapshot()
	var original_owned: Dictionary = GameState.get_owned_equipment_snapshot()
	var original_slots: Dictionary = GameState.get_equipped_items_snapshot()
	var original_currency: int = GameState.get_currency()
	GameState.reset_stats_to_defaults(false)
	GameState.reset_equipment_to_defaults(false, false)
	_expect(GameState.grant_equipment("training_hammer"), "New weapon ownership can be granted")
	_expect(GameState.equip_item("training_hammer"), "Owned weapon can be equipped")
	_expect(GameState.get_equipped_item("weapon") == "training_hammer", "Weapon slot persists the equipment id")
	_expect(GameState.get_stat("power") == 2, "Hammer applies its Power modifier")
	_expect(GameState.grant_equipment("travelers_coat"), "Outfit ownership can be granted")
	_expect(GameState.equip_item("travelers_coat"), "Owned outfit can be equipped")
	_expect(GameState.get_stat("max_stamina") == 7, "Traveler's Coat raises maximum Stamina")
	_expect(GameState.grant_equipment("apprentice_robe"), "Replacement outfit can be granted")
	_expect(GameState.equip_item("apprentice_robe"), "Replacement outfit equips")
	_expect(GameState.get_stat("max_stamina") == 5, "Replacing gear removes the old modifier")
	_expect(GameState.get_stat("max_mana") == 7, "Replacing gear applies the new modifier")
	_expect(not GameState.revoke_equipment("apprentice_robe"), "Equipped gear cannot be removed or sold")
	GameState.set_currency(100)
	var outfitter := EquipmentOutfitter.new()
	add_child(outfitter)
	await get_tree().process_frame
	_expect(outfitter.buy_equipment("lucky_shard"), "Equipment shop purchase succeeds")
	_expect(GameState.get_currency() == 52, "Equipment purchase spends its listed price")
	_expect(outfitter.sell_equipment("lucky_shard"), "Unequipped gear can be sold")
	_expect(GameState.get_currency() == 74, "Equipment sale grants its listed value")
	for stat_variant: Variant in original_stats.keys():
		GameState.set_stat(str(stat_variant), int(original_stats[stat_variant]))
	GameState.apply_saved_equipment({"equipment": {"owned": original_owned, "slots": original_slots}})
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
		print("EQUIPMENT LOADOUT SMOKE TEST PASSED")
	else:
		push_error("EQUIPMENT LOADOUT SMOKE TEST FAILED: " + ", ".join(failures))
