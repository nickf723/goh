extends RefCounted
class_name QuestRewardBundle

var rewards: Dictionary


func _init(reward_definition: Dictionary = {}) -> void:
	rewards = reward_definition.duplicate(true)


func apply() -> Dictionary:
	var granted: Dictionary = {
		"key_items": [],
		"inventory": [],
		"mastery": {},
		"flags": [],
	}

	for item_variant: Variant in rewards.get("key_items", []):
		if not item_variant is Dictionary:
			continue
		var item: Dictionary = item_variant
		var item_id: String = str(item.get("id", ""))
		if item_id.is_empty():
			continue
		var data: Dictionary = (item.get("data", {}) as Dictionary).duplicate(true)
		GameState.add_key_item(item_id, data)
		(granted["key_items"] as Array).append(item_id)

	for item_variant: Variant in rewards.get("inventory", []):
		if not item_variant is Dictionary:
			continue
		var item: Dictionary = item_variant
		var item_id: String = str(item.get("id", ""))
		var count: int = maxi(int(item.get("count", 1)), 1)
		if item_id.is_empty():
			continue
		GameState.add_inventory_item(item_id, count)
		(granted["inventory"] as Array).append({"id": item_id, "count": count})

	var mastery: Dictionary = rewards.get("mastery", {})
	for weapon_variant: Variant in mastery.keys():
		var weapon_class: String = str(weapon_variant)
		var points: int = int(mastery[weapon_variant])
		GameState.set_weapon_mastery_points(
			weapon_class,
			GameState.get_weapon_mastery_points(weapon_class) + points
		)
		(granted["mastery"] as Dictionary)[weapon_class] = points

	for flag_variant: Variant in rewards.get("flags", []):
		var flag_id: String = str(flag_variant)
		if flag_id.is_empty():
			continue
		GameState.set_flag(flag_id, true)
		(granted["flags"] as Array).append(flag_id)

	return granted
