extends RefCounted
class_name RouteFamiliarityPlanner

const RegionalStoreScript = preload("res://scripts/expedition/regional_expedition_store.gd")

const SEGMENT_CATALOG: Array[Dictionary] = [
	{"source_index": 0, "segment_id": "cypress_basin", "display_name": "Flooded Cypress Basin", "biome": "Cypress wetland", "role": "traversal"},
	{"source_index": 1, "segment_id": "wet_woodland", "display_name": "Wet Woodland Fork", "biome": "Wet woodland", "role": "discovery"},
	{"source_index": 2, "segment_id": "pine_ridge", "display_name": "Longleaf Pine Ridge", "biome": "Pine ridge", "role": "resource"},
	{"source_index": 3, "segment_id": "rocky_foothills", "display_name": "Rocky Foothill Camp", "biome": "Rocky foothills", "role": "combat"},
	{"source_index": 4, "segment_id": "mountain_forest", "display_name": "Blue Ridge Mountain Forest", "biome": "Mountain forest", "role": "rest"},
]


static func build_plan(
	route_id: String,
	state_name: String,
	seed_value: int,
	origin_node_id: String,
	destination_node_id: String
) -> Dictionary:
	var typed_source_indices: Array[int] = get_route_source_indices(route_id, state_name)
	var source_indices: Array = []
	for source_index: int in typed_source_indices:
		source_indices.append(source_index)
	var modifiers: Dictionary = get_familiarity_modifiers(state_name)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var entries: Array = []
	var exact_preview: bool = RegionalStoreScript.get_state_rank(state_name) >= RegionalStoreScript.get_state_rank(RegionalStoreScript.STATE_MAPPED)
	var crossed_preview: bool = RegionalStoreScript.get_state_rank(state_name) >= RegionalStoreScript.get_state_rank(RegionalStoreScript.STATE_CROSSED)
	var rest_cache_order: int = -1
	if bool(modifiers.get("guaranteed_rest_cache", false)) and not route_contains_role(source_indices, "rest"):
		rest_cache_order = maxi(source_indices.size() / 2, 0)

	for order: int in range(source_indices.size()):
		var source_index: int = int(source_indices[order])
		var catalog_entry: Dictionary = get_catalog_entry(source_index)
		var entry_modifiers: Dictionary = modifiers.duplicate(true)
		entry_modifiers["segment_order"] = order
		entry_modifiers["segment_count"] = source_indices.size()
		entry_modifiers["add_rest_cache"] = order == rest_cache_order
		entry_modifiers["show_route_markers"] = exact_preview
		entry_modifiers["stabilized_shortcut"] = state_name == RegionalStoreScript.STATE_STABILIZED
		var preview_role: String = "Unknown conditions"
		if exact_preview:
			preview_role = str(catalog_entry.get("role", "passage")).capitalize()
		elif crossed_preview:
			preview_role = "Known " + str(catalog_entry.get("role", "passage")).capitalize()
		entries.append({
			"source_index": source_index,
			"segment_id": str(catalog_entry.get("segment_id", "missing")),
			"display_name": str(catalog_entry.get("display_name", "Wilds Segment")),
			"biome": str(catalog_entry.get("biome", "Wilds")),
			"role": str(catalog_entry.get("role", "passage")),
			"preview_role": preview_role,
			"seed": int(rng.randi()),
			"turn_degrees": choose_turn_degrees(rng, order, source_indices.size()),
			"modifiers": entry_modifiers,
		})

	return {
		"route_id": route_id,
		"state": state_name,
		"seed": seed_value,
		"origin_node_id": origin_node_id,
		"destination_node_id": destination_node_id,
		"source_indices": source_indices,
		"entries": entries,
		"modifiers": modifiers,
		"danger": get_danger_label(state_name),
		"length_label": get_length_label(entries.size(), state_name),
		"signature": build_signature(route_id, state_name, seed_value, entries),
	}


static func get_route_source_indices(route_id: String, state_name: String) -> Array[int]:
	var stabilized: bool = state_name == RegionalStoreScript.STATE_STABILIZED
	match route_id:
		RegionalStoreScript.ROUTE_CYPRESS_CAIRN:
			return [1] if stabilized else [0, 1]
		RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE:
			return [2, 4] if stabilized else [2, 3, 4]
		_:
			return [0, 2, 4] if stabilized else [0, 1, 2, 3, 4]


static func get_familiarity_modifiers(state_name: String) -> Dictionary:
	match state_name:
		RegionalStoreScript.STATE_CROSSED:
			return {"threat_multiplier": 0.82, "obstacle_multiplier": 0.92, "resource_multiplier": 1.0, "guaranteed_rest_cache": true}
		RegionalStoreScript.STATE_MAPPED:
			return {"threat_multiplier": 0.62, "obstacle_multiplier": 0.72, "resource_multiplier": 1.18, "guaranteed_rest_cache": true}
		RegionalStoreScript.STATE_STABILIZED:
			return {"threat_multiplier": 0.25, "obstacle_multiplier": 0.42, "resource_multiplier": 1.3, "guaranteed_rest_cache": true}
		_:
			return {"threat_multiplier": 1.0, "obstacle_multiplier": 1.12, "resource_multiplier": 0.85, "guaranteed_rest_cache": false}


static func build_preview_text(plan: Dictionary) -> String:
	var entries_value: Variant = plan.get("entries", [])
	if not entries_value is Array:
		return "No expedition preview is available."
	var entries: Array = entries_value as Array
	var lines: Array[String] = []
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value as Dictionary
		lines.append(str(entry.get("biome", "Wilds")) + "  •  " + str(entry.get("preview_role", "Unknown conditions")))
	var header: String = "PREVIEW  •  " + str(plan.get("length_label", "Unknown length")) + "  •  " + str(plan.get("danger", "Unknown danger"))
	return header + "\n" + "\n".join(lines)


static func get_catalog_entry(source_index: int) -> Dictionary:
	for entry: Dictionary in SEGMENT_CATALOG:
		if int(entry.get("source_index", -1)) == source_index:
			return entry
	return {}


static func route_contains_role(source_indices: Array, role_name: String) -> bool:
	for source_index_value: Variant in source_indices:
		if str(get_catalog_entry(int(source_index_value)).get("role", "")) == role_name:
			return true
	return false


static func choose_turn_degrees(rng: RandomNumberGenerator, order: int, count: int) -> float:
	if order <= 0 or order >= count - 1:
		return 0.0
	var choices: Array[float] = [-10.0, -5.0, 0.0, 5.0, 10.0]
	return choices[rng.randi_range(0, choices.size() - 1)]


static func get_danger_label(state_name: String) -> String:
	match state_name:
		RegionalStoreScript.STATE_CROSSED:
			return "Guarded"
		RegionalStoreScript.STATE_MAPPED:
			return "Manageable"
		RegionalStoreScript.STATE_STABILIZED:
			return "Low danger"
		_:
			return "Uncertain"


static func get_length_label(segment_count: int, state_name: String) -> String:
	var label: String = str(segment_count) + (" segment" if segment_count == 1 else " segments")
	if state_name == RegionalStoreScript.STATE_STABILIZED:
		label += " via shortcut"
	return label


static func build_signature(route_id: String, state_name: String, seed_value: int, entries: Array) -> String:
	var parts: Array[String] = [route_id, state_name, str(seed_value)]
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value as Dictionary
		parts.append(str(entry.get("segment_id", "missing")) + ":" + str(entry.get("seed", 0)) + ":" + str(entry.get("turn_degrees", 0.0)))
	return "|".join(parts)
