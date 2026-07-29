extends RefCounted
class_name AchievementService

const AchievementCatalogScript = preload(
	"res://scripts/progression/achievement_catalog.gd"
)
const UnlockCatalogScript = preload("res://scripts/systems/unlock_catalog.gd")

const STORAGE_PREFIX: String = "achievement::"
const PERSISTENCE_SCOPE: String = AchievementCatalogScript.PERSISTENCE_SCOPE_SAVE_SLOT


static func get_persistence_scope() -> String:
	return PERSISTENCE_SCOPE


static func get_storage_id(achievement_id: String) -> String:
	if achievement_id == "":
		return ""
	return STORAGE_PREFIX + achievement_id


static func get_achievement_id_from_storage(storage_id: String) -> String:
	if not storage_id.begins_with(STORAGE_PREFIX):
		return ""
	return storage_id.trim_prefix(STORAGE_PREFIX)


static func satisfies_requirement(requirement_id: String) -> bool:
	if requirement_id == "":
		return true
	if AchievementCatalogScript.has_definition(requirement_id):
		return is_unlocked(requirement_id)
	return GameState.has_unlock(requirement_id)


static func unlock(achievement_id: String, evidence: Dictionary = {}) -> Dictionary:
	var definition: Dictionary = AchievementCatalogScript.get_definition(achievement_id)
	if definition.is_empty():
		return {
			"ok": false,
			"achievement_id": achievement_id,
			"newly_unlocked": false,
			"error": "unknown achievement",
		}

	var storage_id: String = get_storage_id(achievement_id)
	if GameState.has_unlock(storage_id):
		return {
			"ok": true,
			"achievement_id": achievement_id,
			"storage_id": storage_id,
			"newly_unlocked": false,
			"row": get_unlocked_row(achievement_id),
		}

	var stored_evidence: Dictionary = evidence.duplicate(true)
	var silent: bool = bool(stored_evidence.get("silent", false))
	stored_evidence.erase("silent")
	definition["achievement_id"] = achievement_id
	definition["storage_id"] = storage_id
	definition["type"] = UnlockCatalogScript.TYPE_ACHIEVEMENT
	definition["persistence_scope"] = PERSISTENCE_SCOPE
	definition["unlocked_at"] = Time.get_datetime_string_from_system(false, true)
	definition["evidence"] = stored_evidence
	GameState.grant_unlock(storage_id, definition)

	if not silent and GameState.has_method("show_system_message"):
		GameState.call(
			"show_system_message",
			"Achievement: " + str(definition.get("display_name", achievement_id))
		)

	return {
		"ok": true,
		"achievement_id": achievement_id,
		"storage_id": storage_id,
		"newly_unlocked": true,
		"row": get_unlocked_row(achievement_id),
	}


static func revoke(achievement_id: String) -> bool:
	var storage_id: String = get_storage_id(achievement_id)
	if storage_id == "" or not GameState.has_unlock(storage_id):
		return false
	GameState.revoke_unlock(storage_id)
	return true


static func is_unlocked(achievement_id: String) -> bool:
	var storage_id: String = get_storage_id(achievement_id)
	return storage_id != "" and GameState.has_unlock(storage_id)


static func get_unlocked_row(achievement_id: String) -> Dictionary:
	var storage_id: String = get_storage_id(achievement_id)
	if storage_id == "":
		return {}
	var unlocks: Dictionary = GameState.get_unlock_snapshot()
	var raw_row: Variant = unlocks.get(storage_id, {})
	if not raw_row is Dictionary:
		return {}
	return (raw_row as Dictionary).duplicate(true)


static func get_unlocked_achievement_ids() -> Array[String]:
	var achievement_ids: Array[String] = []
	for definition: Dictionary in AchievementCatalogScript.get_definitions():
		var achievement_id: String = str(definition.get("id", ""))
		if is_unlocked(achievement_id):
			achievement_ids.append(achievement_id)
	return achievement_ids


static func get_unlocked_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for achievement_id: String in get_unlocked_achievement_ids():
		var row: Dictionary = get_unlocked_row(achievement_id)
		if not row.is_empty():
			rows.append(row)
	rows.sort_custom(_sort_rows)
	return rows


static func get_unlocked_rows_by_source(source_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row: Dictionary in get_unlocked_rows():
		if str(row.get("source_id", "")) == source_id:
			rows.append(row)
	return rows


static func get_summary() -> Dictionary:
	var unlocked_ids: Array[String] = get_unlocked_achievement_ids()
	var total: int = AchievementCatalogScript.get_total_count()
	return {
		"unlocked": unlocked_ids.size(),
		"total": total,
		"remaining": maxi(total - unlocked_ids.size(), 0),
		"fraction": float(unlocked_ids.size()) / float(maxi(total, 1)),
		"persistence_scope": PERSISTENCE_SCOPE,
	}


static func clear_all() -> int:
	var storage_ids: Array[String] = []
	for unlock_id_variant: Variant in GameState.get_unlock_snapshot().keys():
		var storage_id: String = str(unlock_id_variant)
		if storage_id.begins_with(STORAGE_PREFIX):
			storage_ids.append(storage_id)

	for storage_id: String in storage_ids:
		GameState.revoke_unlock(storage_id)
	return storage_ids.size()


static func capture_state() -> Dictionary:
	var snapshot: Dictionary = {}
	var unlocks: Dictionary = GameState.get_unlock_snapshot()
	for unlock_id_variant: Variant in unlocks.keys():
		var storage_id: String = str(unlock_id_variant)
		if not storage_id.begins_with(STORAGE_PREFIX):
			continue
		var raw_row: Variant = unlocks[unlock_id_variant]
		if raw_row is Dictionary:
			snapshot[storage_id] = (raw_row as Dictionary).duplicate(true)
	return snapshot


static func restore_state(snapshot: Dictionary) -> void:
	clear_all()
	for storage_id_variant: Variant in snapshot.keys():
		var storage_id: String = str(storage_id_variant)
		if not storage_id.begins_with(STORAGE_PREFIX):
			continue
		var raw_row: Variant = snapshot[storage_id_variant]
		if not raw_row is Dictionary:
			continue
		GameState.grant_unlock(storage_id, (raw_row as Dictionary).duplicate(true))


static func _sort_rows(a: Dictionary, b: Dictionary) -> bool:
	var order_a: int = int(a.get("sort_index", 0))
	var order_b: int = int(b.get("sort_index", 0))
	if order_a == order_b:
		return str(a.get("achievement_id", "")) < str(b.get("achievement_id", ""))
	return order_a < order_b
