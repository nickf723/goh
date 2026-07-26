extends RefCounted
class_name CombatArenaLoadout

const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")
const UnlockCatalogScript = preload("res://scripts/systems/unlock_catalog.gd")
const WeaponMasteryCatalogScript = preload("res://scripts/weapons/weapon_mastery_catalog.gd")

const RESOURCE_IDS: Array[String] = ["health", "stamina", "mana", "stance"]


static func capture_state() -> Dictionary:
	return {
		"stats": GameState.get_stat_snapshot(),
		"owned_equipment": GameState.get_owned_equipment_snapshot(),
		"equipped_items": GameState.get_equipped_items_snapshot(),
		"weapon_mastery": GameState.get_weapon_mastery_snapshot(),
		"unlocks": GameState.get_unlock_snapshot(),
		"weapon_infusion_id": GameState.get_weapon_infusion(),
	}


static func apply_everything_unlocked() -> Dictionary:
	var equipment_granted: int = 0
	for item_variant: Variant in EquipmentCatalogScript.DEFINITIONS.keys():
		var item_id: String = str(item_variant)
		if GameState.grant_equipment(item_id):
			equipment_granted += 1

	var maximum_mastery: int = WeaponMasteryCatalogScript.RANK_THRESHOLDS.back()
	var mastery_promotions: int = 0
	for weapon_class: String in WeaponMasteryCatalogScript.WEAPON_CLASSES:
		if GameState.get_weapon_mastery_points(weapon_class) < maximum_mastery:
			mastery_promotions += 1
		GameState.set_weapon_mastery_points(weapon_class, maximum_mastery)

	var unlocks_granted: int = 0
	for unlock_variant: Variant in UnlockCatalogScript.UNLOCK_DEFS.keys():
		var unlock_id: String = str(unlock_variant)
		if GameState.has_unlock(unlock_id):
			continue
		GameState.grant_unlock(unlock_id)
		unlocks_granted += 1

	GameState.set_stat("focus", maxi(GameState.get_stat("focus"), 10))
	refill_combat_resources()

	return {
		"equipment_granted": equipment_granted,
		"equipment_total": EquipmentCatalogScript.DEFINITIONS.size(),
		"mastery_promotions": mastery_promotions,
		"mastery_total": WeaponMasteryCatalogScript.WEAPON_CLASSES.size(),
		"mastery_points": maximum_mastery,
		"unlocks_granted": unlocks_granted,
		"unlocks_total": UnlockCatalogScript.UNLOCK_DEFS.size(),
	}


static func refill_combat_resources() -> void:
	for resource_id: String in RESOURCE_IDS:
		var maximum: int = GameState.get_stat("max_" + resource_id)
		if maximum > 0 and GameState.get_stat(resource_id) != maximum:
			GameState.set_stat(resource_id, maximum)


static func restore_state(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return

	var previous_stats: Dictionary = GameState.get_stat_snapshot()
	var previous_equipment: Dictionary = GameState.get_owned_equipment_snapshot()
	var previous_unlocks: Dictionary = GameState.get_unlock_snapshot()

	GameState.stats = (snapshot.get("stats", {}) as Dictionary).duplicate(true)
	GameState.owned_equipment = (snapshot.get("owned_equipment", {}) as Dictionary).duplicate(true)
	GameState.equipped_items = (snapshot.get("equipped_items", {}) as Dictionary).duplicate(true)
	GameState.weapon_mastery = (snapshot.get("weapon_mastery", {}) as Dictionary).duplicate(true)
	GameState.unlocks = (snapshot.get("unlocks", {}) as Dictionary).duplicate(true)
	GameState.weapon_infusion_id = str(snapshot.get("weapon_infusion_id", "none"))

	var stat_ids: Array[String] = _combined_string_keys(previous_stats, GameState.stats)
	for stat_id: String in stat_ids:
		GameState.stat_changed.emit(stat_id, GameState.get_stat(stat_id))

	var equipment_ids: Array[String] = _combined_string_keys(previous_equipment, GameState.owned_equipment)
	for item_id: String in equipment_ids:
		GameState.equipment_owned_changed.emit(item_id, GameState.owns_equipment(item_id))

	for slot_id: String in EquipmentCatalogScript.SLOT_ORDER:
		GameState.equipment_changed.emit(slot_id, GameState.get_equipped_item(slot_id))

	for weapon_class: String in WeaponMasteryCatalogScript.WEAPON_CLASSES:
		var points: int = GameState.get_weapon_mastery_points(weapon_class)
		GameState.weapon_mastery_changed.emit(
			weapon_class,
			points,
			WeaponMasteryCatalogScript.get_rank(points),
			0
		)

	var unlock_ids: Array[String] = _combined_string_keys(previous_unlocks, GameState.unlocks)
	for unlock_id: String in unlock_ids:
		GameState.unlock_changed.emit(unlock_id, GameState.has_unlock(unlock_id))

	GameState.weapon_infusion_changed.emit(GameState.weapon_infusion_id)


static func _combined_string_keys(first: Dictionary, second: Dictionary) -> Array[String]:
	var values: Array[String] = []
	for key_variant: Variant in first.keys():
		var key: String = str(key_variant)
		if not values.has(key):
			values.append(key)
	for key_variant: Variant in second.keys():
		var key: String = str(key_variant)
		if not values.has(key):
			values.append(key)
	values.sort()
	return values
