extends RefCounted
class_name EngineeringPartCatalog

const SELECTED_PART_FLAG: String = "__artificer__::selected_part"
const UNLOCK_PREFIX: String = "__artificer__::part::"

const PART_ORDER: Array[String] = [
	"frame_block",
	"beam",
	"plate",
	"wheel",
	"spring_unit",
	"blast_core",
	"float_pontoon",
	"conductor_rail",
]

const DEFINITIONS: Dictionary = {
	"frame_block": {
		"id": "frame_block",
		"display_name": "Frame Block",
		"icon": "■",
		"description": "A dense structural anchor used to brace a contraption or carry heavier parts.",
		"shape": "box",
		"size": Vector3(1.5, 1.5, 1.5),
		"mass": 4.0,
		"mana_cost": 1,
		"color": Color(0.46, 0.31, 0.18, 1.0),
		"tags": ["structural", "anchor"],
	},
	"beam": {
		"id": "beam",
		"display_name": "Brace Beam",
		"icon": "━",
		"description": "A long lightweight brace for axles, rails, frames, and improvised levers.",
		"shape": "box",
		"size": Vector3(3.0, 0.4, 0.4),
		"mass": 2.0,
		"mana_cost": 1,
		"color": Color(0.32, 0.55, 0.66, 1.0),
		"tags": ["structural", "brace"],
	},
	"plate": {
		"id": "plate",
		"display_name": "Deck Plate",
		"icon": "▰",
		"description": "A broad load-bearing surface for bridges, rafts, carts, and launch decks.",
		"shape": "box",
		"size": Vector3(3.0, 0.3, 2.0),
		"mass": 4.0,
		"mana_cost": 2,
		"color": Color(0.24, 0.62, 0.86, 1.0),
		"tags": ["structural", "deck"],
	},
	"wheel": {
		"id": "wheel",
		"display_name": "Artificer Wheel",
		"icon": "◉",
		"description": "A low-friction wheel pattern. Two or more wheels make a finalized contraption mobile.",
		"shape": "cylinder",
		"size": Vector3(1.1, 0.38, 1.1),
		"mass": 1.0,
		"mana_cost": 1,
		"color": Color(0.13, 0.14, 0.16, 1.0),
		"tags": ["mobility", "wheel"],
	},
	"spring_unit": {
		"id": "spring_unit",
		"display_name": "Spring Unit",
		"icon": "↟",
		"description": "A launch mechanism that throws bodies upward and accepts Lightning overcharge.",
		"shape": "box",
		"size": Vector3(1.4, 0.6, 1.4),
		"mass": 3.0,
		"mana_cost": 2,
		"color": Color(0.42, 0.95, 0.58, 1.0),
		"tags": ["mechanism", "spring", "conductive"],
		"launch_speed": 13.0,
	},
	"blast_core": {
		"id": "blast_core",
		"display_name": "Blast Core",
		"icon": "✹",
		"description": "A volatile artificer charge triggered by Fire, Lightning, heavy Force, or another explosion.",
		"shape": "cylinder",
		"size": Vector3(1.2, 1.4, 1.2),
		"mass": 3.0,
		"mana_cost": 3,
		"color": Color(0.95, 0.3, 0.12, 1.0),
		"tags": ["mechanism", "blast", "volatile"],
		"blast_radius": 5.5,
		"blast_damage": 5,
		"blast_force": 10.0,
	},
	"float_pontoon": {
		"id": "float_pontoon",
		"display_name": "Float Pontoon",
		"icon": "≈",
		"description": "A buoyant sealed body that allows a contraption to ride fluid surfaces and currents.",
		"shape": "box",
		"size": Vector3(1.2, 0.8, 2.8),
		"mass": 2.0,
		"mana_cost": 2,
		"color": Color(0.48, 0.32, 0.17, 1.0),
		"tags": ["mobility", "float"],
		"buoyancy": 0.78,
	},
	"conductor_rail": {
		"id": "conductor_rail",
		"display_name": "Conductor Rail",
		"icon": "ϟ",
		"description": "A conductive strip that lets Lightning energize the finalized contraption's contact field.",
		"shape": "box",
		"size": Vector3(3.0, 0.16, 0.25),
		"mass": 1.0,
		"mana_cost": 1,
		"color": Color(0.72, 0.9, 1.0, 1.0),
		"tags": ["mechanism", "conductive"],
	},
}


static func has_part(part_id: String) -> bool:
	return DEFINITIONS.has(part_id)


static func get_definition(part_id: String) -> Dictionary:
	if not has_part(part_id):
		return {}
	return (DEFINITIONS[part_id] as Dictionary).duplicate(true)


static func get_definitions() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for part_id: String in PART_ORDER:
		rows.append(get_definition(part_id))
	return rows


static func unlock_part(part_id: String) -> bool:
	if not has_part(part_id):
		return false
	GameState.story_flags[UNLOCK_PREFIX + part_id] = true
	if get_selected_part_id() == "":
		select_part(part_id)
	return true


static func unlock_all_for_debug() -> void:
	for part_id: String in PART_ORDER:
		unlock_part(part_id)
	if get_selected_part_id() == "":
		select_part(PART_ORDER[0])


static func ensure_prototype_baseline() -> void:
	if OS.is_debug_build():
		unlock_all_for_debug()
		return
	for part_id: String in ["frame_block", "beam", "plate"]:
		unlock_part(part_id)


static func is_unlocked(part_id: String) -> bool:
	return (
		has_part(part_id)
		and bool(GameState.story_flags.get(UNLOCK_PREFIX + part_id, false))
	)


static func get_unlocked_part_ids() -> Array[String]:
	var ids: Array[String] = []
	for part_id: String in PART_ORDER:
		if is_unlocked(part_id):
			ids.append(part_id)
	return ids


static func select_part(part_id: String) -> bool:
	if not is_unlocked(part_id):
		return false
	GameState.story_flags[SELECTED_PART_FLAG] = part_id
	return true


static func get_selected_part_id() -> String:
	var selected: String = str(GameState.story_flags.get(SELECTED_PART_FLAG, ""))
	if is_unlocked(selected):
		return selected
	for part_id: String in PART_ORDER:
		if is_unlocked(part_id):
			return part_id
	return ""


static func cycle_selected_part(direction: int) -> String:
	var unlocked: Array[String] = get_unlocked_part_ids()
	if unlocked.is_empty() or direction == 0:
		return get_selected_part_id()
	var index: int = unlocked.find(get_selected_part_id())
	if index < 0:
		index = 0
	else:
		index = posmod(index + signi(direction), unlocked.size())
	select_part(unlocked[index])
	return unlocked[index]


static func get_part_cost(part_id: String) -> int:
	return maxi(int(get_definition(part_id).get("mana_cost", 0)), 0)


static func get_part_mass(part_id: String) -> float:
	return maxf(float(get_definition(part_id).get("mass", 0.0)), 0.0)


static func get_part_size(part_id: String) -> Vector3:
	return get_definition(part_id).get("size", Vector3.ONE) as Vector3


static func get_part_tags(part_id: String) -> Array[String]:
	var tags: Array[String] = []
	for value: Variant in get_definition(part_id).get("tags", []):
		tags.append(str(value))
	return tags


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	for part_id: String in PART_ORDER:
		var definition: Dictionary = get_definition(part_id)
		if definition.is_empty():
			failures.append("missing engineering part: " + part_id)
			continue
		var size: Vector3 = definition.get("size", Vector3.ZERO) as Vector3
		if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
			failures.append(part_id + " has invalid dimensions")
		if int(definition.get("mana_cost", -1)) < 0:
			failures.append(part_id + " has invalid mana cost")
		if (definition.get("tags", []) as Array).is_empty():
			failures.append(part_id + " has no engineering tags")
	return failures
