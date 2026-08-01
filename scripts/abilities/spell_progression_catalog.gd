extends RefCounted
class_name SpellProgressionCatalog

const UPGRADE_BRANCHES: Array[String] = ["potency", "efficiency", "expression"]


static func get_spell_id(spell: Dictionary) -> String:
	var spell_id: String = str(spell.get("spell_id", "")).strip_edges()
	if spell_id != "":
		return spell_id
	return str(spell.get("name", "spell")).to_lower().replace(" ", "_")


static func get_property_rows(spell: Dictionary) -> Array[Dictionary]:
	return [
		{
			"id": "behavior",
			"name": "Behavior",
			"value": _short_list(spell.get("roles", []), "Utility"),
			"description": "The spell's authored jobs and combat roles.",
		},
		{
			"id": "delivery",
			"name": "Delivery",
			"value": str(spell.get("delivery", "unknown")).replace("_", " ").capitalize(),
			"description": "How the spell enters the world before reaching its target.",
		},
		{
			"id": "targeting",
			"name": "Targeting",
			"value": str(spell.get("targeting", "unknown")).replace("_", " ").capitalize(),
			"description": "How Grace chooses the spell's target or placement.",
		},
		{
			"id": "scaling",
			"name": "Scaling",
			"value": _short_list(spell.get("scaling_stats", []), "Unassigned"),
			"description": str(spell.get("scaling_note", "Prototype scaling identity.")),
		},
	]


static func get_upgrade_rows(spell: Dictionary) -> Array[Dictionary]:
	var spell_id: String = get_spell_id(spell)
	var element: String = str(spell.get("element", "neutral")).capitalize()
	var category: String = str(spell.get("category", "Spell"))
	return [
		{
			"id": spell_id + ".potency",
			"branch": "potency",
			"name": "Potency",
			"rank": 0,
			"rank_max": 3,
			"description": "Increase payload strength, status buildup, or summon authority while preserving the spell's identity.",
			"unlock_hint": "Raise proficiency and complete a " + element + " challenge.",
		},
		{
			"id": spell_id + ".efficiency",
			"branch": "efficiency",
			"name": "Efficiency",
			"rank": 0,
			"rank_max": 3,
			"description": "Reduce resource cost, recovery, concentration pressure, or setup time.",
			"unlock_hint": "Cast the spell successfully without exhausting its primary resource.",
		},
		{
			"id": spell_id + ".expression",
			"branch": "expression",
			"name": "Expression",
			"rank": 0,
			"rank_max": 3,
			"description": "Unlock alternate shapes, behaviors, or contextual techniques for this " + category.to_lower() + ".",
			"unlock_hint": "Use the spell in multiple roles, targets, and reaction contexts.",
		},
	]


static func get_proficiency_guide(spell: Dictionary) -> Dictionary:
	var spell_id: String = get_spell_id(spell)
	var element: String = str(spell.get("element", "neutral"))
	var roles: Array[String] = _string_array(spell.get("roles", []))
	var methods: Array[String] = [
		"Cast the spell successfully in a live encounter.",
		"Trigger a useful " + element.capitalize() + " reaction or environmental interaction.",
	]
	if roles.has("damage"):
		methods.append("Damage or defeat a target with the spell's intended delivery.")
	if roles.has("control") or roles.has("status"):
		methods.append("Apply control or status long enough for Grace or an ally to capitalize.")
	if roles.has("movement") or roles.has("traversal"):
		methods.append("Use the spell to cross a meaningful obstacle or evade danger.")
	if roles.has("summon") or spell_id == "spectral_familiar":
		methods.append("Complete encounters with the familiar active and issue distinct commands.")
		methods.append("Discover new creature behavior that expands the familiar blueprint.")
	if roles.has("detection"):
		methods.append("Reveal a hidden object, route, enemy, or property.")
	return {
		"spell_id": spell_id,
		"rank": 0,
		"rank_name": "Unpracticed",
		"points": 0,
		"next_rank_points": 10,
		"methods": methods,
		"runtime_tracking": false,
	}


static func get_combo_summary(spell: Dictionary) -> String:
	var parts: Array[String] = []
	var combo_tags: Array[String] = _string_array(spell.get("combo_tags", []))
	var status_tags: Array[String] = _string_array(spell.get("status_tags", []))
	if not combo_tags.is_empty():
		parts.append("Combo: " + ", ".join(combo_tags))
	if not status_tags.is_empty():
		parts.append("Status: " + ", ".join(status_tags))
	return "\n".join(parts) if not parts.is_empty() else "No authored combo or status tags yet."


static func _short_list(value: Variant, fallback: String) -> String:
	var values: Array[String] = _string_array(value)
	if values.is_empty():
		return fallback
	var display_values: Array[String] = []
	for item: String in values:
		display_values.append(item.replace("_", " ").capitalize())
	return ", ".join(display_values.slice(0, mini(display_values.size(), 3)))


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw)
			if text != "":
				result.append(text)
	return result
