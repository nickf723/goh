extends RefCounted
class_name EngineeringBuildCatalog

const PartCatalog = preload(
	"res://scripts/builds/engineering_part_catalog.gd"
)

const SELECTED_BUILD_FLAG: String = "__engineering_builds__::selected_build"
const SELECTED_CUSTOM_SLOT_FLAG: String = "__artificer__::selected_blueprint_slot"
const CUSTOM_BLUEPRINTS_FLAG: String = "__artificer__::custom_blueprints"
const CUSTOM_BLUEPRINT_PREFIX: String = "__artificer__::custom_blueprint::"

const BUILD_ORDER: Array[String] = [
	"bridge_frame",
	"launch_tower",
	"blast_cart",
	"conductive_raft",
]
const CUSTOM_SLOT_ORDER: Array[String] = [
	"custom_1",
	"custom_2",
	"custom_3",
	"custom_4",
]

const DEFINITIONS: Dictionary = {
	"bridge_frame": {
		"id": "bridge_frame",
		"item_id": "bridge_frame_blueprint",
		"family": "build",
		"display_name": "Bridge Frame",
		"short_name": "Bridge Frame",
		"icon": "▰",
		"description": "A starter artificer schematic made from frame blocks, braces, and a broad deck plate.",
		"behavior": "part_contraption",
		"body_mode": "anchored",
		"mana_cost": 5,
		"maximum_active": 2,
		"placement_range": 14.0,
		"color": Color(0.34, 0.68, 0.94, 1.0),
		"components": [
			{"part_id": "frame_block", "item_id": "recorded_crate_blueprint", "label": "Frame Block"},
			{"part_id": "plate", "item_id": "recorded_platform_blueprint", "label": "Deck Plate"},
		],
		"parts": [
			{"part_id": "frame_block", "position": Vector3(-2.05, 0.75, 0.0), "yaw_degrees": 0.0},
			{"part_id": "frame_block", "position": Vector3(2.05, 0.75, 0.0), "yaw_degrees": 0.0},
			{"part_id": "plate", "position": Vector3(0.0, 1.65, 0.0), "yaw_degrees": 0.0},
			{"part_id": "beam", "position": Vector3(0.0, 1.98, -0.8), "yaw_degrees": 0.0},
			{"part_id": "beam", "position": Vector3(0.0, 1.98, 0.8), "yaw_degrees": 0.0},
		],
		"test_prompt": "Bridge the construction-yard trench or create elevated footing.",
	},
	"launch_tower": {
		"id": "launch_tower",
		"item_id": "launch_tower_blueprint",
		"family": "build",
		"display_name": "Launch Tower",
		"short_name": "Launch Tower",
		"icon": "↟",
		"description": "A saved part assembly with a braced deck and an overchargeable spring unit.",
		"behavior": "part_contraption",
		"body_mode": "anchored",
		"mana_cost": 8,
		"maximum_active": 1,
		"placement_range": 12.0,
		"color": Color(0.38, 0.94, 0.56, 1.0),
		"components": [
			{"part_id": "frame_block", "item_id": "recorded_crate_blueprint", "label": "Frame Block"},
			{"part_id": "plate", "item_id": "recorded_platform_blueprint", "label": "Deck Plate"},
			{"part_id": "spring_unit", "item_id": "recorded_spring_blueprint", "label": "Spring Unit"},
		],
		"parts": [
			{"part_id": "frame_block", "position": Vector3(-0.85, 0.75, -0.85), "yaw_degrees": 0.0},
			{"part_id": "frame_block", "position": Vector3(0.85, 0.75, -0.85), "yaw_degrees": 0.0},
			{"part_id": "frame_block", "position": Vector3(-0.85, 0.75, 0.85), "yaw_degrees": 0.0},
			{"part_id": "frame_block", "position": Vector3(0.85, 0.75, 0.85), "yaw_degrees": 0.0},
			{"part_id": "plate", "position": Vector3(0.0, 1.75, 0.0), "yaw_degrees": 0.0},
			{"part_id": "spring_unit", "position": Vector3(0.0, 2.2, 0.0), "yaw_degrees": 0.0},
		],
		"test_prompt": "Reach the high shelf, then overcharge the launch with Lightning.",
	},
	"blast_cart": {
		"id": "blast_cart",
		"item_id": "blast_cart_blueprint",
		"family": "build",
		"display_name": "Blast Cart",
		"short_name": "Blast Cart",
		"icon": "✹",
		"description": "A mobile plate-and-wheel chassis carrying a volatile artificer blast core.",
		"behavior": "part_contraption",
		"body_mode": "dynamic",
		"mana_cost": 9,
		"maximum_active": 2,
		"placement_range": 12.0,
		"color": Color(0.96, 0.34, 0.12, 1.0),
		"components": [
			{"part_id": "plate", "item_id": "recorded_platform_blueprint", "label": "Deck Plate"},
			{"part_id": "wheel", "item_id": "recorded_crate_blueprint", "label": "Artificer Wheel"},
			{"part_id": "blast_core", "item_id": "recorded_blast_barrel_blueprint", "label": "Blast Core"},
		],
		"parts": [
			{"part_id": "plate", "position": Vector3(0.0, 0.75, 0.0), "yaw_degrees": 0.0},
			{"part_id": "wheel", "position": Vector3(-1.05, 0.55, -0.78), "yaw_degrees": 90.0},
			{"part_id": "wheel", "position": Vector3(1.05, 0.55, -0.78), "yaw_degrees": 90.0},
			{"part_id": "wheel", "position": Vector3(-1.05, 0.55, 0.78), "yaw_degrees": 90.0},
			{"part_id": "wheel", "position": Vector3(1.05, 0.55, 0.78), "yaw_degrees": 90.0},
			{"part_id": "blast_core", "position": Vector3(0.0, 1.55, 0.0), "yaw_degrees": 0.0},
		],
		"test_prompt": "Push it into the target cluster, dampen it, or trigger a chain blast.",
	},
	"conductive_raft": {
		"id": "conductive_raft",
		"item_id": "conductive_raft_blueprint",
		"family": "build",
		"display_name": "Conductive Raft",
		"short_name": "Conductive Raft",
		"icon": "≈",
		"description": "A buoyant pontoon assembly whose conductor rail can energize the deck.",
		"behavior": "part_contraption",
		"body_mode": "dynamic",
		"mana_cost": 9,
		"maximum_active": 1,
		"placement_range": 13.0,
		"color": Color(0.2, 0.76, 0.92, 1.0),
		"components": [
			{"part_id": "float_pontoon", "item_id": "recorded_crate_blueprint", "label": "Float Pontoon"},
			{"part_id": "plate", "item_id": "recorded_platform_blueprint", "label": "Deck Plate"},
			{"part_id": "conductor_rail", "item_id": "recorded_platform_blueprint", "label": "Conductor Rail"},
		],
		"parts": [
			{"part_id": "float_pontoon", "position": Vector3(-1.25, 0.5, 0.0), "yaw_degrees": 0.0},
			{"part_id": "float_pontoon", "position": Vector3(1.25, 0.5, 0.0), "yaw_degrees": 0.0},
			{"part_id": "plate", "position": Vector3(0.0, 1.05, 0.0), "yaw_degrees": 0.0},
			{"part_id": "conductor_rail", "position": Vector3(0.0, 1.28, 0.0), "yaw_degrees": 0.0},
		],
		"test_prompt": "Launch it into water, ride the flow, and energize its deck.",
	},
}


static func has_build(build_id: String) -> bool:
	return DEFINITIONS.has(build_id) or get_custom_blueprints().has(build_id)


static func is_custom_build(build_id: String) -> bool:
	return CUSTOM_SLOT_ORDER.has(build_id) and get_custom_blueprints().has(build_id)


static func get_definition(build_id: String) -> Dictionary:
	if DEFINITIONS.has(build_id):
		var starter: Dictionary = (DEFINITIONS[build_id] as Dictionary).duplicate(true)
		starter["parts"] = normalize_part_layout(starter.get("parts", []) as Array)
		starter["features"] = summarize_features(starter["parts"] as Array)
		starter["size"] = calculate_bounds(starter["parts"] as Array).get("size", Vector3.ONE)
		return starter
	var custom: Dictionary = get_custom_blueprints().get(build_id, {}) as Dictionary
	if custom.is_empty():
		return {}
	return build_custom_definition(build_id, custom)


static func get_definitions() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for build_id: String in BUILD_ORDER:
		rows.append(get_definition(build_id))
	for slot_id: String in CUSTOM_SLOT_ORDER:
		if is_custom_build(slot_id):
			rows.append(get_definition(slot_id))
	return rows


static func get_all_build_ids() -> Array[String]:
	var ids: Array[String] = BUILD_ORDER.duplicate()
	for slot_id: String in CUSTOM_SLOT_ORDER:
		if is_custom_build(slot_id):
			ids.append(slot_id)
	return ids


static func get_item_id(build_id: String) -> String:
	return str(get_definition(build_id).get("item_id", ""))


static func get_build_id_for_item(item_id: String) -> String:
	for build_id: String in BUILD_ORDER:
		if get_item_id(build_id) == item_id:
			return build_id
	return ""


static func is_saved(build_id: String) -> bool:
	if is_custom_build(build_id):
		return true
	var item_id: String = get_item_id(build_id)
	return item_id != "" and GameState.get_inventory_count(item_id) > 0


static func requirements_met(build_id: String) -> bool:
	return get_missing_requirements(build_id).is_empty()


static func get_missing_requirements(build_id: String) -> Array[String]:
	var missing: Array[String] = []
	var definition: Dictionary = get_definition(build_id)
	for raw_component: Variant in definition.get("components", []):
		if not raw_component is Dictionary:
			continue
		var component: Dictionary = raw_component as Dictionary
		var part_id: String = str(component.get("part_id", ""))
		var legacy_item_id: String = str(component.get("item_id", ""))
		var learned: bool = PartCatalog.is_unlocked(part_id)
		if not learned and legacy_item_id != "":
			learned = GameState.get_inventory_count(legacy_item_id) > 0
		if not learned:
			missing.append(str(component.get("label", part_id.replace("_", " ").capitalize())))
	return missing


static func save_build(build_id: String) -> Dictionary:
	var definition: Dictionary = get_definition(build_id)
	if definition.is_empty() or is_custom_build(build_id):
		return {"ok": false, "newly_saved": false, "error": "unknown starter build"}
	var missing: Array[String] = get_missing_requirements(build_id)
	if not missing.is_empty():
		return {
			"ok": false,
			"newly_saved": false,
			"error": "missing engineering parts",
			"missing": missing,
		}
	var newly_saved: bool = not is_saved(build_id)
	if newly_saved:
		GameState.add_inventory_item(get_item_id(build_id), 1)
		_record_build_discovery(build_id, definition)
	select_build(build_id)
	return {
		"ok": true,
		"newly_saved": newly_saved,
		"build_id": build_id,
		"item_id": get_item_id(build_id),
		"definition": definition,
	}


static func save_custom_blueprint(
	slot_id: String,
	parts: Array,
	custom_name: String = ""
) -> Dictionary:
	if not CUSTOM_SLOT_ORDER.has(slot_id):
		return {"ok": false, "error": "invalid blueprint slot"}
	var encoded: Array[Dictionary] = encode_part_layout(parts)
	if encoded.size() < 2:
		return {"ok": false, "error": "a contraption needs at least two parts"}
	if encoded.size() > 12:
		return {"ok": false, "error": "a contraption may use at most twelve parts"}
	var newly_saved: bool = not is_custom_build(slot_id)
	var stored: Dictionary = {
		"slot_id": slot_id,
		"display_name": (
			custom_name
			if custom_name.strip_edges() != ""
			else get_custom_slot_display_name(slot_id)
		),
		"parts": encoded,
		"saved_at_msec": Time.get_ticks_msec(),
	}
	store_custom_blueprint_record(slot_id, stored)
	select_build(slot_id)
	select_custom_slot(slot_id)
	var definition: Dictionary = get_definition(slot_id)
	_record_build_discovery(slot_id, definition)
	return {
		"ok": true,
		"newly_saved": newly_saved,
		"build_id": slot_id,
		"definition": definition,
	}


static func store_custom_blueprint_record(
	slot_id: String,
	stored: Dictionary
) -> bool:
	if not CUSTOM_SLOT_ORDER.has(slot_id) or stored.is_empty():
		return false
	var record: Dictionary = stored.duplicate(true)
	record["slot_id"] = slot_id
	GameState.story_flags[get_custom_slot_flag(slot_id)] = record

	# Keep the original aggregate key as a migration mirror for older builds, but
	# each slot key above is authoritative. One subsystem can no longer replace
	# Contraption A while updating Contraption B.
	var aggregate: Dictionary = {}
	var aggregate_value: Variant = GameState.story_flags.get(
		CUSTOM_BLUEPRINTS_FLAG,
		{}
	)
	if aggregate_value is Dictionary:
		aggregate = (aggregate_value as Dictionary).duplicate(true)
	aggregate[slot_id] = record.duplicate(true)
	GameState.story_flags[CUSTOM_BLUEPRINTS_FLAG] = aggregate
	return true


static func delete_custom_blueprint(slot_id: String) -> bool:
	if not CUSTOM_SLOT_ORDER.has(slot_id):
		return false
	var existed: bool = is_custom_build(slot_id)
	GameState.story_flags.erase(get_custom_slot_flag(slot_id))
	var aggregate_value: Variant = GameState.story_flags.get(
		CUSTOM_BLUEPRINTS_FLAG,
		{}
	)
	if aggregate_value is Dictionary:
		var aggregate: Dictionary = (aggregate_value as Dictionary).duplicate(true)
		aggregate.erase(slot_id)
		GameState.story_flags[CUSTOM_BLUEPRINTS_FLAG] = aggregate
	if str(GameState.story_flags.get(SELECTED_BUILD_FLAG, "")) == slot_id:
		GameState.story_flags.erase(SELECTED_BUILD_FLAG)
	return existed


static func get_custom_blueprints() -> Dictionary:
	var blueprints: Dictionary = {}
	var aggregate: Dictionary = {}
	var aggregate_value: Variant = GameState.story_flags.get(
		CUSTOM_BLUEPRINTS_FLAG,
		{}
	)
	if aggregate_value is Dictionary:
		aggregate = aggregate_value as Dictionary

	for slot_id: String in CUSTOM_SLOT_ORDER:
		var slot_value: Variant = GameState.story_flags.get(
			get_custom_slot_flag(slot_id),
			null
		)
		if slot_value is Dictionary:
			var slot_record: Dictionary = (slot_value as Dictionary).duplicate(true)
			if _is_valid_custom_record(slot_id, slot_record):
				blueprints[slot_id] = slot_record
				continue

		# Migrate one slot at a time from the aggregate shape used by the first
		# Artificer prototype.
		var legacy_value: Variant = aggregate.get(slot_id)
		if legacy_value is Dictionary:
			var legacy_record: Dictionary = (legacy_value as Dictionary).duplicate(true)
			if _is_valid_custom_record(slot_id, legacy_record):
				blueprints[slot_id] = legacy_record
				GameState.story_flags[get_custom_slot_flag(slot_id)] = (
					legacy_record.duplicate(true)
				)
	return blueprints


static func get_custom_slot_flag(slot_id: String) -> String:
	return CUSTOM_BLUEPRINT_PREFIX + slot_id


static func _is_valid_custom_record(
	slot_id: String,
	record: Dictionary
) -> bool:
	if not CUSTOM_SLOT_ORDER.has(slot_id):
		return false
	var parts_value: Variant = record.get("parts")
	if not parts_value is Array:
		return false
	var parts: Array = parts_value as Array
	return parts.size() >= 2 and parts.size() <= 12


static func select_custom_slot(slot_id: String) -> bool:
	if not CUSTOM_SLOT_ORDER.has(slot_id):
		return false
	GameState.story_flags[SELECTED_CUSTOM_SLOT_FLAG] = slot_id
	return true


static func get_selected_custom_slot() -> String:
	var selected: String = str(GameState.story_flags.get(SELECTED_CUSTOM_SLOT_FLAG, ""))
	if CUSTOM_SLOT_ORDER.has(selected):
		return selected
	return CUSTOM_SLOT_ORDER[0]


static func get_custom_slot_display_name(slot_id: String) -> String:
	var index: int = CUSTOM_SLOT_ORDER.find(slot_id)
	return "Contraption " + String.chr(65 + maxi(index, 0))


static func select_build(build_id: String) -> bool:
	if not has_build(build_id) or not is_saved(build_id):
		return false
	GameState.story_flags[SELECTED_BUILD_FLAG] = build_id
	return true


static func get_selected_build_id() -> String:
	var selected: String = str(GameState.story_flags.get(SELECTED_BUILD_FLAG, ""))
	if selected != "" and is_saved(selected):
		return selected
	for build_id: String in get_saved_build_ids():
		return build_id
	return ""


static func get_saved_build_ids() -> Array[String]:
	var ids: Array[String] = []
	for build_id: String in BUILD_ORDER:
		if is_saved(build_id):
			ids.append(build_id)
	for slot_id: String in CUSTOM_SLOT_ORDER:
		if is_custom_build(slot_id):
			ids.append(slot_id)
	return ids


static func get_part_layout(build_id: String) -> Array[Dictionary]:
	return normalize_part_layout(get_definition(build_id).get("parts", []) as Array)


static func get_component_summary(build_id: String) -> String:
	var counts: Dictionary = {}
	for part: Dictionary in get_part_layout(build_id):
		var part_id: String = str(part.get("part_id", ""))
		counts[part_id] = int(counts.get(part_id, 0)) + 1
	var labels: Array[String] = []
	for part_id: String in PartCatalog.PART_ORDER:
		var count: int = int(counts.get(part_id, 0))
		if count <= 0:
			continue
		labels.append(
			str(count)
			+ "× "
			+ str(PartCatalog.get_definition(part_id).get("display_name", part_id.capitalize()))
		)
	return " + ".join(labels)


static func normalize_part_layout(raw_parts: Array) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	for value: Variant in raw_parts:
		if not value is Dictionary:
			continue
		var raw: Dictionary = value as Dictionary
		var part_id: String = str(raw.get("part_id", ""))
		if not PartCatalog.has_part(part_id):
			continue
		parts.append({
			"part_id": part_id,
			"position": _decode_vector3(raw.get("position", Vector3.ZERO)),
			"yaw_degrees": snappedf(float(raw.get("yaw_degrees", 0.0)), 22.5),
		})
	if parts.is_empty():
		return parts
	var bounds: Dictionary = calculate_bounds(parts)
	var minimum: Vector3 = bounds.get("minimum", Vector3.ZERO) as Vector3
	var maximum: Vector3 = bounds.get("maximum", Vector3.ZERO) as Vector3
	var center_xz := Vector3(
		(minimum.x + maximum.x) * 0.5,
		0.0,
		(minimum.z + maximum.z) * 0.5
	)
	for part: Dictionary in parts:
		var position: Vector3 = part.get("position", Vector3.ZERO) as Vector3
		position -= center_xz
		position.y -= minimum.y
		part["position"] = position
	return parts


static func calculate_bounds(parts: Array) -> Dictionary:
	if parts.is_empty():
		return {
			"minimum": Vector3.ZERO,
			"maximum": Vector3.ONE,
			"size": Vector3.ONE,
		}
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for value: Variant in parts:
		if not value is Dictionary:
			continue
		var part: Dictionary = value as Dictionary
		var part_id: String = str(part.get("part_id", ""))
		var size: Vector3 = PartCatalog.get_part_size(part_id)
		var yaw: float = deg_to_rad(float(part.get("yaw_degrees", 0.0)))
		var cosine: float = absf(cos(yaw))
		var sine: float = absf(sin(yaw))
		var half := Vector3(
			(size.x * cosine + size.z * sine) * 0.5,
			size.y * 0.5,
			(size.x * sine + size.z * cosine) * 0.5
		)
		var position: Vector3 = _decode_vector3(part.get("position", Vector3.ZERO))
		minimum.x = minf(minimum.x, position.x - half.x)
		minimum.y = minf(minimum.y, position.y - half.y)
		minimum.z = minf(minimum.z, position.z - half.z)
		maximum.x = maxf(maximum.x, position.x + half.x)
		maximum.y = maxf(maximum.y, position.y + half.y)
		maximum.z = maxf(maximum.z, position.z + half.z)
	return {
		"minimum": minimum,
		"maximum": maximum,
		"size": Vector3(
			maxf(maximum.x - minimum.x, 0.25),
			maxf(maximum.y - minimum.y, 0.25),
			maxf(maximum.z - minimum.z, 0.25)
		),
	}


static func summarize_features(parts: Array) -> Dictionary:
	var features: Dictionary = {
		"structural": 0,
		"wheels": 0,
		"springs": 0,
		"blast_cores": 0,
		"floats": 0,
		"conductors": 0,
	}
	for value: Variant in parts:
		if not value is Dictionary:
			continue
		var part_id: String = str((value as Dictionary).get("part_id", ""))
		for tag: String in PartCatalog.get_part_tags(part_id):
			match tag:
				"structural", "anchor", "brace", "deck":
					features["structural"] = int(features["structural"]) + 1
				"wheel":
					features["wheels"] = int(features["wheels"]) + 1
				"spring":
					features["springs"] = int(features["springs"]) + 1
				"blast":
					features["blast_cores"] = int(features["blast_cores"]) + 1
				"float":
					features["floats"] = int(features["floats"]) + 1
				"conductive":
					features["conductors"] = int(features["conductors"]) + 1
	return features


static func build_custom_definition(
	slot_id: String,
	stored: Dictionary
) -> Dictionary:
	var parts: Array[Dictionary] = normalize_part_layout(stored.get("parts", []) as Array)
	var features: Dictionary = summarize_features(parts)
	var bounds: Dictionary = calculate_bounds(parts)
	var mana_cost: int = 1
	var total_mass: float = 0.0
	for part: Dictionary in parts:
		var part_id: String = str(part.get("part_id", ""))
		mana_cost += PartCatalog.get_part_cost(part_id)
		total_mass += PartCatalog.get_part_mass(part_id)
	var dynamic: bool = (
		int(features.get("wheels", 0)) >= 2
		or int(features.get("floats", 0)) > 0
		or int(features.get("blast_cores", 0)) > 0
	)
	return {
		"id": slot_id,
		"item_id": "",
		"family": "build",
		"custom": true,
		"display_name": str(stored.get("display_name", get_custom_slot_display_name(slot_id))),
		"short_name": str(stored.get("display_name", get_custom_slot_display_name(slot_id))),
		"icon": "⚙",
		"description": "A player-authored artificer contraption assembled from dedicated engineering parts.",
		"behavior": "part_contraption",
		"body_mode": "dynamic" if dynamic else "anchored",
		"size": bounds.get("size", Vector3.ONE),
		"mass": maxf(total_mass, 1.0),
		"mana_cost": maxi(mana_cost, 1),
		"maximum_active": 2,
		"placement_range": 14.0,
		"color": Color(0.46, 0.8, 1.0, 1.0),
		"parts": parts,
		"features": features,
		"components": [],
		"test_prompt": "Deploy the saved machine and test how its parts combine.",
	}


static func encode_part_layout(parts: Array) -> Array[Dictionary]:
	var encoded: Array[Dictionary] = []
	for part: Dictionary in normalize_part_layout(parts):
		var position: Vector3 = part.get("position", Vector3.ZERO) as Vector3
		encoded.append({
			"part_id": str(part.get("part_id", "")),
			"position": [position.x, position.y, position.z],
			"yaw_degrees": float(part.get("yaw_degrees", 0.0)),
		})
	return encoded


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = PartCatalog.validate_catalog()
	var seen_items: Dictionary = {}
	for build_id: String in BUILD_ORDER:
		var definition: Dictionary = get_definition(build_id)
		if definition.is_empty():
			failures.append("missing engineering build: " + build_id)
			continue
		var item_id: String = str(definition.get("item_id", ""))
		if item_id == "":
			failures.append(build_id + " has no inventory item")
		elif seen_items.has(item_id):
			failures.append("duplicate engineering build item: " + item_id)
		seen_items[item_id] = true
		if (definition.get("parts", []) as Array).is_empty():
			failures.append(build_id + " has no engineering part layout")
		if int(definition.get("maximum_active", 0)) <= 0:
			failures.append(build_id + " needs an active limit")
	return failures


static func _decode_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value as Vector3
	if value is Array:
		var values: Array = value as Array
		if values.size() >= 3:
			return Vector3(float(values[0]), float(values[1]), float(values[2]))
	if value is Dictionary:
		var row: Dictionary = value as Dictionary
		return Vector3(
			float(row.get("x", 0.0)),
			float(row.get("y", 0.0)),
			float(row.get("z", 0.0))
		)
	return Vector3.ZERO


static func _record_build_discovery(
	build_id: String,
	definition: Dictionary
) -> void:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		return
	var tree := main_loop as SceneTree
	var tracker: Node = tree.root.get_node_or_null(
		"FullMenuDirector/ProgressionTracker"
	)
	if tracker != null and tracker.has_method("record_discovery"):
		tracker.call(
			"record_discovery",
			"blueprint",
			build_id,
			{
				"source": "artificer_construction",
				"display_name": str(definition.get("display_name", build_id.capitalize())),
				"components": get_component_summary(build_id),
			}
		)
