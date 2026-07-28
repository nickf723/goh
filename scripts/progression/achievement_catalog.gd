extends RefCounted
class_name AchievementCatalog

const SpellcastingTraditionCatalogScript = preload("res://scripts/progression/spellcasting_tradition_catalog.gd")


static func has_definition(achievement_id: String) -> bool:
	return not get_definition(achievement_id).is_empty()


static func get_definition(achievement_id: String) -> Dictionary:
	if achievement_id == "":
		return {}
	for definition: Dictionary in SpellcastingTraditionCatalogScript.get_achievement_definitions():
		if str(definition.get("id", "")) == achievement_id:
			return definition.duplicate(true)
	return {}


static func get_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for definition: Dictionary in SpellcastingTraditionCatalogScript.get_achievement_definitions():
		definitions.append(definition.duplicate(true))
	definitions.sort_custom(_sort_definitions)
	return definitions


static func get_definitions_by_source(source_id: String) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for definition: Dictionary in get_definitions():
		if str(definition.get("source_id", "")) == source_id:
			definitions.append(definition)
	return definitions


static func validate_catalog() -> Array[String]:
	var errors: Array[String] = SpellcastingTraditionCatalogScript.validate_catalog()
	var seen_ids: Dictionary = {}

	for definition: Dictionary in get_definitions():
		var achievement_id: String = str(definition.get("id", ""))
		if achievement_id == "":
			errors.append("achievement catalog contains an empty id")
			continue
		if seen_ids.has(achievement_id):
			errors.append("duplicate achievement id: " + achievement_id)
		seen_ids[achievement_id] = true
		if str(definition.get("display_name", "")).strip_edges() == "":
			errors.append(achievement_id + " has no display name")
		if str(definition.get("description", "")).strip_edges() == "":
			errors.append(achievement_id + " has no description")
		if str(definition.get("type", "")) != "achievement":
			errors.append(achievement_id + " must use achievement type")
		if not definition.get("tags", null) is Array:
			errors.append(achievement_id + " tags must be an Array")

	return errors


static func _sort_definitions(a: Dictionary, b: Dictionary) -> bool:
	var order_a: int = int(a.get("sort_index", 0))
	var order_b: int = int(b.get("sort_index", 0))
	if order_a == order_b:
		return str(a.get("id", "")) < str(b.get("id", ""))
	return order_a < order_b