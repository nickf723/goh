extends Node

const CombatArenaLoadoutScript = preload("res://scripts/systems/combat_arena_loadout.gd")
const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")
const UnlockCatalogScript = preload("res://scripts/systems/unlock_catalog.gd")
const WeaponMasteryCatalogScript = preload("res://scripts/weapons/weapon_mastery_catalog.gd")

var failures: Array[String] = []


func _ready() -> void:
	var before: Dictionary = CombatArenaLoadoutScript.capture_state()
	validate_sandbox()
	CombatArenaLoadoutScript.restore_state(before)
	validate_restoration(before)

	if failures.is_empty():
		print("COMBAT_ARENA_LOADOUT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("COMBAT_ARENA_LOADOUT_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func validate_sandbox() -> void:
	var result: Dictionary = CombatArenaLoadoutScript.apply_everything_unlocked()
	var maximum_mastery: int = WeaponMasteryCatalogScript.RANK_THRESHOLDS.back()

	if int(result.get("mastery_total", 0)) != WeaponMasteryCatalogScript.WEAPON_CLASSES.size():
		failures.append("did not report every weapon class")
	if int(result.get("equipment_total", 0)) != EquipmentCatalogScript.DEFINITIONS.size():
		failures.append("did not report every equipment definition")
	if int(result.get("unlocks_total", 0)) != UnlockCatalogScript.UNLOCK_DEFS.size():
		failures.append("did not report every catalog unlock")

	for weapon_class: String in WeaponMasteryCatalogScript.WEAPON_CLASSES:
		if GameState.get_weapon_mastery_points(weapon_class) != maximum_mastery:
			failures.append("did not master " + weapon_class)

	for item_variant: Variant in EquipmentCatalogScript.DEFINITIONS.keys():
		var item_id: String = str(item_variant)
		if not GameState.owns_equipment(item_id):
			failures.append("did not grant equipment " + item_id)

	for unlock_variant: Variant in UnlockCatalogScript.UNLOCK_DEFS.keys():
		var unlock_id: String = str(unlock_variant)
		if not GameState.has_unlock(unlock_id):
			failures.append("did not grant unlock " + unlock_id)

	for resource_id: String in CombatArenaLoadoutScript.RESOURCE_IDS:
		if GameState.get_stat(resource_id) != GameState.get_stat("max_" + resource_id):
			failures.append("did not refill " + resource_id)

	if GameState.get_stat("focus") < 10:
		failures.append("did not provide the arena Focus floor")


func validate_restoration(before: Dictionary) -> void:
	if GameState.get_stat_snapshot() != before.get("stats", {}):
		failures.append("did not restore stats")
	if GameState.get_owned_equipment_snapshot() != before.get("owned_equipment", {}):
		failures.append("did not restore owned equipment")
	if GameState.get_equipped_items_snapshot() != before.get("equipped_items", {}):
		failures.append("did not restore equipped items")
	if GameState.get_weapon_mastery_snapshot() != before.get("weapon_mastery", {}):
		failures.append("did not restore weapon mastery")
	if GameState.get_unlock_snapshot() != before.get("unlocks", {}):
		failures.append("did not restore unlocks")
	if GameState.get_weapon_infusion() != str(before.get("weapon_infusion_id", "none")):
		failures.append("did not restore weapon infusion")
