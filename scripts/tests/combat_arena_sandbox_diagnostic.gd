extends Node

const CombatArenaLoadoutScript = preload("res://scripts/systems/combat_arena_loadout.gd")
const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")
const UnlockCatalogScript = preload("res://scripts/systems/unlock_catalog.gd")
const WeaponMasteryCatalogScript = preload("res://scripts/weapons/weapon_mastery_catalog.gd")


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if not args.is_empty() else "apply"
	var failures: Array[String] = []
	if mode == "restore":
		validate_restore(failures)
	else:
		validate_apply(failures)

	if failures.is_empty():
		print("COMBAT_ARENA_SANDBOX_DIAGNOSTIC_" + mode.to_upper() + ": PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("COMBAT_ARENA_SANDBOX_DIAGNOSTIC_" + mode.to_upper() + ": " + failure)
	get_tree().quit(1)


func validate_apply(failures: Array[String]) -> void:
	var result: Dictionary = CombatArenaLoadoutScript.apply_everything_unlocked()
	var maximum_mastery: int = WeaponMasteryCatalogScript.RANK_THRESHOLDS.back()
	if int(result.get("mastery_total", 0)) != WeaponMasteryCatalogScript.WEAPON_CLASSES.size():
		failures.append("mastery total")
	if int(result.get("equipment_total", 0)) != EquipmentCatalogScript.DEFINITIONS.size():
		failures.append("equipment total")
	if int(result.get("unlocks_total", 0)) != UnlockCatalogScript.UNLOCK_DEFS.size():
		failures.append("unlock total")
	for weapon_class: String in WeaponMasteryCatalogScript.WEAPON_CLASSES:
		if GameState.get_weapon_mastery_points(weapon_class) != maximum_mastery:
			failures.append("mastery " + weapon_class)
	for item_variant: Variant in EquipmentCatalogScript.DEFINITIONS.keys():
		if not GameState.owns_equipment(str(item_variant)):
			failures.append("equipment " + str(item_variant))
	for unlock_variant: Variant in UnlockCatalogScript.UNLOCK_DEFS.keys():
		if not GameState.has_unlock(str(unlock_variant)):
			failures.append("unlock " + str(unlock_variant))
	for resource_id: String in CombatArenaLoadoutScript.RESOURCE_IDS:
		if GameState.get_stat(resource_id) != GameState.get_stat("max_" + resource_id):
			failures.append("resource " + resource_id)


func validate_restore(failures: Array[String]) -> void:
	var before: Dictionary = CombatArenaLoadoutScript.capture_state()
	CombatArenaLoadoutScript.apply_everything_unlocked()
	CombatArenaLoadoutScript.restore_state(before)
	if GameState.get_stat_snapshot() != before.get("stats", {}):
		failures.append("stats")
	if GameState.get_owned_equipment_snapshot() != before.get("owned_equipment", {}):
		failures.append("owned equipment")
	if GameState.get_equipped_items_snapshot() != before.get("equipped_items", {}):
		failures.append("equipped items")
	if GameState.get_weapon_mastery_snapshot() != before.get("weapon_mastery", {}):
		failures.append("weapon mastery")
	if GameState.get_unlock_snapshot() != before.get("unlocks", {}):
		failures.append("unlocks")
	if GameState.get_weapon_infusion() != str(before.get("weapon_infusion_id", "none")):
		failures.append("weapon infusion")
