extends RefCounted
class_name RecordedObjectCatalog

const SELECTED_BLUEPRINT_FLAG: String = "__recorded_objects__::selected_blueprint"

const BLUEPRINT_ORDER: Array[String] = [
	"crate",
	"platform",
	"spring",
	"blast_barrel",
]

const DEFINITIONS: Dictionary = {
	"crate": {
		"id": "crate",
		"item_id": "recorded_crate_blueprint",
		"display_name": "Recorded Crate",
		"short_name": "Crate",
		"icon": "▣",
		"description": "A sturdy reproduced crate that can be pushed, stacked, dropped, or used as temporary footing.",
		"behavior": "crate",
		"body_mode": "dynamic",
		"size": Vector3(1.45, 1.45, 1.45),
		"mass": 5.0,
		"mana_cost": 1,
		"maximum_active": 3,
		"placement_range": 11.0,
		"color": Color(0.66, 0.38, 0.16, 1.0),
		"test_prompt": "Stack it, push it, or use it as a step.",
	},
	"platform": {
		"id": "platform",
		"item_id": "recorded_platform_blueprint",
		"display_name": "Recorded Platform",
		"short_name": "Platform",
		"icon": "▰",
		"description": "A broad stable platform reproduced for bridging gaps, building footing, and redirecting movement.",
		"behavior": "platform",
		"body_mode": "anchored",
		"size": Vector3(3.8, 0.42, 2.2),
		"mass": 12.0,
		"mana_cost": 2,
		"maximum_active": 3,
		"placement_range": 13.0,
		"color": Color(0.28, 0.66, 0.92, 1.0),
		"test_prompt": "Bridge the short trench or build a landing.",
	},
	"spring": {
		"id": "spring",
		"item_id": "recorded_spring_blueprint",
		"display_name": "Recorded Spring",
		"short_name": "Spring",
		"icon": "↟",
		"description": "A compact launch mechanism that converts weight into an upward burst for Grace, creatures, and loose objects.",
		"behavior": "spring",
		"body_mode": "anchored",
		"size": Vector3(1.8, 0.48, 1.8),
		"mass": 10.0,
		"mana_cost": 2,
		"maximum_active": 2,
		"placement_range": 10.0,
		"launch_speed": 10.5,
		"color": Color(0.36, 0.94, 0.5, 1.0),
		"test_prompt": "Launch onto the high shelf.",
	},
	"blast_barrel": {
		"id": "blast_barrel",
		"item_id": "recorded_blast_barrel_blueprint",
		"display_name": "Recorded Blast Barrel",
		"short_name": "Blast Barrel",
		"icon": "✹",
		"description": "A volatile reproduced barrel that detonates when struck by Fire, Heavy force, or another explosion.",
		"behavior": "blast_barrel",
		"body_mode": "dynamic",
		"size": Vector3(1.15, 1.75, 1.15),
		"mass": 4.0,
		"mana_cost": 3,
		"maximum_active": 2,
		"placement_range": 11.0,
		"blast_radius": 5.0,
		"blast_damage": 4,
		"blast_force": 9.0,
		"color": Color(0.96, 0.28, 0.12, 1.0),
		"test_prompt": "Place it beside the target cluster and ignite it.",
	},
}


static func has_blueprint(blueprint_id: String) -> bool:
	return DEFINITIONS.has(blueprint_id)


static func get_definition(blueprint_id: String) -> Dictionary:
	if not has_blueprint(blueprint_id):
		return {}
	return (DEFINITIONS[blueprint_id] as Dictionary).duplicate(true)


static func get_definitions() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for blueprint_id: String in BLUEPRINT_ORDER:
		rows.append(get_definition(blueprint_id))
	return rows


static func get_item_id(blueprint_id: String) -> String:
	return str(get_definition(blueprint_id).get("item_id", ""))


static func get_blueprint_id_for_item(item_id: String) -> String:
	for blueprint_id: String in BLUEPRINT_ORDER:
		if get_item_id(blueprint_id) == item_id:
			return blueprint_id
	return ""


static func is_recorded(blueprint_id: String) -> bool:
	var item_id: String = get_item_id(blueprint_id)
	return item_id != "" and GameState.get_inventory_count(item_id) > 0


static func record_blueprint(blueprint_id: String) -> Dictionary:
	var definition: Dictionary = get_definition(blueprint_id)
	if definition.is_empty():
		return {"ok": false, "newly_recorded": false, "error": "unknown blueprint"}
	var item_id: String = str(definition.get("item_id", ""))
	var newly_recorded: bool = not is_recorded(blueprint_id)
	if newly_recorded:
		GameState.add_inventory_item(item_id, 1)
		_record_journal_discovery(blueprint_id, definition)
	if get_selected_blueprint_id() == "":
		select_blueprint(blueprint_id)
	return {
		"ok": true,
		"newly_recorded": newly_recorded,
		"blueprint_id": blueprint_id,
		"item_id": item_id,
		"definition": definition,
	}


static func select_blueprint(blueprint_id: String) -> bool:
	if not has_blueprint(blueprint_id) or not is_recorded(blueprint_id):
		return false
	GameState.story_flags[SELECTED_BLUEPRINT_FLAG] = blueprint_id
	return true


static func get_selected_blueprint_id() -> String:
	var selected: String = str(GameState.story_flags.get(SELECTED_BLUEPRINT_FLAG, ""))
	if selected != "" and is_recorded(selected):
		return selected
	for blueprint_id: String in BLUEPRINT_ORDER:
		if is_recorded(blueprint_id):
			return blueprint_id
	return ""


static func get_recorded_blueprint_ids() -> Array[String]:
	var ids: Array[String] = []
	for blueprint_id: String in BLUEPRINT_ORDER:
		if is_recorded(blueprint_id):
			ids.append(blueprint_id)
	return ids


static func get_recorded_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for blueprint_id: String in BLUEPRINT_ORDER:
		var definition: Dictionary = get_definition(blueprint_id)
		definition["recorded"] = is_recorded(blueprint_id)
		definition["selected"] = blueprint_id == get_selected_blueprint_id()
		rows.append(definition)
	return rows


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	var seen_items: Dictionary = {}
	for blueprint_id: String in BLUEPRINT_ORDER:
		var definition: Dictionary = get_definition(blueprint_id)
		if definition.is_empty():
			failures.append("missing blueprint: " + blueprint_id)
			continue
		var item_id: String = str(definition.get("item_id", ""))
		if item_id == "":
			failures.append(blueprint_id + " has no inventory item")
		elif seen_items.has(item_id):
			failures.append("duplicate blueprint item: " + item_id)
		seen_items[item_id] = true
		var size_value: Variant = definition.get("size", Vector3.ZERO)
		if not size_value is Vector3 or (size_value as Vector3).length() <= 0.1:
			failures.append(blueprint_id + " has invalid dimensions")
		if int(definition.get("mana_cost", 0)) < 0:
			failures.append(blueprint_id + " has a negative mana cost")
		if int(definition.get("maximum_active", 0)) <= 0:
			failures.append(blueprint_id + " needs an active-object limit")
	return failures


static func _record_journal_discovery(
	blueprint_id: String,
	definition: Dictionary
) -> void:
	var tracker: Node = Engine.get_main_loop().root.get_node_or_null(
		"FullMenuDirector/ProgressionTracker"
	)
	if tracker != null and tracker.has_method("record_discovery"):
		tracker.call(
			"record_discovery",
			"blueprint",
			blueprint_id,
			{
				"source": "recorded_object",
				"display_name": str(definition.get("display_name", blueprint_id.capitalize())),
			}
		)
