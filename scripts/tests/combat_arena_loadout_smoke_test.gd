extends Node

const CombatArenaLoadoutScript = preload("res://scripts/systems/combat_arena_loadout.gd")
const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")
const UnlockCatalogScript = preload("res://scripts/systems/unlock_catalog.gd")
const WeaponMasteryCatalogScript = preload("res://scripts/weapons/weapon_mastery_catalog.gd")


func _ready() -> void:
	var before: Dictionary = CombatArenaLoadoutScript.capture_state()
	var result: Dictionary = CombatArenaLoadoutScript.apply_everything_unlocked()

	assert(int(result.get("mastery_total", 0)) == WeaponMasteryCatalogScript.WEAPON_CLASSES.size())
	assert(int(result.get("equipment_total", 0)) == EquipmentCatalogScript.DEFINITIONS.size())
	assert(int(result.get("unlocks_total", 0)) == UnlockCatalogScript.UNLOCK_DEFS.size())

	var maximum_mastery: int = WeaponMasteryCatalogScript.RANK_THRESHOLDS.back()
	for weapon_class: String in WeaponMasteryCatalogScript.WEAPON_CLASSES:
		assert(GameState.get_weapon_mastery_points(weapon_class) == maximum_mastery)
		assert(GameState.get_weapon_mastery_rank(weapon_class) == WeaponMasteryCatalogScript.RANK_NAMES.size() - 1)

	for item_variant: Variant in EquipmentCatalogScript.DEFINITIONS.keys():
		assert(GameState.owns_equipment(str(item_variant)))

	for unlock_variant: Variant in UnlockCatalogScript.UNLOCK_DEFS.keys():
		assert(GameState.has_unlock(str(unlock_variant)))

	for resource_id: String in CombatArenaLoadoutScript.RESOURCE_IDS:
		assert(GameState.get_stat(resource_id) == GameState.get_stat("max_" + resource_id))
	assert(GameState.get_stat("focus") >= 10)

	CombatArenaLoadoutScript.restore_state(before)
	assert(GameState.get_stat_snapshot() == before.get("stats", {}))
	assert(GameState.get_owned_equipment_snapshot() == before.get("owned_equipment", {}))
	assert(GameState.get_equipped_items_snapshot() == before.get("equipped_items", {}))
	assert(GameState.get_weapon_mastery_snapshot() == before.get("weapon_mastery", {}))
	assert(GameState.get_unlock_snapshot() == before.get("unlocks", {}))
	assert(GameState.get_weapon_infusion() == str(before.get("weapon_infusion_id", "none")))

	print("Combat arena loadout smoke test passed: full sandbox applied and entry progression restored.")
